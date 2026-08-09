# 20minTrack

macOS-Menüleisten-App: Der Tag wird in 20-Minuten-Blöcken getrackt.
Alle 20 Minuten fragt die App „Was hast du gemacht?" — kurze Notiz +
Label (z. B. Fokus Arbeit MMA, Kein Fokus, Orga/Other, Schlafen, Spaß,
Sport). Verpasste Blöcke (Schlaf, unterwegs) werden beim nächsten
Check-in als ein Zeitraum nachgetragen. Am Ende des Tages: Tagesfazit.
Statistiken zeigen die Zeit pro Label (Tag/Woche).

## Install

```bash
./build.sh
```

Baut die Release-App und installiert nach `/Applications/20minTrack.app`.

## Bedienung

- **Menüleiste**: `20⃝ 7 m` = nächster Check-in in 7 min; gefülltes
  Symbol + Zahl = offene Blöcke warten. Klick öffnet das Popover.
- **Check-in**: Notiz tippen, Label wählen, Enter. „Überspringen" lässt
  den Zeitraum leer. „Von"-Auswahl, wenn mehrere Blöcke offen sind.
- **Tagesstrip**: Klick auf einen Block → eintragen/bearbeiten/löschen.
- **Fazit**: Stift-Symbol im Popover (oder in der Statistik pro Tag).
- **Statistik**: Balken-Symbol — Tag- und Wochenansicht.
- **Einstellungen**: Labels (Name, Farbe, archivieren, neue), Ton,
  Auto-Popover, Pause, Login-Start.

## Entwicklung

```bash
swift build                      # debug build
swift run TwentyTrackTestRunner  # tests (kein XCTest — eigener Runner)
```

Daten: `~/Library/Application Support/20minTrack/days/YYYY-MM-DD.json`,
Settings in UserDefaults (`com.moritzthelen.twentymintrack`).
