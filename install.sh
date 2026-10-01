#!/usr/bin/env bash
# One-line installer for 20minTrack:
#   curl -fsSL https://raw.githubusercontent.com/moritzthln/20minTrack/main/install.sh | bash
# Downloads the latest release, installs it to /Applications (or
# ~/Applications without write access), clears the download quarantine
# (the app is ad-hoc signed, not notarized) and launches it.
set -euo pipefail

REPO="moritzthln/20minTrack"
URL="https://github.com/$REPO/releases/latest/download/20minTrack.zip"

if [ "$(uname)" != "Darwin" ]; then
  echo "20minTrack is a macOS app." >&2
  exit 1
fi
major="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$major" -lt 13 ]; then
  echo "20minTrack needs macOS 13 (Ventura) or newer." >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "▸ Downloading the latest 20minTrack release…"
curl -fsSL "$URL" -o "$tmp/20minTrack.zip"
# Verify the SHA-256 checksum when the release publishes one.
if curl -fsSL "$URL.sha256" -o "$tmp/20minTrack.zip.sha256" 2>/dev/null; then
  ( cd "$tmp" && shasum -a 256 -c 20minTrack.zip.sha256 >/dev/null ) \
    || { echo "Checksum mismatch — download corrupted, aborting." >&2; exit 1; }
  echo "▸ Checksum verified."
fi
ditto -x -k "$tmp/20minTrack.zip" "$tmp/unpacked"
app="$(find "$tmp/unpacked" -maxdepth 3 -name '20minTrack.app' -type d | head -1)"
if [ -z "$app" ]; then
  echo "Release archive did not contain 20minTrack.app." >&2
  exit 1
fi

target_dir="/Applications"
[ -w "$target_dir" ] || { target_dir="$HOME/Applications"; mkdir -p "$target_dir"; }
target="$target_dir/20minTrack.app"

echo "▸ Installing to $target…"
pkill -x TwentyTrackApp 2>/dev/null || true
rm -rf "$target"
ditto "$app" "$target"
xattr -cr "$target"

echo "▸ Launching…"
open "$target"
echo "✓ 20minTrack is running — look for the countdown circle in your menu bar."
