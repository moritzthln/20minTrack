#!/usr/bin/env bash
# Cuts a release: ./release.sh 1.2.0
#
#   1. checks: semver, on main, clean tree, in sync with origin, tag free,
#      CHANGELOG "Unreleased" section not empty
#   2. bumps Info.plist (CFBundleShortVersionString = version,
#      CFBundleVersion = previous + 1)
#   3. turns "## [Unreleased]" into "## [version] - date" (Keep a Changelog)
#   4. runs the tests, builds the universal ZIP (package.sh) + SHA-256
#   5. commits, tags vX.Y.Z (annotated), pushes, creates the GitHub release
#      with the changelog section as notes
#
# Builds locally on purpose: the pinned Command Line Tools toolchain is
# the one known to place the menu bar popover correctly.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
TAG="v$VERSION"
REPO="moritzthln/20minTrack"
PLIST="Resources/Info.plist"

die() { echo "✗ $*" >&2; exit 1; }

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: ./release.sh MAJOR.MINOR.PATCH (e.g. 1.2.0)"
command -v gh >/dev/null || die "GitHub CLI (gh) is required"
[ "$(git branch --show-current)" = "main" ] || die "releases are cut from main"
[ -z "$(git status --porcelain)" ] || die "working tree not clean"
git fetch -q --tags origin
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main is not in sync with origin/main"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists"

NOTES="$(awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | sed '/^[[:space:]]*$/N;/^\n$/D')"
[ -n "$(echo "$NOTES" | tr -d '[:space:]')" ] || die "CHANGELOG.md has no entries under [Unreleased]"

echo "▸ Releasing $TAG"

BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PLIST")"
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set CFBundleVersion $((BUILD + 1))" "$PLIST"

TODAY="$(date +%Y-%m-%d)"
PREV="$(git describe --tags --abbrev=0 2>/dev/null || echo "")"
python3 - "$VERSION" "$TODAY" "$PREV" "$REPO" << 'PY'
import sys, re
version, today, prev, repo = sys.argv[1:]
p = "CHANGELOG.md"
s = open(p).read()
s = s.replace("## [Unreleased]", f"## [Unreleased]\n\n## [{version}] - {today}", 1)
s = re.sub(r"^\[Unreleased\]: .*$",
           f"[Unreleased]: https://github.com/{repo}/compare/v{version}...HEAD\n"
           f"[{version}]: https://github.com/{repo}/compare/{prev}...v{version}" if prev else
           f"[Unreleased]: https://github.com/{repo}/compare/v{version}...HEAD\n"
           f"[{version}]: https://github.com/{repo}/releases/tag/v{version}",
           s, count=1, flags=re.M)
open(p, "w").write(s)
PY

echo "▸ Tests"
./test.sh > /dev/null || { git checkout -- "$PLIST" CHANGELOG.md; die "tests failed"; }

echo "▸ Package"
./package.sh
( cd dist && shasum -a 256 20minTrack.zip > 20minTrack.zip.sha256 )

echo "▸ Commit, tag, push"
git add "$PLIST" CHANGELOG.md
git commit -q -m "chore: release $TAG"
git tag -a "$TAG" -m "20minTrack $TAG"
git push -q origin main "$TAG"

echo "▸ GitHub release"
INSTALL='**Install or update:** `curl -fsSL https://raw.githubusercontent.com/moritzthln/20minTrack/main/install.sh | bash` — your data is kept.'
gh release create "$TAG" dist/20minTrack.zip dist/20minTrack.zip.sha256 \
  -R "$REPO" --title "20minTrack $TAG" --notes "$INSTALL

$NOTES"

echo "✓ Released $TAG — https://github.com/$REPO/releases/tag/$TAG"
