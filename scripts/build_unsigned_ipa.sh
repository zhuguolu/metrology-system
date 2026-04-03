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

PBXPROJ_PATH="$PROJECT_PATH/project.pbxproj"
if [ -f "$PBXPROJ_PATH" ]; then
  # Work around XcodeGen newer objectVersion (77) not readable by Xcode 15.4 runners.
  perl -0pi -e 's/objectVersion = 77;/objectVersion = 60;/g; s/compatibilityVersion = "Xcode 16\.0";/compatibilityVersion = "Xcode 15.0";/g' "$PBXPROJ_PATH"
fi

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
