#!/usr/bin/env bash
# Regenerates the README screenshots in docs/images/ from demo data.
# Backs up your real settings + data first and ALWAYS restores them
# (also on failure). Run after every visible UI change:
#   ./Scripts/render_screenshots.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DOMAIN="com.moritzthelen.twentymintrack"
DATA="$HOME/Library/Application Support/20minTrack"
APP="/Applications/20minTrack.app"
BACKUP="$(mktemp -d)"

[ -x "$APP/Contents/MacOS/TwentyTrackApp" ] || { echo "✗ build first: ./build.sh" >&2; exit 1; }

restore() {
  rm -rf "$DATA"
  [ -d "$BACKUP/data" ] && ditto "$BACKUP/data" "$DATA"
  defaults delete "$DOMAIN" 2>/dev/null || true
  [ -f "$BACKUP/defaults.plist" ] && defaults import "$DOMAIN" "$BACKUP/defaults.plist"
  open -a "$APP"
  echo "✓ real data restored"
}

pkill -x TwentyTrackApp 2>/dev/null || true
sleep 1
defaults export "$DOMAIN" "$BACKUP/defaults.plist" 2>/dev/null || true
[ -d "$DATA" ] && ditto "$DATA" "$BACKUP/data"
trap restore EXIT

python3 Scripts/demo_data.py
rm -f docs/images/done
TWENTYMINTRACK_SNAPSHOT="$PWD/docs/images" "$APP/Contents/MacOS/TwentyTrackApp" >/dev/null 2>&1
rm -f docs/images/done

# Strip PNG metadata chunks (resolution/EXIF) — keep pixels + color.
python3 - << 'PY'
import glob, struct
keep = {b"IHDR", b"PLTE", b"IDAT", b"IEND", b"tRNS", b"sRGB", b"gAMA", b"cHRM", b"iCCP", b"pHYs"}
for path in glob.glob("docs/images/*.png"):
    data = open(path, "rb").read()
    out, i = data[:8], 8
    while i < len(data):
        n = struct.unpack(">I", data[i:i + 4])[0]
        if data[i + 4:i + 8] in keep:
            out += data[i:i + 12 + n]
        i += 12 + n
    open(path, "wb").write(out)
PY
echo "✓ screenshots updated in docs/images/"
