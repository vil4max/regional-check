#!/usr/bin/env bash
# The app's CI work after the unit tests (.github/workflows/tests.yml): the Snapshots test
# plan, and Sonar coverage for the unit and snapshot runs together.
#
# Snapshot baselines are recorded on a developer Mac, and pixel differences on a
# different Xcode or GPU must not block the job, so a snapshot failure is reported
# but not fatal.
#
# Usage: scripts/ci-extra.sh
# Run it after an `xcodebuild test` of the same project and scheme: it takes the unit run's
# coverage profile from DerivedData. Settings by environment variable:
#   IOS_PROJECT      default RegionalCheck.xcodeproj
#   IOS_SCHEME       default RegionalCheck
#   IOS_DESTINATION  default platform=iOS Simulator,name=iPhone 17
set -euo pipefail

case "${1:-}" in
  -h | --help)
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;
  *)
    echo "usage: scripts/ci-extra.sh [--help]" >&2
    exit 2
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

PROJ="${IOS_PROJECT:-RegionalCheck.xcodeproj}"
SCHEME="${IOS_SCHEME:-RegionalCheck}"
DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

OUT="$ROOT/build/ci"
mkdir -p "$OUT/results" "$OUT/sonar" "$OUT/profiles"

BUILD_DIR="$(xcodebuild -project "$PROJ" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^ *BUILD_DIR = /{print $2; exit}')"
DERIVED_DATA="${BUILD_DIR%/Build/Products}"
[[ -d "$DERIVED_DATA" ]] || { echo "ci-extra: no DerivedData at $DERIVED_DATA" >&2; exit 1; }

# The newest coverage profile under DerivedData belongs to the run that just ended.
latest_profile() {
  find "$DERIVED_DATA/Build/ProfileData" -name Coverage.profdata -print0 2>/dev/null \
    | xargs -0 ls -t 2>/dev/null | head -1
}

unit_profile="$(latest_profile)"
[[ -n "$unit_profile" ]] || { echo "ci-extra: the unit run left no coverage profile" >&2; exit 1; }
cp "$unit_profile" "$OUT/profiles/unit.profdata"

# Same flags as the unit run in tests.yml, with the Snapshots plan.
ARGS=(-project "$PROJ" -scheme "$SCHEME" -testPlan Snapshots -destination "$DESTINATION"
  -configuration Debug -skipPackagePluginValidation -skipMacroValidation
  -enableCodeCoverage YES -parallel-testing-enabled NO
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=
  -resultBundlePath "$OUT/results/snapshots.xcresult")
rm -rf "$OUT/results/snapshots.xcresult"

snapshot_status=0
xcodebuild "${ARGS[@]}" test || snapshot_status=$?
if [[ $snapshot_status -ne 0 ]]; then
  echo "::warning::Snapshot tests failed (exit $snapshot_status); see build/ci/results/snapshots.xcresult"
fi

profiles=("$OUT/profiles/unit.profdata")
snapshot_profile="$(latest_profile)"
if [[ -n "$snapshot_profile" && "$snapshot_profile" != "$unit_profile" ]]; then
  cp "$snapshot_profile" "$OUT/profiles/snapshots.profdata"
  profiles+=("$OUT/profiles/snapshots.profdata")
fi
"$ROOT/scripts/sonar-coverage.sh" "$DERIVED_DATA" "$OUT/sonar/coverage.xml" "${profiles[@]}"
