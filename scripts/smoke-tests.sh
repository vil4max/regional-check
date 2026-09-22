#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found" >&2
  exit 1
fi

# The session's own test simulator from the Runtime (Tooling/docs/ci.md): picking "the
# best available iPhone" by name used to land on another app's device.
# shellcheck source=../Tooling/scripts/lib.sh
source "$ROOT/Tooling/scripts/lib.sh"
destination="${SMOKE_DESTINATION:-$(destination_spec test)}"

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
