# 20minTrack v1 — Design

2026-08-09. New app, sibling of `~/AI/Tools/Timer` (same platform, same
house style: Swift menu bar app, SPM without Xcode, custom test runner,
local-only persistence, German UI / English code).

## Purpose

Track the day in 20-minute blocks. Every 20 minutes the app asks "Was
hast du gemacht?" — you write one line and assign a label. At the end of
the day you write a Tagesfazit. Statistics show how much time went into
each label per day and per week.

Default labels (user-specified, editable later in settings):
Fokus Arbeit MMA · Kein Fokus · Orga/Other · Schlafen · Spaß · Sport.

## Decisions made without interview (autonomous session)

The user asked to plan and implement in one go. These assumptions are
recorded for review:

1. **Platform**: native macOS menu bar app like Timer ("neue App, die in
   die Richtung geht" — the reference is a Swift menu bar app; a
   20-minute nag must live in the menu bar, not in a browser tab).
2. **Grid**: blocks are wall-clock aligned (:00 / :20 / :40). Predictable,
   clean statistics; 72 blocks per day.
3. **Gaps**: a missed prompt is not lost — the next check-in covers the
   whole span since the last entry (that is how "Schlafen" gets logged
   the next morning). Untracked time stays visible as "Nicht erfasst".
4. **Persistence**: local only — UserDefaults for settings, one JSON file
   per day. No backend, no sync (Timer precedent).
5. **Statistics**: Tag and Woche views. No month view, no export in v1.

## Core concept

- The day is a grid of 20-minute slots aligned to the wall clock.
- Entries are half-open intervals `[start, end)` snapped to the grid,
  carrying a label id and a free-text note. Entries never overlap.
- The **check-in anchor** is a persisted date: everything before it is
  settled (logged or deliberately skipped). The **pending range** runs
  from the anchor to the most recent grid boundary ≤ now.
- While tracking is active, every boundary plays a soft chime and opens
  the popover with the check-in form for the current pending range.
- Saving a check-in writes one entry over the chosen span and advances
  the anchor. "Überspringen" advances the anchor without writing.
- The anchor never looks back further than the start of *yesterday*
  (a week offline must not produce a monster block).

## Data model

### Entry (per-day JSON)

```swift
struct Entry: Codable, Equatable {
    let id: UUID
    let start: Date      // on grid
    let end: Date        // on grid, > start, same local day
    let labelID: String
    let text: String
}
```

`days/YYYY-MM-DD.json` under `~/Library/Application Support/20minTrack/`:

```json
{ "entries": [Entry], "fazit": "optional daily conclusion" }
```

- **Midnight split**: an entry saved across midnight is stored as two
  entries in two day files (Timer's `FocusLog`/`ActivityStore` pattern).
- **Overlap trim**: inserting an entry trims or splits any existing
  entries it overlaps — last write wins. This one rule powers editing,
  relabeling, and corrections with no special cases.
- Corrupt or missing files read as an empty day.

### Labels (UserDefaults, JSON-encoded)

```swift
struct Label: Codable, Equatable {
    let id: String        // UUID string, stable
    var name: String
    var colorKey: String  // named palette color
    var archived: Bool    // hidden from picker, still resolvable in stats
}
```

Never-set → seeded with the six defaults (green, red, blue, indigo,
orange, teal). Archive instead of delete so history stays resolvable;
a written empty list stays empty (Timer's never-set vs. cleared split).

### Preferences (UserDefaults domain `com.moritzthelen.twentymintrack`)

- `labels` (above), `checkinAnchor: Date?` (nil → floor(now) at launch),
  `chimeVolume` (0…1, default 0.5), `autoOpenPopover` (default true),
  `trackingPaused` (default false).

## Core logic (TwentyCore, all TDD)

- `SlotGrid` — pure grid math on `Calendar`: `floorBoundary(_:)`,
  `nextBoundary(after:)`, `isOnGrid(_:)`, `boundaries(in:)`,
  `blockCount(start:end:)`. DST-safe (minute components, not epoch math).
- `CheckinRules` — pure: `pendingRange(anchor:now:)` applying the
  floor/lookback rules; nil when nothing is pending.
- `DayStore` — per-day JSON files (injected directory): `insert(_:)`
  with midnight split + overlap trim, `entries(onDay:)` sorted,
  `remove(id:onDay:)`, `fazit(onDay:)` / `setFazit(_:onDay:)`.
- `LabelStore` (in `Preferences`) — seeding, add / rename / recolor /
  archive, lookup incl. archived.
- `StatsMath` — pure: `totals(entries:)` → `[labelID: seconds]`,
  `trackedSeconds`, `untrackedSeconds(dayStart:now:tracked:)` (past time
  only), share percentages (German "39 %" formatting, `UsageShare`
  precedent), ISO-week day list (Monday start).
- `TimeFormatting` — "1 h 25 min" / "45 min" wording (Timer port).
- `MenuBarPresentation` — pure: (paused, pendingBlocks, minutesToNext) →
  status item symbol + title ("7 m", pause icon when paused, filled
  badge symbol while a check-in is pending).

## App shell (TwentyTrackApp)

- `StatusBarController` — status item + popover (~300 pt wide), owns the
  boundary scheduler (one `Foundation.Timer` to the next boundary,
  1 s tolerance; reschedule on wake/clock change via
  `NSWorkspace.didWakeNotification` + `NSSystemClockDidChange`). On
  boundary: unless paused → chime + auto-open popover (if enabled) +
  refresh. Exactly one prompt after sleep — no catch-up storm (the
  pending range absorbs missed boundaries by construction).
- Chime: `NSSound(named: "Glass")` once at `chimeVolume` (no bundled
  sounds in v1).
- Popover views (SwiftUI):
  - **CheckinView** (pending ≠ nil): "Was hast du gemacht?", span line
    "12:40 – 14:20 · 5 Blöcke" with a "Von:"-picker over the pending
    boundaries (default = anchor), auto-focused text field (Return
    saves), label chips (color dot + name, one selected), prominent
    "Speichern" (disabled without label), quiet "Überspringen".
  - **IdleView** (no pending): "Nächster Check-in um 14:40 · in 7 min"
    plus today's colored day strip.
  - **Day strip** (shared component): 72 slots, label colors, gray =
    untracked, thin "now" marker; click on a slot opens the editor.
  - **SlotEditView**: von/bis pickers (grid times), text, label chips,
    "Speichern" (insert with trim = edit/relabel), "Löschen" for an
    existing entry.
  - **FazitView**: TextEditor for today's Fazit, "Speichern".
  - Footer: Fazit · Statistik · "⋯" menu (Tracking pausieren ✓,
    Einstellungen…, 20minTrack beenden ⌘Q).
- `StatsWindowController` — "Statistik", resizable, fresh hosting view
  per open (Timer pattern):
  - **Tag**: ‹ date › navigation, large day strip with hour ticks,
    per-label list (color, name, duration, share of tracked time),
    "Nicht erfasst" line, editable Fazit (commit on focus loss/Return).
  - **Woche**: ‹ KW n · range › navigation (forward capped at current
    week), per-label week totals + share, seven Mon–Sun mini strips
    with day sums.
- `SettingsWindowController` — "Einstellungen": Labels (rename inline,
  archive, add with palette color menu), Check-in (auto-open toggle,
  volume slider + test), Tracking pausieren, Login-Start
  (`SMAppService.mainApp`, simple status line — no LaunchAgent fallback
  in v1), data folder reveal button.
- `main.swift` — accessory activation policy, duplicate-instance guard,
  hidden ⌘Q menu (Timer port).

## Build & test

- SPM targets: `TwentyCore` (lib) / `TwentyTrackApp` (exe) /
  `TwentyTrackTestRunner` (exe; module names cannot start with a digit —
  the bundle is still `20minTrack.app`).
- Custom harness (`Harness.swift` port); run: `swift run
  TwentyTrackTestRunner`. **No XCTest** (CLT-only machine).
- `build.sh`: release build → `dist/20minTrack.app` → ad-hoc codesign →
  install to `/Applications`. Icon generated once by
  `Scripts/generate_icon.swift` → `Resources/AppIcon.icns`.
- Info.plist: `LSUIElement` true, id `com.moritzthelen.twentymintrack`,
  name `20minTrack`.

## Error handling

- Corrupt day file → empty day (never crash, never overwrite until the
  next insert).
- Clock jumps / DST: scheduler always re-derives the next boundary from
  `Calendar`; grid math never does epoch arithmetic across offsets.
- Deleted/archived label referenced by old entries → resolves by id for
  stats; unknown id renders as "Unbekannt" in gray.
- Empty check-in text is allowed (label suffices); empty label is not.

## Non-goals (v1 — do not add unasked)

Reminders via Notification Center, bundled/generated sounds, export,
month view, goals/streaks/heatmaps, sync/iCloud, hotkeys, floating
window, auto-prompted Fazit at a fixed time, editing days before
yesterday's lookback via check-in (the stats/strip editor covers that),
multi-device, week strips zoom/tooltips.

## Success criteria

- All unit tests green (`swift run TwentyTrackTestRunner`).
- `./build.sh` installs a signed app that launches, shows the status
  item, prompts at the next boundary, saves entries, and renders stats.
- File and function size limits respected (800/80).
