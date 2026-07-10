#!/bin/bash
# Builds WindowAnchor.app (arm64 release) and packages it into a DMG.
# Usage: Scripts/build_app.sh [version]
set -euo pipefail

VERSION="${1:-1.0.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/WindowAnchor.app"
DMG="$DIST/WindowAnchor-$VERSION.dmg"

cd "$ROOT"
rm -rf "$DIST"
mkdir -p "$DIST"

echo "==> Building (release, arm64)…"
swift build -c release --arch arm64

echo "==> Generating icon…"
swift Scripts/make_icon.swift "$DIST"

echo "==> Assembling WindowAnchor.app…"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/WindowAnchor "$APP/Contents/MacOS/WindowAnchor"
sed -e "s/APP_VERSION/$VERSION/" -e "s/APP_BUILD/$VERSION/" \
    Packaging/Info.plist > "$APP/Contents/Info.plist"
cp "$DIST/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "==> Signing (ad-hoc)…"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose=2 "$APP"

echo "==> Creating DMG…"
STAGING="$DIST/dmg-staging"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "WindowAnchor" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING" "$DIST/AppIcon.iconset"

echo "==> Done: $DMG"
