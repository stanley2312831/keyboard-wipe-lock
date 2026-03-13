#!/usr/bin/env bash
set -euo pipefail

APP_NAME="KeyboardWipeLock"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

swiftc -O -target arm64-apple-macos12.0 -framework Cocoa main.swift -o "$BUILD_DIR/${APP_NAME}-arm64"
swiftc -O -target x86_64-apple-macos12.0 -framework Cocoa main.swift -o "$BUILD_DIR/${APP_NAME}-x64"
lipo -create -output "$MACOS_DIR/$APP_NAME" "$BUILD_DIR/${APP_NAME}-arm64" "$BUILD_DIR/${APP_NAME}-x64"
chmod +x "$MACOS_DIR/$APP_NAME"

cp Info.plist "$APP_DIR/Contents/Info.plist"
if [ -f "build/AppIcon.icns" ]; then
  cp "build/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi

echo "Built: $APP_DIR"
