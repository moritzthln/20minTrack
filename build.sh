#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Pin the Command Line Tools toolchain (same SDK as the Timer app):
# the Xcode 26 SDK displaces the NSPopover below the status item.
if [ -d /Library/Developer/CommandLineTools ]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

# Universal binary. `swift build --arch` needs full Xcode (xcbuild);
# on the pinned CLT toolchain we build each slice by triple and lipo
# them together (Timer's package.sh pattern).
echo "▸ Building universal release binary (arm64 + x86_64 slices)…"
swift build -c release --triple arm64-apple-macosx13.0 2>&1 | tail -1
swift build -c release --triple x86_64-apple-macosx13.0 2>&1 | tail -1

APP="dist/20minTrack.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

lipo -create ".build/arm64-apple-macosx/release/TwentyTrackApp" \
     ".build/x86_64-apple-macosx/release/TwentyTrackApp" \
     -output "$APP/Contents/MacOS/TwentyTrackApp"
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
