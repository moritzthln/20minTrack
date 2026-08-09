# PROJECT_STATE — 20minTrack

## Status

v1 implemented on `feat/v1` (2026-08-09): menu bar 20-minute tracker —
grid math, pending-range check-in with chime + auto-popover, per-day
JSON store (midnight split, overlap trim, gap-filling saves), today
strip with slot editor, Tagesfazit, statistics (Tag/Woche), settings
(labels CRUD, volume, pause, login item). 51 unit tests green; app
built, installed, launched headless (process verified). Code review
pending, then merge.

## In Progress

- Independent code review (reviewer subagent), then merge to `main`

## Next Up

- User live-E2E: hear the chime at a real boundary, save a check-in,
  fill a slot via the strip, write a Fazit, check both stats views
- Morning test: overnight gap prompts once shortly after wake/login and
  saves as "Schlafen" across midnight (lands in both day files)
- Optional: private GitHub repo + push (still local-only)

## Known Issues

- UI not yet visually inspected (headless session): views verified by
  build + launch only; core logic is unit-tested
- First prompt after login arrives ~2 s after launch by design; after
  wake it can chime while the lid is barely open — acceptable, revisit
  if annoying
- `swift build` prints `xcrun … PlatformPath` errors — pre-existing CLT
  noise on this machine (Timer has the same), harmless

## Recent Decisions

- 2026-08-09: Native macOS menu bar app in the Timer house style (user
  pointed at the Timer as the reference; a 20-min nag belongs in the
  menu bar, not a browser tab) — autonomous-session assumption,
  recorded in the spec
- 2026-08-09: Blocks are wall-clock aligned (:00/:20/:40) — predictable
  prompts, clean stats; 72 blocks/day
- 2026-08-09: One persisted `checkinAnchor` marks settled time; the
  check-in covers anchor → last boundary, capped at start of yesterday
  (a week offline never produces a monster block)
- 2026-08-09: Check-in saves fill only untracked gaps (`GapFill`) so
  manual strip edits inside the pending window survive; strip edits
  never move the anchor
- 2026-08-09: Overlap trim on insert (last write wins) is the single
  editing rule — relabel/correct = insert over it
- 2026-08-09: Labels archive instead of delete (stable slug ids for the
  six defaults) so history always resolves name + color
- 2026-08-09: v1 chime = single system "Glass" (gentle, 3×/h), no
  bundled sounds; Notification Center deliberately unused (popover +
  chime, Timer precedent)

## Recently Done

- 2026-08-09: v1 implemented spec-direct-plus-compact-plan in 12
  commits on `feat/v1` (51 tests, TDD for all of TwentyCore); app
  installed to /Applications and launch-verified; docs written
  (CLAUDE.md, README, PROJECT_STATE)
- 2026-08-09: Spec + implementation plan committed
