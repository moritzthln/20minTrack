# 20minTrack

macOS-Menüleisten-App: Der Tag wird in 20-Minuten-Blöcken getrackt.
Alle 20 Minuten fragt die App „Was hast du gemacht?" — kurze Notiz +
Label (mitgeliefert: Fokus Arbeit, Halbfokus, Orga & Alltag, Calls,
Ablenkung, Erholung, Sport, Schlafen — in den Einstellungen änderbar).
Verpasste Blöcke (Schlaf, unterwegs) werden beim nächsten
Check-in als ein Zeitraum nachgetragen. Am Ende des Tages: Tagesfazit.
Statistiken zeigen die Zeit pro Label (Tag/Woche).

## Install

```bash
./build.sh
```

Baut die Release-App und installiert nach `/Applications/20minTrack.app`.

## Bedienung

- **Menüleiste**: `20⃝ 7 m` = nächster Check-in in 7 min; gefülltes
  Symbol + Zahl = offene Blöcke warten. Klick öffnet das (breite)
  Popover.
- **Blockende = Fenster mitten auf dem Bildschirm**: Zu jeder
  20-Minuten-Grenze ploppt das Check-in-Fenster zentriert auf — über
  allen Fenstern, auf jedem Space, auch über Fullscreen-Apps. Enter
  speichert, Esc = „Später". Nicht zu übersehen. (Abschaltbar in den
  Einstellungen.)
- **Check-in in einer Taste**: Das zuletzt benutzte Label ist
  vorausgewählt — **Enter** speichert sofort. Alternativ: **⌘1–⌘9**
  wählt ein Label und speichert direkt, Klick auf das gewählte Label
  speichert ebenfalls. Notiz ist immer optional. Darunter steht, welche
  Apps im Zeitraum benutzt wurden („Benutzt: Chrome 12 min …").
  **„Später"** verschiebt den Check-in — der Zeitraum bleibt offen und
  wird beim nächsten Mal wieder mit abgefragt: Es entstehen keine
  Lücken, alles wird irgendwann ausgefüllt.
- **Ruhe, wenn nötig**: Bei aktivem macOS-Fokus („Nicht stören") kommt
  keine Meldung (abschaltbar in den Einstellungen). Glocken-Symbol im
  Popover = manuell stummschalten (z. B. für Calls) — Tracking läuft
  weiter, offene Blöcke sammeln sich und werden danach abgefragt.
- **Tagesstrip**: Klick auf einen leeren Block öffnet den Editor gleich
  mit der **ganzen zusammenhängenden Lücke** (z. B. der ganzen Nacht);
  Klick auf einen vollen Block → bearbeiten/löschen.
- **Fazit**: Stift-Symbol im Popover (oder in der Statistik pro Tag).
- **Statistik**: Balken-Symbol — Tag- und Wochenansicht. Der Tagesstrip
  ist auch hier klickbar: damit lassen sich vergangene Tage nachtragen
  (z. B. Schlaf), inkl. „bis 24:00". Nachgetragene Blöcke fragt der
  Check-in nicht mehr ab.
- **Einstellungen**: Labels (Name, Farbe, archivieren, neue), Ton,
  Auto-Popover, Pause, Login-Start.

## Entwicklung

```bash
swift build                      # debug build
swift run TwentyTrackTestRunner  # tests (kein XCTest — eigener Runner)
```

Daten: `~/Library/Application Support/20minTrack/days/YYYY-MM-DD.json`,
Settings in UserDefaults (`com.moritzthelen.twentymintrack`).
