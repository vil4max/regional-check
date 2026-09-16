#!/usr/bin/env bash
# Regenerates the coverage-by-layer report: how much of RegionalCheck.app and
# DriveCheckKit each test layer covers, split into "only this layer" and "also
# covered elsewhere". Slow on purpose — it isolates each layer with its own
# xcodebuild test run (plus one run with no tests, to measure what launching
# the app under test alone covers) so the split is real, not estimated.
#
# Usage: scripts/coverage-pyramid.sh [output.html]
#   Default output: docs/engineering/coverage-pyramid.html
#
# Layers are declared in scripts/coverage-layers.txt (one per line:
# "<layer> <TestClass> <TestClass> ..."). Update that file when a test file's
# class list changes; nothing else in this script encodes test names.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=../Tooling/scripts/lib.sh
source Tooling/scripts/lib.sh

OUTPUT="${1:-docs/engineering/coverage-pyramid.html}"
LAYERS_FILE="scripts/coverage-layers.txt"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SCHEME="$(scheme_name)"
PROJ="$(find_xcodeproj)"
DEST="$(destination_spec)"
SIM_ID="$(echo "$DEST" | sed -n 's/.*id=\([^, ]*\).*/\1/p')"
[[ -n "$SCHEME" && -n "$PROJ" && -n "$SIM_ID" ]] || {
  echo "could not resolve scheme/project/simulator from runtime.yml" >&2
  exit 1
}

echo "scheme=$SCHEME sim=$SIM_ID work=$WORK"

run_layer() {
  local layer="$1"
  shift
  local filters=()
  if [[ "$layer" == "baseline" ]]; then
    filters=("-only-testing:RegionalCheckTests/MapImageSourceTests/dayVariantBuildsDefaultMapURL()")
  else
    for class in "$@"; do filters+=("-only-testing:RegionalCheckTests/$class"); done
  fi
  local log="$WORK/$layer.log"
  for attempt in 1 2 3; do
    xcrun simctl terminate "$SIM_ID" vil4max.RegionalCheck >/dev/null 2>&1 || true
    xcrun simctl uninstall "$SIM_ID" vil4max.RegionalCheck >/dev/null 2>&1 || true
    rm -rf "$WORK/$layer.xcresult"
    xcodebuild -project "$PROJ" -scheme "$SCHEME" -destination "$DEST" -configuration Debug \
      -skipPackagePluginValidation -skipMacroValidation -enableCodeCoverage YES \
      -parallel-testing-enabled NO -test-timeouts-enabled YES \
      -default-test-execution-time-allowance 60 -maximum-test-execution-time-allowance 120 \
      -derivedDataPath "$WORK/DerivedData" "${filters[@]}" \
      -resultBundlePath "$WORK/$layer.xcresult" test >"$log" 2>&1 || true
    if grep -q "TEST SUCCEEDED" "$log"; then
      break
    fi
    if grep -q "Busy\|failed preflight\|failed to bless service hub" "$log"; then
      echo "  $layer: simulator busy, retrying ($attempt/3)" >&2
      xcrun simctl shutdown "$SIM_ID" >/dev/null 2>&1 || true
      sleep 3
      xcrun simctl boot "$SIM_ID" >/dev/null 2>&1 || true
      sleep 5
      continue
    fi
    echo "  $layer: xcodebuild failed, see $log" >&2
    exit 1
  done
  local profile
  profile="$(find "$WORK/DerivedData/Build/ProfileData" -name Coverage.profdata | head -1)"
  cp "$profile" "$WORK/$layer.profdata"
  local app_binary="$WORK/DerivedData/Build/Products/Debug-iphonesimulator/RegionalCheck.app/RegionalCheck.debug.dylib"
  local kit_binary
  kit_binary="$(find "$WORK/DerivedData/Build/Products/Debug-iphonesimulator/RegionalCheck.app/Frameworks" \
    -type f -name 'DriveCheckKit_*PackageProduct' | head -1)"
  xcrun llvm-cov export -format=lcov -instr-profile "$WORK/$layer.profdata" \
    "$app_binary" -object "$kit_binary" >"$WORK/$layer.lcov"
  xcrun xcresulttool get test-results tests --path "$WORK/$layer.xcresult" >"$WORK/$layer.tests.json" 2>/dev/null || echo '{}' >"$WORK/$layer.tests.json"
  echo "  $layer: done"
}

run_layer baseline
while read -r layer classes; do
  [[ -z "$layer" || "$layer" == \#* ]] && continue
  # shellcheck disable=SC2086
  run_layer "$layer" $classes
done <"$LAYERS_FILE"

python3 "$(dirname "${BASH_SOURCE[0]}")/coverage-pyramid-render.py" "$WORK" "$ROOT" "$LAYERS_FILE" "$OUTPUT"
echo "wrote $OUTPUT"
