#!/usr/bin/env zsh
set -euo pipefail

APP_NAME="ClipPin"
BUNDLE_ID="com.clippin.app"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BIN_SRC="$ROOT_DIR/.build/release/$APP_NAME"
BIN_DST="$MACOS_DIR/$APP_NAME"

VERSION_ARG="${1:-}"
if [[ -n "$VERSION_ARG" ]]; then
  VERSION="$VERSION_ARG"
else
  VERSION="$(git -C "$ROOT_DIR" describe --tags --always --dirty 2>/dev/null || true)"
  if [[ -z "$VERSION" ]]; then
    VERSION="0.1.0"
  fi
fi

BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M%S)}"
ZIP_NAME="${APP_NAME}-${VERSION}-macOS.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
CHECKSUM_PATH="${ZIP_PATH}.sha256"

echo "Building release binary..."
cd "$ROOT_DIR"
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_SRC" "$BIN_DST"
chmod +x "$BIN_DST"
strip -x "$BIN_DST"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

if command -v codesign >/dev/null 2>&1; then
  echo "Applying ad-hoc code signature..."
  codesign --force --sign - "$APP_DIR" >/dev/null
fi

echo "Creating zip for GitHub Release..."
rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
(
  cd "$DIST_DIR"
  ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$ZIP_NAME"
)

(
  cd "$DIST_DIR"
  shasum -a 256 "$ZIP_NAME" > "$CHECKSUM_PATH"
)

echo ""
echo "Done."
echo "App:      $APP_DIR"
echo "Zip:      $ZIP_PATH"
echo "Checksum: $CHECKSUM_PATH"
stat -f "App binary size: %z bytes" "$BIN_DST"
