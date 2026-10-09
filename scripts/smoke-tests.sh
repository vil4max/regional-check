#!/usr/bin/env bash
# Runs the unit tests without the Snapshots plan, for a quick check on a simulator.
#
# Usage: scripts/smoke-tests.sh
#   SMOKE_DESTINATION   xcodebuild destination; default is this worktree's own
#                       simulator, `ios-verify destination`
#   SMOKE_DERIVED_DATA  derived data path; default /tmp/RegionalCheck-Smoke
set -euo pipefail

case "${1:-}" in
  -h | --help)
    sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found" >&2
  exit 1
fi

# This worktree's own simulator: picking "the best available iPhone" by name used to land
# on another app's device.
if [[ -n "${SMOKE_DESTINATION:-}" ]]; then
  destination="$SMOKE_DESTINATION"
elif command -v ios-verify >/dev/null 2>&1; then
  destination="$(ios-verify destination)"
else
  echo "ios-verify not found: enable the ios-agentic-sdlc plugin or set SMOKE_DESTINATION" >&2
  exit 2
fi

echo "Smoke tests → $destination"
set -o pipefail
# Prefire's snapshot tests are pinned to a specific device/OS config (see
# .prefire.yml) and already run, pinned, in the Snapshots plan and CI, so this
# script skips them to stay fast. -skipPackagePluginValidation is required for
# any test run of this target now that Prefire's build tool plugin is a
# RegionalCheckTests dependency.
SMOKE_ARGS=(
  -project RegionalCheck.xcodeproj
  -scheme RegionalCheck
  -destination "$destination"
  -skipPackagePluginValidation
  -skipMacroValidation
  -only-testing:RegionalCheckTests
  -skip-testing:RegionalCheckTests/PreviewTests
  -derivedDataPath "${SMOKE_DERIVED_DATA:-/tmp/RegionalCheck-Smoke}"
  CODE_SIGNING_ALLOWED=YES
)
if command -v xcbeautify >/dev/null 2>&1; then
  xcodebuild test "${SMOKE_ARGS[@]}" | xcbeautify
else
  xcodebuild test "${SMOKE_ARGS[@]}"
fi
