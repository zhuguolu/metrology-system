#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-ios-app}"
SCHEME="${2:-}"
CONFIGURATION="${3:-Release}"
MIN_APP_BUNDLE_SIZE_MB="${MIN_APP_BUNDLE_SIZE_MB:-${MIN_IPA_SIZE_MB:-1}}"

if ! [[ "$MIN_APP_BUNDLE_SIZE_MB" =~ ^[0-9]+$ ]]; then
  echo "MIN_APP_BUNDLE_SIZE_MB must be a non-negative integer, got: $MIN_APP_BUNDLE_SIZE_MB"
  exit 1
fi
MIN_APP_BUNDLE_SIZE_BYTES=$((MIN_APP_BUNDLE_SIZE_MB * 1024 * 1024))

if [ ! -d "$APP_DIR" ]; then
  echo "App directory not found: $APP_DIR"
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required. Please run on macOS with Xcode installed."
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install with: brew install xcodegen"
  exit 1
fi

ROOT_DIR="$(cd "$APP_DIR" && pwd)"
PROJECT_YML_PATH="$ROOT_DIR/project.yml"

if [ ! -f "$PROJECT_YML_PATH" ]; then
  echo "project.yml not found in: $ROOT_DIR"
  exit 1
fi

resolve_scheme_from_project_yml() {
  local spec="$1"
  local value=""

  # Primary: top-level "name:" (tolerate BOM + spaces).
  value="$(sed -n 's/^[[:space:]]*name:[[:space:]]*//p' "$spec" | head -n 1 | tr -d '\r\357\273\277' || true)"
  if [ -n "$value" ]; then
    printf '%s' "$value"
    return
  fi

  # Fallback: first key under "schemes:" block.
  value="$(awk '
    /^[[:space:]]*schemes:[[:space:]]*$/ { in_schemes=1; next }
    in_schemes && /^[^[:space:]]/ { in_schemes=0 }
    in_schemes && /^[[:space:]]{2}[A-Za-z0-9_.-]+:[[:space:]]*$/ {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/:[[:space:]]*$/, "", line)
      print line
      exit
    }
  ' "$spec" | tr -d '\r\357\273\277' || true)"
  printf '%s' "$value"
}

file_size_bytes() {
  local path="$1"
  if stat -f%z "$path" >/dev/null 2>&1; then
    stat -f%z "$path"
  else
    wc -c < "$path" | tr -d ' '
  fi
}

app_bundle_size_bytes() {
  local path="$1"
  du -sk "$path" | awk '{print $1 * 1024}'
}

plist_value() {
  local plist="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true
}

upsert_plist_string() {
  local plist="$1"
  local key="$2"
  local value="$3"
  if /usr/libexec/PlistBuddy -c "Print :$key" "$plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist" >/dev/null
  else
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist" >/dev/null
  fi
}

upsert_plist_bool() {
  local plist="$1"
  local key="$2"
  local value="$3"
  if /usr/libexec/PlistBuddy -c "Print :$key" "$plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist" >/dev/null
  else
    /usr/libexec/PlistBuddy -c "Add :$key bool $value" "$plist" >/dev/null
  fi
}

set_device_family_iphone_only() {
  local plist="$1"
  /usr/libexec/PlistBuddy -c "Delete :UIDeviceFamily" "$plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :UIDeviceFamily array" "$plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Add :UIDeviceFamily:0 integer 1" "$plist" >/dev/null
}

normalize_token() {
  local raw="${1:-}"
  printf '%s' "$raw" | tr -d '\r[:space:]' | tr '[:upper:]' '[:lower:]'
}

is_truthy() {
  local normalized
  normalized="$(normalize_token "${1:-}")"
  [ "$normalized" = "true" ] || [ "$normalized" = "1" ] || [ "$normalized" = "yes" ]
}

coalesce_non_empty() {
  local first="${1:-}"
  local second="${2:-}"
  if [ -n "$(normalize_token "$first")" ]; then
    printf '%s' "$first"
  else
    printf '%s' "$second"
  fi
}

if [ -z "$SCHEME" ]; then
  SCHEME="$(resolve_scheme_from_project_yml "$PROJECT_YML_PATH")"
fi

if [ -z "$SCHEME" ]; then
  echo "Unable to resolve scheme. Provide arg2 or set name: in project.yml"
  exit 1
fi

PROJECT_PATH="$ROOT_DIR/${SCHEME}.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos"
PACKAGE_DIR="$ROOT_DIR/build/unsigned_ipa"
ARTIFACT_DIR="$ROOT_DIR/build/artifacts"
IPA_PATH="$ARTIFACT_DIR/${SCHEME}-unsigned.ipa"
APP_ZIP_PATH="$ARTIFACT_DIR/${SCHEME}.app.zip"
CHECKSUM_PATH="$ARTIFACT_DIR/checksums.txt"
BUILD_INFO_PATH="$ARTIFACT_DIR/build-info.txt"

cd "$ROOT_DIR"
xcodegen generate --spec project.yml

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  clean build

APP_PATH="$PRODUCTS_DIR/${SCHEME}.app"
if [ ! -d "$APP_PATH" ]; then
  APP_PATH="$(find "$PRODUCTS_DIR" -maxdepth 1 -name "*.app" | head -n 1 || true)"
fi

if [ -z "${APP_PATH:-}" ] || [ ! -d "$APP_PATH" ]; then
  echo "Unable to find built .app in: $PRODUCTS_DIR"
  exit 1
fi

APP_INFO_PLIST="$APP_PATH/Info.plist"
if [ ! -f "$APP_INFO_PLIST" ]; then
  echo "Built app Info.plist not found: $APP_INFO_PLIST"
  exit 67
fi
SOURCE_INFO_PLIST="$ROOT_DIR/Sources/Resources/Info.plist"

BUILT_LAUNCH_STORYBOARD_NAME="$(plist_value "$APP_INFO_PLIST" "UILaunchStoryboardName")"
BUILT_REQUIRES_FULLSCREEN="$(plist_value "$APP_INFO_PLIST" "UIRequiresFullScreen")"
BUILT_DEVICE_FAMILY_FIRST="$(plist_value "$APP_INFO_PLIST" "UIDeviceFamily:0")"
BUILT_DEVICE_FAMILY_SECOND="$(plist_value "$APP_INFO_PLIST" "UIDeviceFamily:1")"

SOURCE_LAUNCH_STORYBOARD_NAME=""
SOURCE_REQUIRES_FULLSCREEN=""
SOURCE_DEVICE_FAMILY_FIRST=""
SOURCE_DEVICE_FAMILY_SECOND=""
if [ -f "$SOURCE_INFO_PLIST" ]; then
  SOURCE_LAUNCH_STORYBOARD_NAME="$(plist_value "$SOURCE_INFO_PLIST" "UILaunchStoryboardName")"
  SOURCE_REQUIRES_FULLSCREEN="$(plist_value "$SOURCE_INFO_PLIST" "UIRequiresFullScreen")"
  SOURCE_DEVICE_FAMILY_FIRST="$(plist_value "$SOURCE_INFO_PLIST" "UIDeviceFamily:0")"
  SOURCE_DEVICE_FAMILY_SECOND="$(plist_value "$SOURCE_INFO_PLIST" "UIDeviceFamily:1")"
fi

LAUNCH_STORYBOARD_NAME="$(coalesce_non_empty "$BUILT_LAUNCH_STORYBOARD_NAME" "$SOURCE_LAUNCH_STORYBOARD_NAME")"
REQUIRES_FULLSCREEN="$(coalesce_non_empty "$BUILT_REQUIRES_FULLSCREEN" "$SOURCE_REQUIRES_FULLSCREEN")"
DEVICE_FAMILY_FIRST="$(coalesce_non_empty "$BUILT_DEVICE_FAMILY_FIRST" "$SOURCE_DEVICE_FAMILY_FIRST")"
DEVICE_FAMILY_SECOND="$(coalesce_non_empty "$BUILT_DEVICE_FAMILY_SECOND" "$SOURCE_DEVICE_FAMILY_SECOND")"

if [ -z "$LAUNCH_STORYBOARD_NAME" ]; then
  DETECTED_STORYBOARD_PATH="$(find "$APP_PATH" -maxdepth 1 -type d -name "*.storyboardc" | head -n 1 || true)"
  if [ -n "$DETECTED_STORYBOARD_PATH" ]; then
    LAUNCH_STORYBOARD_NAME="$(basename "$DETECTED_STORYBOARD_PATH" ".storyboardc")"
  fi
fi

if [ -z "$LAUNCH_STORYBOARD_NAME" ]; then
  echo "Compatibility check failed: UILaunchStoryboardName missing. This can cause non-full-screen rendering on modern iPhone."
  exit 68
fi

# Normalize built Info.plist to avoid runtime letterboxing.
upsert_plist_string "$APP_INFO_PLIST" "UILaunchStoryboardName" "$LAUNCH_STORYBOARD_NAME"
if ! is_truthy "$REQUIRES_FULLSCREEN"; then
  upsert_plist_bool "$APP_INFO_PLIST" "UIRequiresFullScreen" "true"
  REQUIRES_FULLSCREEN="true"
fi

if [ "$(normalize_token "$DEVICE_FAMILY_FIRST")" != "1" ] || [ -n "$(normalize_token "$DEVICE_FAMILY_SECOND")" ]; then
  set_device_family_iphone_only "$APP_INFO_PLIST"
  DEVICE_FAMILY_FIRST="1"
  DEVICE_FAMILY_SECOND=""
fi

if [ ! -d "$APP_PATH/${LAUNCH_STORYBOARD_NAME}.storyboardc" ]; then
  echo "Compatibility check failed: launch storyboard bundle missing at $APP_PATH/${LAUNCH_STORYBOARD_NAME}.storyboardc."
  exit 68
fi

rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"

rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR/Payload"
cp -R "$APP_PATH" "$PACKAGE_DIR/Payload/"

rm -f "$IPA_PATH"
(
  cd "$PACKAGE_DIR"
  /usr/bin/zip -qry "$IPA_PATH" Payload
)

APP_NAME="$(basename "$APP_PATH")"
rm -f "$APP_ZIP_PATH"
(
  cd "$PRODUCTS_DIR"
  /usr/bin/zip -qry "$APP_ZIP_PATH" "$APP_NAME"
)

IPA_SIZE_BYTES="$(file_size_bytes "$IPA_PATH")"
APP_ZIP_SIZE_BYTES="$(file_size_bytes "$APP_ZIP_PATH")"
APP_BUNDLE_SIZE_BYTES="$(app_bundle_size_bytes "$APP_PATH")"
APP_FILE_COUNT="$(find "$APP_PATH" -type f | wc -l | tr -d ' ')"
EXECUTABLE_NAME="$(plist_value "$APP_PATH/Info.plist" "CFBundleExecutable")"
EXECUTABLE_SIZE_BYTES=0
if [ -n "$EXECUTABLE_NAME" ] && [ -f "$APP_PATH/$EXECUTABLE_NAME" ]; then
  EXECUTABLE_SIZE_BYTES="$(file_size_bytes "$APP_PATH/$EXECUTABLE_NAME")"
fi

(
  cd "$ARTIFACT_DIR"
  shasum -a 256 "$(basename "$IPA_PATH")" "$(basename "$APP_ZIP_PATH")" > "$CHECKSUM_PATH"
)

{
  echo "app_dir=$APP_DIR"
  echo "scheme=$SCHEME"
  echo "configuration=$CONFIGURATION"
  echo "app=$APP_NAME"
  echo "built_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "min_app_bundle_size_mb=$MIN_APP_BUNDLE_SIZE_MB"
  echo "ipa_size_bytes=$IPA_SIZE_BYTES"
  echo "app_zip_size_bytes=$APP_ZIP_SIZE_BYTES"
  echo "app_bundle_size_bytes=$APP_BUNDLE_SIZE_BYTES"
  echo "app_file_count=$APP_FILE_COUNT"
  echo "executable_name=$EXECUTABLE_NAME"
  echo "executable_size_bytes=$EXECUTABLE_SIZE_BYTES"
  echo "launch_storyboard_name=$LAUNCH_STORYBOARD_NAME"
  echo "ui_requires_full_screen=$REQUIRES_FULLSCREEN"
  echo "ui_device_family_first=$DEVICE_FAMILY_FIRST"
  echo "ui_device_family_second=$DEVICE_FAMILY_SECOND"
  xcodebuild -version | tr '\n' '|' | sed 's/|$//'
} > "$BUILD_INFO_PATH"

if [ "$APP_BUNDLE_SIZE_BYTES" -lt "$MIN_APP_BUNDLE_SIZE_BYTES" ]; then
  echo "App bundle size check failed: ${APP_BUNDLE_SIZE_BYTES} bytes (< ${MIN_APP_BUNDLE_SIZE_BYTES} bytes, MIN_APP_BUNDLE_SIZE_MB=${MIN_APP_BUNDLE_SIZE_MB}); ipa_size_bytes=${IPA_SIZE_BYTES}; app_file_count=${APP_FILE_COUNT}; executable_name=${EXECUTABLE_NAME}; executable_size_bytes=${EXECUTABLE_SIZE_BYTES}"
  exit 66
fi

echo "Unsigned IPA: $IPA_PATH"
echo "IPA size bytes: $IPA_SIZE_BYTES"
echo "Zipped APP: $APP_ZIP_PATH"
echo "APP zip size bytes: $APP_ZIP_SIZE_BYTES"
echo "APP bundle size bytes: $APP_BUNDLE_SIZE_BYTES"
echo "APP file count: $APP_FILE_COUNT"
echo "Executable: $EXECUTABLE_NAME ($EXECUTABLE_SIZE_BYTES bytes)"
echo "Checksums: $CHECKSUM_PATH"
echo "Build info: $BUILD_INFO_PATH"
