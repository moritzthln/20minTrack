# 20minTrack v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans
> (inline, same-session). Compact form: this plan pins file structure,
> contracts, test cases, and commit points; implementations follow the
> spec (`docs/superpowers/specs/2026-08-09-20mintrack-design.md`) and the
> Timer codebase patterns (`~/AI/Tools/Timer`).

**Goal:** macOS menu bar app that logs the day in 20-minute blocks with
labels + notes, a daily Fazit, and per-label statistics.

**Architecture:** Two SPM targets plus test runner — `TwentyCore`
(pure, fully unit-tested logic: grid math, pending range, day store,
labels, stats) and `TwentyTrackApp` (AppKit shell + SwiftUI views).
Persistence: UserDefaults + one JSON per day. No XCTest — custom
harness ported from Timer.

**Tech stack:** Swift 5.9+, SwiftUI in AppKit shell (NSStatusItem +
NSPopover + NSWindow), SPM, `ServiceManagement` for login item.

---

## File map

```
Package.swift                      targets: TwentyCore / TwentyTrackApp / TwentyTrackTestRunner
build.sh                           release build → dist/20minTrack.app → codesign → install
Resources/Info.plist               LSUIElement, com.moritzthelen.twentymintrack
Scripts/generate_icon.swift        one-shot iconset generator
Sources/TwentyCore/
  SlotGrid.swift                   wall-clock 20-min grid math (Calendar-based)
  CheckinRules.swift               pendingRange(anchor:now:) with yesterday-lookback cap
  Entry.swift                      Entry + DayFile Codable models
  DayStore.swift                   per-day JSON: insert (midnight split + overlap trim), remove, fazit
  TrackLabel.swift                 label model + six seeded defaults (stable slug ids)
  Preferences.swift                labels CRUD, checkinAnchor, chimeVolume, autoOpenPopover, trackingPaused
  StatsMath.swift                  per-label totals, tracked/untracked, share %, ISO week days
  TimeFormatting.swift             "1 h 25 min" wording, HH:mm clock
  MenuBarPresentation.swift        (paused, pendingBlocks, minutesToNext) → symbol + title
Sources/TwentyTrackApp/
  main.swift                       accessory policy, dup-instance guard, ⌘Q menu (Timer port)
  AppDelegate.swift                wires Preferences/DayStore/StatusBarController
  SoundPlayer.swift                single Glass chime at pref volume
  BoundaryScheduler.swift          timer to next boundary + wake/clock-change reschedule
  StatusBarController.swift        status item, popover, boundary → chime + auto-open, refresh
  LaunchAtLogin.swift              SMAppService.mainApp (simple: register/unregister/status)
  StatsWindowController.swift      "Statistik" window, fresh hosting view per open
  SettingsWindowController.swift   "Einstellungen" window
  Views/
    LabelPalette.swift             colorKey → Color (10 named colors)
    PillButtonStyle.swift          Timer port
    TrackerViewModel.swift         ObservableObject over Preferences + DayStore
    PopoverRootView.swift          checkin/idle switch + day strip + footer
    CheckinView.swift              span line, Von-picker, text, chips, Speichern/Überspringen
    IdleView.swift                 next check-in line
    DayStripView.swift             72-slot strip (Canvas), tap → slot callback
    LabelChipsView.swift           shared label chip grid
    SlotEditView.swift             von/bis pickers, chips, text, Speichern/Löschen
    FazitView.swift                TextEditor + Speichern
    StatsView.swift                Tag | Woche root
    StatsDayView.swift             ‹ date ›, strip + hour marks, label list, Fazit editor
    StatsWeekView.swift            ‹ KW ›, label totals, 7 mini strips
    SettingsView.swift             labels CRUD, check-in, login, data folder
Tests/TwentyTrackTestRunner/
  Harness.swift                    Timer port (test/expect/expectEqual/finishTestRun)
  main.swift                       runs all suites, finishTestRun()
  SlotGridTests.swift
  CheckinRulesTests.swift
  DayStoreTests.swift
  PreferencesTests.swift
  StatsMathTests.swift
  TimeFormattingTests.swift
  MenuBarPresentationTests.swift
```

## Contracts (pinned; later tasks must match)

```swift
// SlotGrid — all Calendar-based, DST-safe
static func floorBoundary(_ date: Date, calendar: Calendar) -> Date
static func nextBoundary(after date: Date, calendar: Calendar) -> Date  // strictly >
static func isOnGrid(_ date: Date, calendar: Calendar) -> Bool
static func boundaries(from: Date, to: Date, calendar: Calendar) -> [Date] // inclusive
static func blockCount(start: Date, end: Date, calendar: Calendar) -> Int

// CheckinRules
static func pendingRange(anchor: Date?, now: Date, calendar: Calendar)
    -> (start: Date, end: Date)?   // end = floor(now); start = max(anchor, startOfYesterday); nil anchor → nothing pending

// DayStore
init(directory: URL, calendar: Calendar)
func insert(start: Date, end: Date, labelID: String, text: String)
func entries(onDay: Date) -> [Entry]          // sorted by start
func remove(id: UUID, onDay: Date)
func fazit(onDay: Date) -> String?
func setFazit(_ text: String?, onDay: Date)   // empty/whitespace → nil
static func defaultDirectory() -> URL         // …/Application Support/20minTrack/days

// Preferences
var labels: [TrackLabel]                       // never-set → TrackLabel.defaults()
func addLabel(name: String, colorKey: String) -> TrackLabel?  // trimmed, empty → nil
func updateLabel(_ label: TrackLabel)          // replace by id
func archiveLabel(id: String)
func label(byID: String) -> TrackLabel?
var checkinAnchor: Date?
var chimeVolume: Double                        // default 0.5, clamped 0…1
var autoOpenPopover: Bool                      // default true
var trackingPaused: Bool                       // default false

// StatsMath
static func totals(_ entries: [Entry]) -> [String: TimeInterval]
static func trackedSeconds(_ entries: [Entry]) -> TimeInterval
static func untrackedSeconds(day: Date, reference: Date, entries: [Entry], calendar: Calendar) -> TimeInterval
static func percentLabel(seconds: TimeInterval, total: TimeInterval) -> String? // "39 %", "<1 %", nil at zero
static func weekDays(containing: Date, calendar: Calendar) -> [Date]  // ISO Mon…Sun

// MenuBarPresentation
static func make(paused: Bool, pendingBlocks: Int, minutesToNext: Int)
    -> (symbolName: String, title: String)
// paused → ("pause.circle", "") · pending>0 → ("20.circle.fill", "\(n)") · else ("20.circle", "\(m) m")
```

Overlap-trim rule (DayStore.insert, per day piece `[s,e)` against existing `x`):
keep if `x.end <= s || x.start >= e`; split into two if `x.start < s && x.end > e`;
left-trim to `[x.start, s)` if `x.start < s`; right-trim to `[e, x.end)` if `x.end > e`;
otherwise drop. New entry appended after trimming; entries saved sorted by start.

## Tasks (TDD: red → green → commit, one commit per task)

- [ ] **T1 Scaffold** — Package.swift, Harness.swift, empty suite files +
  runner main, `.gitignore` (`.build/`, `dist/`, `.DS_Store`).
  Verify: `swift build` + `swift run TwentyTrackTestRunner` → "0 tests".
  Commit: `chore: scaffold SPM package and test harness`
- [ ] **T2 SlotGrid** — tests: floor at :00/:07/:20/:39/:59.59 → :00/:00/:20/:20/:40;
  next after exact boundary = +20; isOnGrid true/false incl. non-zero
  seconds; boundaries inclusive count over 1 h = 4; blockCount 20 min = 1,
  100 min = 5, 0 = 0. Commit: `feat: add SlotGrid wall-clock grid math`
- [ ] **T3 CheckinRules** — tests: nil anchor → nil; anchor = floor(now) →
  nil; 40 min gap → 2 blocks; now mid-block excludes current block;
  anchor 3 days back → clamped to start of yesterday; anchor in the
  future → nil. Commit: `feat: add CheckinRules pending range`
- [ ] **T4 DayStore** — tests (temp dir): insert + read back sorted;
  midnight-crossing insert lands in two day files; exact overlap
  replaces; left/right trim; middle split keeps text+label both sides;
  containing insert drops old; remove(id:); fazit set/get, empty → nil;
  corrupt file → empty + insert still works; end<=start discarded.
  Commit: `feat: add DayStore with midnight split and overlap trim`
- [ ] **T5 Preferences + TrackLabel** — tests (fresh suite-named
  UserDefaults, removePersistentDomain in setup): never-set → 6 defaults
  in order with expected slugs/colors; add trims + rejects empty +
  appends; update renames/recolors by id; archive hides nowhere but sets
  flag; label(byID:) resolves archived; anchor roundtrip; volume clamp;
  toggles' defaults. Commit: `feat: add Preferences with label store`
- [ ] **T6 StatsMath + TimeFormatting** — tests: totals sums per label
  across entries; trackedSeconds; untracked for past day = 24 h −
  tracked, for today uses reference clamp, never negative; percentLabel
  "39 %"/"<1 %"/nil-at-zero/halves-round-up; weekDays Monday start, 7
  days, contains input date; wording "45 min"/"1 h 25 min"/"0 min";
  clock "09:05". Commit: `feat: add stats math and time formatting`
- [ ] **T7 MenuBarPresentation** — tests: three states incl. paused
  precedence over pending. Commit: `feat: add menu bar presentation`
- [ ] **T8 App shell** — main/AppDelegate/SoundPlayer/BoundaryScheduler/
  StatusBarController (presentation wired, 10 s title refresh, boundary →
  chime + conditional auto-open, wake/clock reschedule), LaunchAtLogin.
  Verify: `swift build`. Commit: `feat: add app shell with boundary scheduler`
- [ ] **T9 Popover UI** — TrackerViewModel + views (Checkin/Idle/Strip/
  Chips/Edit/Fazit/Root, palette, pill style). Save advances anchor via
  VM; skip advances anchor only. Verify: `swift build`.
  Commit: `feat: add popover check-in UI`
- [ ] **T10 Stats window** — StatsView Tag|Woche + controller.
  Verify: `swift build`. Commit: `feat: add statistics window`
- [ ] **T11 Settings window** — SettingsView + controller + login toggle.
  Verify: `swift build`. Commit: `feat: add settings window`
- [ ] **T12 Bundle + install** — Info.plist, icon script + icns,
  build.sh; run: `swift run TwentyTrackTestRunner` (all green) then
  `./build.sh`; launch installed app, `pgrep TwentyTrackApp` after 3 s.
  Commit: `feat: add app bundle build and icon`
- [ ] **T13 Docs** — README.md, CLAUDE.md, PROJECT_STATE.md.
  Commit: `docs: add project docs and state`

## Verification gate (before "fertig")

`swift run TwentyTrackTestRunner` all green · `./build.sh` installs ·
app process alive after launch · every file ≤ 800 lines, functions ≤ 80.
