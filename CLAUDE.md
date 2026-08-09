# CLAUDE.md — 20minTrack

macOS menu bar time tracker: the day is a grid of wall-clock-aligned
20-minute blocks. Every 20 minutes the app chimes and asks "Was hast du
gemacht?" — one line of text plus a label. Missed blocks (sleep, away)
collapse into one pending range settled at the next check-in; a strip of
today's blocks allows manual edits. Daily Fazit, per-label statistics
(Tag/Woche). Sibling of `~/AI/Tools/Timer` — same house style.

## Tech stack (do NOT apply the workspace default stack here)

- Swift 5.10, SwiftUI views inside an AppKit shell (NSStatusItem +
  NSPopover + NSWindow), menu-bar-only (`LSUIElement`)
- Swift Package Manager only — **no Xcode project**; built via `build.sh`
- **No XCTest**: Command Line Tools only. Tests run through a custom
  runner executable.
- No backend, no network. Persistence: UserDefaults (domain
  `com.moritzthelen.twentymintrack`) + one JSON file per day under
  `~/Library/Application Support/20minTrack/days/`

## Commands

- Test: `swift run TwentyTrackTestRunner`  (NOT `swift test`)
- Build (debug): `swift build`
- Build + install release app: `./build.sh` → `/Applications/20minTrack.app`
- Note: `xcrun … PlatformPath` lines in build output are harmless CLT noise.

## Architecture

- `Sources/TwentyCore/` — library target, all testable logic:
  - `SlotGrid` — wall-clock 20-min grid math (floor/next/boundaries/
    blockCount), Calendar-based, DST-safe
  - `CheckinRules` — `pendingRange(anchor:now:)`: anchor → last completed
    boundary, lookback capped at start of yesterday
  - `Entry` + `DayStore` — per-day JSON; `insert` splits at midnight and
    trims overlapped entries (last write wins — powers editing), Fazit
    get/set, corrupt file reads as empty day
  - `GapFill` — interval subtraction; check-ins fill only untracked gaps
    so manual strip edits survive
  - `TrackLabel` + `Preferences` — six seeded labels (stable slug ids:
    focus-mma, no-focus, orga, sleep, fun, sport), add/update/archive
    (archived = hidden from pickers, still resolvable), checkinAnchor,
    chimeVolume, autoOpenPopover, trackingPaused
  - `StatsMath` — per-label totals, untracked seconds, "39 %" share
    labels, ISO week days (Monday start, locale-independent)
  - `TimeFormatting` ("1 h 25 min", "09:05") · `MenuBarPresentation`
    (paused → pause icon; pending → filled symbol + block count; else
    "n m" to next boundary)
- `Sources/TwentyTrackApp/` — executable (bundle: `20minTrack.app`):
  - `main.swift` — accessory policy, duplicate-instance guard, ⌘Q menu
  - `StatusBarController` — status item + popover owner; boundary →
    reload, chime, auto-open (once per block via `lastPromptedEnd`);
    10 s title refresh; 2 s post-launch pending check (login case);
    fresh NSHostingController per popover open (state reset)
  - `BoundaryScheduler` — one timer to the next boundary + wake/clock
    observers (no catch-up storm — pending absorbs missed boundaries)
  - `SoundPlayer` (single Glass chime) · `LaunchAtLogin` (SMAppService,
    no LaunchAgent fallback) · `StatsWindowController` ·
    `SettingsWindowController`
  - `Views/` — `TrackerViewModel` (all writes go through it; check-in
    saves fill gaps then advance the anchor; strip edits never move the
    anchor), `PopoverRootView` (checkin/idle/edit/fazit modes + today
    strip + footer), `CheckinView`, `IdleView`, `SlotEditView`,
    `FazitView`, `DayStripView` (Canvas, tap → slot), `LabelChipsView`,
    `LabelPalette`, `PillButtonStyle`, `StatsView` + `StatsDayView` +
    `StatsWeekView` + `LabelTotalsList`, `SettingsView`
- `Tests/TwentyTrackTestRunner/` — custom harness + suites

## Conventions

- UI strings German, code/comments/commits English
- Spec: `docs/superpowers/specs/2026-08-09-20mintrack-design.md`
- Plan: `docs/superpowers/plans/2026-08-09-20mintrack-implementation.md`
- Hard limits: files ≤ 800 lines, functions ≤ 80 lines
- Non-goals v1 (do not add unasked): Notification Center, bundled
  sounds, export, month view, goals/streaks/heatmaps, sync, hotkeys,
  floating window, auto-prompted Fazit
