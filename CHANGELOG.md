# Changelog

All notable changes to 20minTrack are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Removed
- The ⌘I / ⌘, shortcuts in the menu bar popover — they didn't fire reliably there. ⌘, still works inside the Statistics/Settings window.

## [1.2.0] - 2026-10-02

### Added
- Week chart "All labels" (now the default): one stacked bar per day showing how it was composed, with exact durations on hover. Picking a single label still shows its bars and goal line. ([#2](https://github.com/moritzthln/20minTrack/issues/2))
- Statistics and Settings share one window with toolbar tabs — closing it never leaves a stray window behind. ([#3](https://github.com/moritzthln/20minTrack/issues/3))
- Calendar hints (opt-in, Settings → Calendar): events that overlap a block appear in the check-in and the block editor as a reminder — read-only, local, never turned into entries. Choose which calendars to use. ([#4](https://github.com/moritzthln/20minTrack/issues/4))
- Shortcuts: ⌘, opens Settings, ⌘I opens Statistics (popover, status item menu, app menu). Pausing deliberately has no shortcut, like Quit.

### Changed
- Notes fields use a soft surface that follows light/dark mode instead of a solid black box. ([#1](https://github.com/moritzthln/20minTrack/issues/1))
- Day strips: the hover time label is centered on the slot and never clipped, the hovered slot is highlighted, and the current-time line stands out on every color. ([#1](https://github.com/moritzthln/20minTrack/issues/1))

## [1.1.1] - 2026-10-01

### Changed
- Licensed under [PolyForm Noncommercial 1.0.0](LICENSE): free for personal and noncommercial use, commercial use not permitted.
- The download ZIP now includes the license text.

## 1.1.0 - 2026-10-01

### Added
- App version shown at the bottom of Settings (helps with bug reports).
- Release script (`release.sh`) and a SHA-256 checksum next to each release ZIP.

## 1.0.0 - 2026-10-01

First public release.

### Added
- 20-minute check-ins on the wall clock with a centered floating window.
- One-keystroke saving: preselected last label, ⌘1–⌘9 and ⌘0.
- Two labels per block (10/10 split), optional notes, last-note reuse.
- Pending ranges: nothing is ever dropped; From/until to fill piece by piece.
- App and browser-site usage as a memory aid in the check-in.
- Statistics: day, week, month, year — focus ratio, distraction, goals, trends.
- Daily goals per label, daily review with evening reminder and morning catch-up.
- Silence during macOS Focus, timed mute, planned absences.
- English and German UI.
- Universal binary (Apple Silicon + Intel), macOS 13+.

[Unreleased]: https://github.com/moritzthln/20minTrack/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/moritzthln/20minTrack/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/moritzthln/20minTrack/releases/tag/v1.1.1
