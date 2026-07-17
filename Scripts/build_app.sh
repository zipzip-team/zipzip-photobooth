#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/PhotoPrintBooth.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
if [ -d "$ROOT_DIR/Resources/Filters" ]; then
  cp -R "$ROOT_DIR/Resources/Filters" "$RESOURCES_DIR/Filters"
fi
find "$ROOT_DIR/Resources" -maxdepth 1 -type f ! -name "Info.plist" ! -name ".DS_Store" -exec cp {} "$RESOURCES_DIR" \;

xcrun swiftc \
  -target arm64-apple-macosx14.0 \
  -parse-as-library \
  "$ROOT_DIR"/Sources/*.swift \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework CoreImage \
  -framework CoreGraphics \
  -o "$MACOS_DIR/PhotoPrintBooth"

codesign --force --sign - "$APP_DIR" >/dev/null

echo "Built $APP_DIR"
