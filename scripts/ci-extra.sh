#!/usr/bin/env bash
# The app's CI work after the Runtime gate (`just ci`, Tooling/docs/ci.md): the
# Snapshots test plan, and Sonar coverage for the unit and snapshot runs together.
#
# Snapshot baselines are recorded on a developer Mac, and pixel differences on a
# different Xcode or GPU must not block the job, so a snapshot failure is reported
# but not fatal: the same rule the pre-shared pipeline's workflow applied.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../Tooling/scripts/lib.sh
source "$ROOT/Tooling/scripts/lib.sh"
cd "$ROOT"

OUT="$ROOT/build/ci"
mkdir -p "$OUT/results" "$OUT/sonar" "$OUT/profiles"

PROJ="$(find_xcodeproj)"
SCHEME="$(scheme_name)"
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

ARGS=(-project "$PROJ" -scheme "$SCHEME" -testPlan Snapshots -destination "$(destination_spec test)"
  -configuration Debug -enableCodeCoverage YES -resultBundlePath "$OUT/results/snapshots.xcresult")
while IFS= read -r flag; do ARGS+=("$flag"); done < <(xcodebuild_validation_flags)
while IFS= read -r flag; do [[ "$flag" == -enableCodeCoverage || "$flag" == YES ]] || ARGS+=("$flag"); done \
  < <(xcodebuild_ci_flags)
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
