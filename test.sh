#!/usr/bin/env bash
# Runs the test suite on the SAME toolchain build.sh uses (CLT pin) —
# one standard for everything until the Xcode 26 SDK popover bug is
# fixed (then remove the pin here AND in build.sh together).
set -euo pipefail
cd "$(dirname "$0")"

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Library/Developer/CommandLineTools ]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

swift run -q TwentyTrackTestRunner
