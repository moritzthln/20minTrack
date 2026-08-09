#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ Building release binary…"
swift build -c release 2>&1 | tail -2

APP="dist/20minTrack.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/TwentyTrackApp "$APP/Contents/MacOS/TwentyTrackApp"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f Resources/AppIcon.icns ]; then
  echo "▸ Generating app icon…"
  swift Scripts/generate_icon.swift dist/AppIcon.iconset
  iconutil -c icns dist/AppIcon.iconset -o Resources/AppIcon.icns
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Code signing (ad-hoc)…"
codesign --force --deep -s - "$APP"

echo "▸ Installing…"
pkill -x TwentyTrackApp 2>/dev/null || true
TARGET="/Applications/20minTrack.app"
if [ ! -w /Applications ]; then
  TARGET="$HOME/Applications/20minTrack.app"
  mkdir -p "$HOME/Applications"
fi
rm -rf "$TARGET"
ditto "$APP" "$TARGET"
echo "✓ Installed: $TARGET"
