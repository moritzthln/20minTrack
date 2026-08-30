# PROJECT_STATE — 20minTrack

## Status

v1 + v2 + v3 implemented and merged to `main` (2026-08-09). Menu bar
20-minute tracker: grid check-ins with chime + auto-popover, per-day
JSON store (midnight split, overlap trim, gap-filling saves), today
strip with slot editor, Tagesfazit, statistics (Tag/Woche), settings.
v2: local frontmost-app recorder feeding a "Benutzt: …" line into
check-in + slot editor, clickable stats day strip (backfill past days,
"24:00" option), anchor advance (backfilled blocks never re-prompt).
v3 (user: "immer alles ausgefüllt, intuitiv, zeitsparend"): "Später"
replaced skip — spans stay pending until labeled, no silent gaps;
last label preselected (Return alone saves), click-on-selected-chip
saves, ⌘1–⌘9 pick-and-save, empty-slot tap expands to the whole gap.
v4 (user: "sehr breit" + "aufploppen, quasi gezwungen"): popover
540 pt wide; every boundary pops a centered floating check-in window
(all Spaces, above fullscreen, Enter saves / Esc postpones, closes
itself once nothing is pending) — user-confirmed live at 10:40.
v5 (user: "im Fokus keine Meldung + selber anklicken für Calls"):
prompts stay silent while a macOS Focus is active (Assertions.json via
`FocusAssertions`, fail-open, settings toggle) and via the manual bell
button in the popover footer (`muted` pref) — tracking continues,
suppressed boundaries do not set lastPromptedEnd, so the next boundary
after unmute prompts normally.
Independent code review done — both blockers and both warnings fixed,
cheap nits hardened. 68 unit tests green. Installed to
/Applications/20minTrack.app and running.

## In Progress

- (nothing)

## Next Up

- User live-E2E: chime at a real boundary, save a check-in (usage line
  visible after some minutes of recording), backfill yesterday via
  Statistik → Tag → strip click, write a Fazit, check Woche view
- Settings: enable "Beim Anmelden starten" so tracking survives reboots
- Optional: private GitHub repo + push (still local-only)

## Known Issues

- UI not visually inspected (headless session): views verified by
  build + launch; core logic unit-tested (67)
- Usage recorder has no input-idle detection (documented v2 non-goal):
  an app left frontmost counts until screen lock / sleep
- DST fall-back hour (once a year): repeated wall times floor to the
  first occurrence — the repeated hour prompts late (at 03:00) as one
  collected check-in; absolute-time accounting stays correct (review
  nit, accepted)
- Timezone change requires an app restart (Calendar snapshot; review
  nit, accepted for a personal app)
- Day-file JSON stores Apple reference timestamps, not ISO dates
  (review nit; kept — live data already exists, decoder compatibility
  not worth it)

## Recent Decisions

- 2026-08-09 (v3): Skip is gone — "Später" only closes the popover; the
  anchor moves exclusively through saving (or AnchorAdvance over
  manually covered blocks). The lookback cap (start of yesterday)
  remains the only way time can end up permanently unlabeled; those
  days are backfilled via the stats editor
- 2026-08-09 (v3): ⌘-shortcuts save immediately (pick + save in one),
  implemented as invisible keyboard-shortcut buttons so the auto-focused
  text field keeps plain digits
- 2026-08-09 (v2): NO automatic sleep window — user explicitly rejected
  it ("nein keins"); sleep is backfilled manually (check-in over the
  night gap or stats editor), text stays optional everywhere
- 2026-08-09 (v2): Check-in usage line loads on appear and on span
  changes (not per keystroke); the recorder flushes before every read
- 2026-08-09 (v2): Usage segments keep one id across midnight pieces —
  ids are unique per day file, so replace-by-id heartbeats stay correct
- 2026-08-09 (v2): Anchor normalization = clamp future anchors
  (clock set back) + max with start-of-yesterday + AnchorAdvance over
  covered blocks, all in `TrackerViewModel.normalizeAnchor`
- 2026-08-09 (review): Rename/recolor persists per keystroke into
  UserDefaults but no longer posts notifications or reloads day files;
  empty rename never persists (`updateLabel` guard)
- 2026-08-09 (review): Check-in drafts reset only when the pending
  START moves — a boundary firing mid-typing grows the end without
  wiping input
- 2026-08-09 (v1): Wall-clock 20-min grid; one persisted checkinAnchor;
  lookback capped at start of yesterday; check-in fills only gaps
  (GapFill) so manual edits survive; overlap trim = the single editing
  rule; labels archive instead of delete; single Glass chime
- 2026-08-09 (v1): Native macOS menu bar app in the Timer house style
  (user pointed at Timer as the reference)

## Recently Done

- 2026-08-30: Labels follow the language — TrackLabel.effectiveGerman() (override key checked first, shared constant with L10n) drives defaults(); TrackLabel.relocalized(labels:german:) (TDD) renames stock-named labels on language switch (custom names + ids + goals untouched), applied by the settings language picker

- 2026-08-30: Universal binary — build.sh builds both slices by triple (CLT has no xcbuild for --arch) and lipo-merges them (Timer pattern); installed app + share package verified "x86_64 arm64", Intel Macs now supported

- 2026-08-30: Manual language picker — germanUI/l10nLocale became computed (UserDefaults languageOverride wins over system language), settings General section gained System/Deutsch/English picker (fresh-per-open windows pick it up immediately, window titles fully after restart)

- 2026-08-30: Localization audit — automated scan for unlocalized German string literals found 4 leftovers (strip tooltip, hidden app/edit menu titles) + German-style day date format + Core absence fallback name, all fixed (localized in UI); scan now CLEAN

- 2026-08-19: Bilingual UI — L10n.swift (loc(de,en) + l10nLocale following the system language), every user-facing string in views/windows/menus localized, TrackLabel.defaults(german:) seeds English names on non-German systems (ids stable, tests cover both), date formatters switched from hardcoded de_DE to l10nLocale, package.sh adds an English install guide

- 2026-08-19: Timed mute — muted Bool replaced by mutedUntil Date (isMuted(now:), expiry exclusive, TDD); popover bell is now a menu (20 min / 1 h / 2 h / bis morgen, when muted: "Stumm bis …" + reactivate); silence always expires on its own

- 2026-08-19: Absence visibility — AbsenceSummaryLine ("Abwesend: Urlaub 3 Tage", airplane icon, orange) under the tiles in week/month/year; week day rows show the absence NAME instead of "0 min" on entry-less absent days

- 2026-08-19: Absences (Urlaub) — Absence model + AbsenceRules (Core, TDD: inclusive day bounds, chained-absence anchor skip), Preferences.absences with add/remove (sorted, swapped bounds, fallback name), DayAttribution isAbsent flag (no distraction on away days), prompt+Fazit gates, anchor skip in normalizeAnchor, settings section (name + date pickers + list) and an orange badge in the stats day header

- 2026-08-18: DayAttribution (Core, TDD) — on days older than yesterday the remaining untracked time counts as Ablenkung (deliberate non-tracking); today/yesterday keep "Nicht erfasst" (still backfillable) and entry-less days are never attributed; wired into day/week/month/year tabs, replacing their ad-hoc untracked sums

- 2026-08-18: Label rework — "Calls & Orga" became "Orga & Alltag" (id orga kept), "Alltag" (everyday) merged into it via a one-off migration (59 entries in 9 day files re-pointed, label removed), new "Calls" label (id calls, mint) after it; shipped defaults + tests + README updated. Shortcuts now: 1 Fokus, 2 Halbfokus, 3 Orga & Alltag, 4 Calls, 5 Ablenkung, 6 Erholung, 7 Sport, 8 Schlafen

- 2026-08-12: Edit menu added in main.swift (undo/redo/cut/copy/paste/select-all) — an accessory app routes Cmd-C/V to text fields only when those items exist in the main menu; pasting links into notes now works

- 2026-08-09: Check-in got a "bis" picker (chronological partial saves) and the window now stays open after a partial save — it closes only when nothing is pending; saveCheckin takes an optional end, drafts clear per save, pickers clamp into the remaining span

- 2026-08-09: Shipped defaults are now the curated 8-label set (Fokus Arbeit, Halbfokus, Calls & Orga, Ablenkung, Erholung, Sport, Schlafen, Alltag; ids unchanged, no goals) — count-agnostic Preferences tests, README updated; fresh installs (brother) start with it

- 2026-08-09: Chip click on a selected label always deselects now (never saves) — onConfirm path removed; saving is Return, the button, or Cmd-1..9

- 2026-08-09: Second label now via the chips themselves (SecondLabelRow deleted): LabelChipsView takes an ordered selection of up to two ids — 1st click primary, 2nd click adds the split partner (chips show "1/2"), 3rd unselected chip restarts, click on the sole selected chip still saves, click on one of two deselects it; Cmd-1..9 stay single-label express saves

- 2026-08-09: Two labels per span — HalfSplit (Core, TDD) halves every 20-min block (10/10), optional second label via SecondLabelRow in check-in + slot editor (also in the stats backfill sheet), day strips now draw sub-slot pieces proportionally so split blocks show both colors

- 2026-08-09: Month + year stats tabs — tiles (Fokus, Avg/aktiver Tag, Quote, Ablenkung), per-day/per-month LabelBarChart (extracted shared component with tooltips, goal line, dense-axis mode), month goals x day count, month untracked over active days only, year aggregates via one day sweep

- 2026-08-09: Toolchain cleanup verified for real — mixed .build artifacts (Swift 6.3 objects + CLT linker) broke test.sh with missing coro-stub symbols and a pipe swallowed the failure once; .build wiped, everything rebuilt from scratch on CLT: 78 tests green, release installed

- 2026-08-09: Single toolchain standard — test.sh added with the same CLT pin as build.sh, CLAUDE.md commands updated (Xcode 26 installed but not used for this project until the SDK popover bug is fixed)

- 2026-08-09: build.sh pins the CLT toolchain (DEVELOPER_DIR) — the Xcode 26 SDK displaces the status-item popover ~2 cm; Timer comparison confirmed identical code, so the SDK is the variable; realign workaround removed again

- 2026-08-09: Xcode license accepted by user — project verified green on the Xcode toolchain (Swift 6.3.3, build + 78 tests + release install); custom test runner kept deliberately

- 2026-08-09: v20 merged — drag-to-select on day strips (click = slot/gap as before, drag = exact span into the editor), live selection highlight + hover time label; note: Xcode was installed on the machine mid-session, builds ran via DEVELOPER_DIR=CommandLineTools until the user accepts the Xcode license

- 2026-08-09: v19 merged — EntryMerge (Core, TDD): adjacent same-label same-text entries collapse to one row in the stats entry list (display-only, ids carried for whole-span edit/delete), duration shown per row

- 2026-08-09: v17 merged — "Wochenverlauf" bar chart in the week view: 7 bottom-aligned bars per selectable label with h:mm values and the daily goal as a reference line

- 2026-08-09: v15 merged — partial "Von" saves no longer drop the earlier span: the anchor only advances via AnchorAdvance over covered blocks, so unlabeled time before the chosen start stays pending

- 2026-08-09: v14 merged — dedicated "Ziele" section with progress bars (done/target, remaining, green reached; week x7) replacing inline goal text; package.sh builds a shareable ZIP (app + German install guide, xattr note for ad-hoc signing)

- 2026-08-09: v12+v13 merged — goal input reworked: dropdown → plain minutes field → hours + minutes fields (empty = no goal, live-saved)

- 2026-08-09: v11 merged — always-visible live-saving Fazit/notes field in the popover (pencil mode removed), per-label daily goals (30-min steps, settings menu) with "Ziel …" + green check in stats (week = goal x 7), Getrackt tile replaced by Ablenkung

- 2026-08-09: v10 merged — stats overhaul: stat tiles (Fokus, Fokus-Quote, Getrackt; week adds Avg Fokus/Tag over active days), proportional color bars behind label rows, clickable chronological entry list with notes (day), week Fazit list

- 2026-08-09: v9 merged — one-click reuse of the last note in the check-in; new "Halbfokus" label (yellow, Cmd-2) between Fokus and Ablenkung (written to defaults, ids stable)

- 2026-08-09: v8 merged — today-balance line in check-in, evening Fazit window (default 21:30, once/day, respects mute+Focus), Timer-focus label suggestion (>=50 % overlap preselects Fokus Arbeit), browser tab domains as own usage segments (site:<domain>, 10 s poll, no double counting; needs per-browser automation permission)

- 2026-08-09: v7 merged — menu bar is one bare number circle (countdown minutes; filled = open blocks; no text title)

- 2026-08-09: v6 merged — app-usage shown as a visible boxed list ("In dieser Zeit benutzt", top 6) in check-in + slot editor; recorder verified live (70 segments on day one)

- 2026-08-09: v4 merged to main — 540 pt popover, centered floating
  check-in window at every boundary (autoOpenPopover gates the window
  now); 68 tests
- 2026-08-09: v3 merged to main — no-gap flow (Später), preselected
  last label + one-key save (Return / ⌘1–⌘9 / click-click), empty-slot
  tap expands to the whole gap; 68 tests
- 2026-08-09: v2 merged to main — usage recorder + line, stats backfill
  editor, anchor advance; review fixes (split oversized test functions,
  prefs test cleanup, input-wipe fix, dictionary uniquing, future-anchor
  clamp, saveCheckin hardening, settings pause sync); 67 tests
- 2026-08-09: Independent code review of v1 (reviewer subagent): 2
  blockers (oversized test functions), 2 warnings, 10 nits — all
  blockers/warnings fixed, cheap nits hardened, 4 accepted + documented
- 2026-08-09: v1 shipped — spec + plan, 51 tests, installed and
  launch-verified; docs (CLAUDE.md, README, PROJECT_STATE)
