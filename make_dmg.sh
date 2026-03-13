#!/usr/bin/env bash
set -euo pipefail

APP_NAME="KeyboardWipeLock"
VERSION="${1:-1.0.0}"
BUILD_DIR="build"
DMG_DIR="$BUILD_DIR/dmg"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

bash ./build_app.sh

rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$BUILD_DIR/${APP_NAME}.app" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -format UDZO \
  "$BUILD_DIR/$DMG_NAME"

echo "DMG: $BUILD_DIR/$DMG_NAME"
