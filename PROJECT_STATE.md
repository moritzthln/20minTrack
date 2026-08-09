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
