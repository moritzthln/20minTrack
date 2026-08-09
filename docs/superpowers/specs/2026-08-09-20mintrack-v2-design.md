# 20minTrack v2 — Design

2026-08-09, on top of v1. User request (clarified via question round):

1. Show which apps were used in the check-in span ("welche Apps in den
   letzten 20 min benutzt wurden").
2. Comfortable backfilling of old ranges (sleep, past days): pick a
   span, assign a label, no text required. Explicitly NOT an automatic
   sleep window ("nein keins") — backfilling stays a manual, fast action.
3. Note: text was already optional in v1 (label suffices) — v2 makes
   backfilling reachable for past days and marks backfilled time as
   settled.

## Features

### 1. App usage tracking + display

- New local recorder (Timer v4 pattern, simplified): frontmost-app
  segments `{bundleID, name, start, end}`, one JSON per day under
  `…/Application Support/20minTrack/usage/`.
- Events: `didActivateApplicationNotification` opens/closes segments;
  sleep/wake and screen lock/unlock close/reopen them; 60 s heartbeat
  upserts the open segment (crash loses ≤ 60 s); `flush()` on quit and
  before display. Own app is never recorded. `trackingPaused` also
  pauses this recorder (reconciled via `.trackerSettingsChanged`).
- No input-idle detection in v2 (Timer's presence poll) — the line is a
  memory aid, not an exact statistic. Documented limitation: an app left
  frontmost counts until lock/sleep.
- Display: one caption line "Benutzt: Chrome 12 min · Slack 5 min
  (+2 weitere)" — top 3 apps ≥ 1 min, clipped to the span —
  in **CheckinView** (pending span) and in **SlotEditView** (live for
  the currently picked von–bis span). Hidden when there is no data.

### 2. Backfill past days from the statistics day view

- The day strip in `StatsDayView` becomes clickable; a tapped slot opens
  `SlotEditView` in a sheet (same component as the popover editor —
  von/bis pickers, chips, optional text, delete).
- `SlotEditView` gains the end-of-day boundary ("24:00" = next midnight)
  as a "bis" option so late-evening spans reach the day end.
- After save/delete the view reloads and posts `.trackerSettingsChanged`
  so the menu bar + popover refresh when today was edited.

### 3. Backfilled time counts as settled (AnchorAdvance)

- New pure rule: starting at the anchor, walk block by block; while the
  block `[b, next(b))` is fully covered by entries, advance. Applied on
  every reload — manually filled blocks never re-prompt, and partial
  manual fills shrink the asked span.
- Core: `AnchorAdvance.advanced(from:upTo:entries:calendar:)` using
  `GapFill` for the coverage check.

## Core additions (TDD)

- `AppUsageSegment` (Codable, Identifiable) + `AppUsageStore` —
  FocusLog-style per-day JSON with `upsert` (insert-or-replace by id,
  midnight split), `segments(onDay:)`; corrupt file reads empty.
- `AppUsageMath.totals(segments:in:)` → `[(name, seconds)]`: clipped to
  the range, merged per bundleID (latest name wins), sorted desc.
- `AnchorAdvance` as above.

## Non-goals (v2)

Automatic sleep window / auto-fill of any kind, input-idle presence
detection, browser-tab domains, usage statistics views (the data only
feeds the check-in/editor line), editing days older than the stats
navigation reaches, multi-day spans in one editor save (cross-midnight
backfill = two quick saves; the live check-in still spans midnight).
