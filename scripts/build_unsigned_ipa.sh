#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-ios-app}"
SCHEME="${2:-}"
CONFIGURATION="${3:-Release}"

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

if [ -z "$SCHEME" ]; then
  SCHEME="$(awk -F': ' '/^name:/{print $2; exit}' "$PROJECT_YML_PATH" | tr -d '\r' || true)"
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
  xcodebuild -version | tr '\n' '|' | sed 's/|$//'
} > "$BUILD_INFO_PATH"

echo "Unsigned IPA: $IPA_PATH"
echo "Zipped APP: $APP_ZIP_PATH"
echo "Checksums: $CHECKSUM_PATH"
echo "Build info: $BUILD_INFO_PATH"
