# CLAUDE.md — 20minTrack

macOS menu bar time tracker: the day is a grid of wall-clock-aligned
20-minute blocks. Every 20 minutes the app chimes and asks "Was hast du
gemacht?" — one line of text (optional) plus a label. Missed blocks
(sleep, away) collapse into one pending range settled at the next
check-in; a strip of today's blocks allows manual edits. Daily Fazit,
per-label statistics (Tag/Woche). v2 adds a local frontmost-app recorder
feeding a "Benutzt: Chrome 12 min …" memory-aid line into the check-in
and the slot editor, makes the statistics day strip clickable (backfill
editor for past days, "24:00" end option), and advances the check-in
anchor over manually backfilled blocks so they never re-prompt.
v3 is the no-gap fast flow: "Später" replaced skip (the span stays
pending until labeled — nothing is silently dropped), the last saved
label is preselected (`Preferences.lastLabelID` — Return alone saves),
chips are a toggle selection of up to two labels (two = 10/10 split per
block via `HalfSplit`; a click on a selected chip deselects, it never
saves), ⌘1–⌘9 (and ⌘0 for a 10th label) pick-and-save a single label, and tapping an
empty slot opens the editor over the whole surrounding gap (capped at
the running block today). v4: the popover is wide (540 pt) and every
boundary pops a centered floating check-in window
(`CheckinWindowController`: NSWindow, level .floating, all Spaces +
fullScreenAuxiliary, re-centered on every show, Esc postpones, closes
itself when nothing is pending — `autoOpenPopover` now gates this
window instead of the popover). v5: prompt suppression — while a macOS
Focus mode is active (`FocusAssertions` parses
~/Library/DoNotDisturb/DB/Assertions.json, fail-open; settings toggle
`suppressDuringFocus`) and via the manual popover bell — a timed mute (`mutedUntil` pref:
20 min / 1 h / 2 h / until tomorrow, expires on its own, never silent
forever); suppressed boundaries leave `lastPromptedEnd` untouched.
v6: bilingual UI — `L10n.swift` (`loc(de, en)`, `germanUI`,
`l10nLocale`) follows the system language, `TrackLabel.defaults(german:)`
seeds English label names on non-German systems (ids unchanged), the
share package carries a German and an English install guide.
Sibling of `~/AI/Tools/Timer` — same house style.

## Tech stack (do NOT apply the workspace default stack here)

- Swift (5.10+; machine has full Xcode with Swift 6.3 since 2026-08-09),
  SwiftUI views inside an AppKit shell (NSStatusItem + NSPopover +
  NSWindow), menu-bar-only (`LSUIElement`)
- Swift Package Manager only — **no Xcode project**; built via `build.sh`
- Tests run through a custom runner executable (kept deliberately even
  though XCTest is available now — same harness as the Timer app).
- No backend, no network. Persistence: UserDefaults (domain
  `com.moritzthelen.twentymintrack`) + one JSON file per day under
  `~/Library/Application Support/20minTrack/days/` (entries + Fazit) and
  `…/20minTrack/usage/` (app usage segments)

## Commands

**One toolchain standard: Command Line Tools** (both scripts pin
`DEVELOPER_DIR`). The machine also has Xcode 26 — do NOT build the app
with it: its SDK displaces the status-item popover (~2 cm). When Apple
fixes that, remove the pin in `build.sh` + `test.sh` together.

- Test: `./test.sh`  (custom runner — NOT `swift test`)
- Build + install release app: `./build.sh` → `/Applications/20minTrack.app`
- Share package: `./package.sh` → `dist/20minTrack.zip`
- Note: `xcrun … PlatformPath` lines in build output are harmless CLT noise.
- After any accidental Xcode-toolchain build: `rm -rf .build` — mixed
  toolchain artifacts break the CLT link (missing coro stub symbols).

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
  - `DayAttribution` — settled days (older than yesterday, i.e. past the
    check-in lookback) count their remaining gaps as Ablenkung
    ("deliberately untracked"); today/yesterday stay "Nicht erfasst",
    and a day without a single entry is never attributed (pre-install /
    Mac-off days would otherwise become 24 h of distraction). Used by
    all four stats tabs.
  - `Absence` + `AbsenceRules` — planned away periods (whole days,
    inclusive; stored in Preferences.absences): absent days never
    prompt (check-in + Fazit), never count gaps as Ablenkung, and
    `normalizedAnchor` walks the anchor to the first midnight after
    chained absences so the return check-in skips them
  - `TimeFormatting` ("1 h 25 min", "09:05") · `MenuBarPresentation`
    (paused → pause icon; pending → filled symbol + block count; else
    "n m" to next boundary)
  - v2: `AppUsageSegment`/`AppUsageTotal` + `AppUsageStore` (per-day
    JSON, heartbeat `upsert` insert-or-replace by id with midnight
    split, `totals(in:)` for two-adjacent-day ranges) + `AppUsageMath`
    (clipped per-bundle aggregation, latest name wins) ·
    `AnchorAdvance` (anchor walks over fully covered blocks — backfilled
    time counts as settled; used in `TrackerViewModel.normalizeAnchor`
    together with the future-anchor clamp)
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
  - v2 `AppUsageTracker` — frontmost-app recorder: didActivate opens/
    closes segments, sleep/lock close, wake/unlock reopen, 60 s
    heartbeat upsert, `flush()` before usage reads, own app never
    recorded, `trackingPaused` pauses it. **No input-idle detection**
    (documented limitation: an app left frontmost counts until
    lock/sleep)
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
- Specs: `docs/superpowers/specs/2026-08-09-20mintrack-design.md` (v1),
  `docs/superpowers/specs/2026-08-09-20mintrack-v2-design.md` (v2)
- Plan: `docs/superpowers/plans/2026-08-09-20mintrack-implementation.md`
  (v1; v2 executed spec-direct)
- Hard limits: files ≤ 800 lines, functions ≤ 80 lines
- Non-goals v1 (do not add unasked): Notification Center, bundled
  sounds, export, month view, goals/streaks/heatmaps, sync, hotkeys,
  floating window, auto-prompted Fazit
- Non-goals v2: automatic sleep window / auto-fill (explicitly rejected
  by the user), input-idle presence detection, browser-tab domains,
  usage statistics views, multi-day spans in one editor save
