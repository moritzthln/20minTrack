<div align="center">

<img src="docs/images/icon.png" width="128" alt="20minTrack App-Icon">

# 20minTrack

**Wissen, wo dein Tag wirklich geblieben ist — in 20-Minuten-Blöcken.**

Eine kleine macOS-Menüleisten-App, die alle 20 Minuten fragt: *„Was hast du gemacht?"*
Eine Taste zum Antworten, keine Lücken, ehrliche Statistik am Ende der Woche.

[English](README.md) · [**Installieren**](#installieren) · [Funktionen](#funktionen) · [Datenschutz](#datenschutz)

<br>

<img src="docs/images/checkin.png" width="620" alt="Das Check-in-Fenster">

</div>

---

## Worum geht's

Timer messen, was du *geplant* hast. 20minTrack hält fest, was du *gemacht* hast.

Alle 20 Minuten zur vollen Uhrzeit (:00, :20, :40) erscheint mitten auf dem Bildschirm ein kleines Fenster. Label wählen — *Fokus Arbeit*, *Calls*, *Ablenkung*, … —, optional ein paar Worte notieren, <kbd>Enter</kbd>. Zwei Sekunden, dann weiter.

So entsteht ein lückenloses Bild deines Tages: wie viel echter Fokus drin war, wo der Nachmittag verschwunden ist und ob du deine Ziele triffst.

## Was ist anders?

Es gibt drei übliche Arten, Zeit auf dem Mac zu tracken — und jede hat eine Lücke:

- **Start/Stopp-Timer** (Toggl, Clockify, …) funktionieren nur, wenn man an *Start* und *Stopp* denkt. Genau die vergessenen Stunden wären die interessanten.
- **Automatische Tracker** (Timing, RescueTime, Rize, …) wissen, welche App offen war — nicht, was du gemacht hast. Zwei Stunden Chrome können Recherche oder YouTube sein. Dazu kosten sie oft über 100 $ im Jahr.
- **Intervall-Abfragen** (Daily, TagTime) fragen regelmäßig nach — die richtige Idee. Daily ist ein Abo, TagTime fragt zu zufälligen Zeitpunkten und liefert damit Schätzungen statt eines vollständigen Tages.

20minTrack nimmt die Intervall-Idee und macht sie lückenlos:

| | Start/Stopp-Timer | Automatische Tracker | 20minTrack |
|---|:---:|:---:|:---:|
| Läuft, ohne dass man an Start denken muss | ➖ | ✅ | ✅ |
| Weiß, *was* du gemacht hast, nicht nur welche App offen war | ✅ | ➖ | ✅ |
| Vergessene Zeit kommt zurück statt zu verschwinden | ➖ | ➖ | ✅ |
| Jede Minute des Tages erfasst | ➖ | ➖ | ✅ |
| Bewertet die *Qualität* der Arbeit (Fokus / Halbfokus / Ablenkung) | ➖ | geraten anhand der App | ✅ du entscheidest |
| Kostenlos und Open Source | teils | ➖ | ✅ |
| 100 % lokal, kein Account | teils | teils | ✅ |

**Was nur 20minTrack macht** (soweit wir wissen):

- **Nichts geht verloren.** Verpasste Blöcke warten als offener Zeitraum, bis du sie gelabelt hast. Mac war nachts zu? Ein Klick: *Schlafen*.
- **Die Uhr ist das Raster.** Blöcke starten um :00, :20 und :40 — jeder Tag hat dieselben 72 Felder, Tage und Wochen sind direkt vergleichbar.
- **Zwei Sekunden pro Antwort.** Letztes Label vorausgewählt, <kbd>Enter</kbd> speichert. Schnell genug, dass man dranbleibt.
- **Automatik als Hinweis, nicht als Urteil.** Der Check-in zeigt, welche Apps und Seiten du benutzt hast — entscheiden tust du.
- **Ehrlichkeit eingebaut.** Leere Tage zählen später als Ablenkung. Vor der eigenen Statistik kann man sich nicht verstecken.

**Für wen?** Selbstständige und Gründer, alle, die an Deep Work arbeiten, Menschen mit ADHS oder „Zeitblindheit" (der 20-Minuten-Anker und die farbigen Blöcke machen den Tag sichtbar) und Studierende, die ehrlich wissen wollen, wie viel sie wirklich lernen.

## Funktionen

- **Check-in mit einer Taste** — das letzte Label ist vorausgewählt, <kbd>Enter</kbd> speichert. <kbd>⌘1</kbd>–<kbd>⌘9</kbd> und <kbd>⌘0</kbd> wählen ein Label und speichern sofort. Zwei Labels gewählt = der Block wird 10/10 aufgeteilt.
- **Keine Lücken** — Mac zugeklappt, im Meeting? Verpasste Blöcke werden zu **einem offenen Zeitraum**, der beim nächsten Mal abgefragt wird. Mit *Von / bis* stückweise ausfüllen; das Fenster bleibt, bis alles erfasst ist. *Später* verschiebt, verwirft aber nie.
- **Gedächtnisstütze** — „In dieser Zeit benutzt: Xcode 21 min · github.com 9 min" steht direkt im Check-in.
- **Ehrliche Statistik** — Tag, Woche, Monat, Jahr: Fokuszeit, Fokus-Quote, Ablenkung, Balken pro Label, klickbare Tagesstreifen zum Nachtragen. Ab vorgestern zählt Unerfasstes als Ablenkung.
- **Tagesziele** pro Label (z. B. 4 h 30 min Fokus, 8 h Schlaf) mit Fortschrittsbalken.
- **Tagesfazit** — Erinnerung am Abend; verpasst, kommt morgens um 9:30 noch einmal.
- **Rücksichtsvoll** — still bei macOS-Fokus, Stummschalten für Calls (20 min / 1 h / 2 h / bis morgen), geplante Abwesenheiten (Urlaub) ohne Abfragen.
- **Zweisprachig** — Deutsch und Englisch, folgt der Systemsprache, in den Einstellungen umschaltbar.

<table>
<tr>
<td width="50%"><img src="docs/images/stats-week.png" alt="Wochenstatistik"></td>
<td width="50%"><img src="docs/images/stats-day.png" alt="Tagesstatistik"></td>
</tr>
</table>

## Installieren

**Voraussetzungen:** macOS 13 Ventura oder neuer · Apple Silicon oder Intel

### Variante 1 — eine Zeile im Terminal (empfohlen)

```bash
curl -fsSL https://raw.githubusercontent.com/moritzthln/20minTrack/main/install.sh | bash
```

Lädt das neueste Release, installiert nach `/Applications` und startet die App. Oben in der Menüleiste erscheint ein Kreis mit Countdown.

### Variante 2 — manuell

1. **`20minTrack.zip`** aus dem [neuesten Release](https://github.com/moritzthln/20minTrack/releases/latest) laden.
2. Entpacken und **20minTrack.app** in den Ordner *Programme* ziehen.
3. Die App ist nicht von Apple notarisiert, deshalb einmalig im Terminal:
   ```bash
   xattr -cr /Applications/20minTrack.app
   ```
4. App öffnen.

> **Tipp:** Kreis in der Menüleiste → **⋯** → **Einstellungen** → **Beim Anmelden starten**.

### Variante 3 — selbst bauen

```bash
git clone https://github.com/moritzthln/20minTrack.git
cd 20minTrack
./build.sh
```

Braucht die Xcode Command Line Tools (`xcode-select --install`).

## Bedienung

| Taste | Aktion |
|---|---|
| <kbd>Enter</kbd> | Mit gewähltem Label speichern |
| <kbd>⌘1</kbd> … <kbd>⌘9</kbd>, <kbd>⌘0</kbd> | Label 1–10 wählen und sofort speichern |
| <kbd>Esc</kbd> | Später — Zeitraum bleibt offen |
| Klick auf gewähltes Label | Abwählen (speichert nie) |

Klick auf einen Block im Tagesstreifen öffnet den Editor; Klick auf einen leeren Block öffnet ihn über die ganze Lücke, Ziehen markiert einen Bereich. ⌘Q beendet die App absichtlich nicht — Beenden per Rechtsklick auf den Kreis.

## Datenschutz

Alles bleibt auf deinem Mac — kein Account, keine Cloud, keine Netzwerkzugriffe.

- Einträge & Fazit: `~/Library/Application Support/20minTrack/days/JJJJ-MM-TT.json`
- App-Nutzung (Gedächtnisstütze): `~/Library/Application Support/20minTrack/usage/`
- Einstellungen: `~/Library/Preferences/com.moritzthelen.twentymintrack.plist`

Für Safari, Chrome und Arc kann die Benutzt-Liste auch die Website zeigen — macOS fragt einmal pro Browser um Erlaubnis, Ablehnen ist kein Problem.

## Entwicklung

```bash
./test.sh       # Tests (eigener Runner, kein XCTest nötig)
./build.sh      # Universal-Build + Installation
./package.sh    # dist/20minTrack.zip zum Weitergeben
```

Architektur-Notizen: [`CLAUDE.md`](CLAUDE.md).

Mitmachen ist willkommen — siehe [CONTRIBUTING.md](CONTRIBUTING.md) (auf Englisch).

## Lizenz

[MIT](LICENSE) © Moritz Thelen
