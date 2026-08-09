#!/usr/bin/env bash
# Builds a shareable ZIP (app + German install guide) into dist/.
# The app is ad-hoc signed — the guide's xattr command lifts Gatekeeper's
# download quarantine on the recipient's Mac (macOS 13+).
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

STAGE="dist/20minTrack-Paket"
rm -rf "$STAGE" dist/20minTrack.zip
mkdir -p "$STAGE"
ditto dist/20minTrack.app "$STAGE/20minTrack.app"

cat > "$STAGE/ANLEITUNG.txt" << 'EOF'
20minTrack installieren (macOS 13 oder neuer)
=============================================

1. "20minTrack.app" in den Ordner "Programme" ziehen.

2. Terminal öffnen (Spotlight: "Terminal") und diesen Befehl einfügen,
   dann Enter — er hebt die macOS-Sperre für heruntergeladene Apps auf:

   xattr -cr /Applications/20minTrack.app

3. App starten. Oben in der Menüleiste erscheint ein Kreis mit einer
   Zahl — der Countdown bis zum nächsten Check-in (alle 20 min).

4. Empfohlen: Im Popover (Klick auf den Kreis) → "…"-Menü →
   Einstellungen → "Beim Anmelden starten" aktivieren.

5. Optional: Wenn Safari/Chrome/Arc benutzt werden, fragt macOS einmal
   pro Browser um Erlaubnis ("möchte … steuern") — mit "Erlauben"
   erscheinen einzelne Websites (z. B. youtube.com) in der Benutzt-Liste.

Alle Daten bleiben lokal auf dem Mac (keine Cloud, kein Account).
EOF

ditto -c -k --keepParent "$STAGE" dist/20minTrack.zip
rm -rf "$STAGE"
echo "✓ Paket: dist/20minTrack.zip"
