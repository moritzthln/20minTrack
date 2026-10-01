#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Pin the Command Line Tools toolchain (same SDK as the Timer app):
# the Xcode 26 SDK displaces the NSPopover below the status item.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Library/Developer/CommandLineTools ]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

# Universal binary. `swift build --arch` needs full Xcode (xcbuild);
# on the pinned CLT toolchain we build each slice by triple and lipo
# them together. Each slice gets its own scratch path: sharing one
# .build between triples makes SwiftPM reuse the other triple's cached
# build description ("command … not registered").
build_slice() {
  local arch="$1" log
  log="$(mktemp)"
  if ! swift build -c release --triple "$arch-apple-macosx13.0" \
       --scratch-path ".build/slice-$arch" > "$log" 2>&1; then
    grep -v "xcrun" "$log" >&2
    echo "✗ $arch build failed" >&2
    exit 1
  fi
  rm -f "$log"
}
echo "▸ Building universal release binary (arm64 + x86_64 slices)…"
build_slice arm64
build_slice x86_64

APP="dist/20minTrack.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

lipo -create ".build/slice-arm64/arm64-apple-macosx/release/TwentyTrackApp" \
     ".build/slice-x86_64/x86_64-apple-macosx/release/TwentyTrackApp" \
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

# NO_INSTALL=1 (CI / packaging): build dist/ only, leave the running app alone.
if [ "${NO_INSTALL:-0}" = "1" ]; then
  echo "✓ Built: $APP"
  exit 0
fi

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
