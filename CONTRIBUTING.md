# Contributing to 20minTrack

Thanks for your interest! Bug reports, ideas and pull requests are all welcome.

## Ways to help

- **Report a bug** — open an [issue](https://github.com/moritzthln/20minTrack/issues/new/choose) with your macOS version and steps to reproduce.
- **Suggest a feature** — open a feature request and describe the problem it solves. For bigger changes, please open an issue *before* writing code so we can agree on the approach.
- **Improve translations** — the UI ships in English and German (see [Localization](#localization)).
- **Pick up an issue** — look for [`good first issue`](https://github.com/moritzthln/20minTrack/labels/good%20first%20issue) or [`help wanted`](https://github.com/moritzthln/20minTrack/labels/help%20wanted).

## Development setup

Requirements: macOS 13+, Xcode Command Line Tools (`xcode-select --install`). No Xcode project — it's a plain Swift package.

```bash
git clone https://github.com/<you>/20minTrack.git
cd 20minTrack
./test.sh          # run the test suite
./build.sh         # universal release build, installs to /Applications
NO_INSTALL=1 ./build.sh   # build into dist/ only
```

Note: the scripts pin the Command Line Tools toolchain because the Xcode 26 SDK misplaces the menu bar popover. Set `DEVELOPER_DIR` yourself to override.

## Project structure

| Path | What lives there |
|---|---|
| `Sources/TwentyCore/` | All logic (slot grid, pending ranges, gap filling, statistics, absences …). No UI, fully unit-tested. |
| `Sources/TwentyTrackApp/` | The app: status item, windows, SwiftUI views (`Views/`). |
| `Tests/TwentyTrackTestRunner/` | Test suites. Custom harness (`test`, `expect`, `expectEqual`) — no XCTest needed. |

More architecture notes: [`CLAUDE.md`](CLAUDE.md).

## Workflow

1. Fork the repo and create a branch: `feat/<name>`, `fix/<name>` or `docs/<name>`.
2. **Logic goes into `TwentyCore` with tests first.** Add a suite file in `Tests/TwentyTrackTestRunner/` and register its run function in `main.swift`.
3. Run `./test.sh` — all tests must pass — and `NO_INSTALL=1 ./build.sh` to make sure the universal build works.
4. Try the change in the real app (`./build.sh` installs and you can launch it).
5. Add a line to `CHANGELOG.md` under **[Unreleased]** (Added / Changed / Fixed) for anything users will notice.
6. Open a pull request against `main` and fill in the template. Screenshots are very welcome for UI changes.

### Commit messages

[Conventional Commits](https://www.conventionalcommits.org/), English, imperative:

```
feat: add CSV export to the statistics window
fix: keep the check-in window open after a partial save
docs: explain absences in the README
```

## Releases

Maintainers cut releases with `./release.sh X.Y.Z` ([Semantic Versioning](https://semver.org/)): it bumps the app version, moves the *Unreleased* changelog entries into the new version, runs the tests, builds the universal ZIP plus a SHA-256 checksum, tags `vX.Y.Z` and publishes the GitHub release.

## Code style

- Swift + SwiftUI, match the surrounding code. 4-space indentation (see `.editorconfig`).
- **Size limits:** files ≤ 800 lines, functions ≤ 80 lines — split before you hit them.
- Code, comments and identifiers in English. Comments explain *why*, not *what*.
- No new dependencies without discussing it in an issue first.
- No network access. All data stays local — this is a core promise of the app.

## Localization

Every user-facing string goes through `loc(german, english)` from `Sources/TwentyTrackApp/L10n.swift`:

```swift
Text(loc("Später", "Later"))
```

Never hard-code a single-language string in the UI. Date formats use `l10nLocale`.

## Product principles

Please keep these in mind when proposing features:

- **One interaction.** A check-in must stay answerable with a single keystroke.
- **Nothing is silently dropped.** Time is never auto-filled or guessed; missed blocks stay pending until the user labels them.
- **Respect attention.** Prompts stay silent during Focus modes, mutes and absences — and mutes always expire on their own.
