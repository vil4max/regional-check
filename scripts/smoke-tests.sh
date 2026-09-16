#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found" >&2
  exit 1
fi

destination="${SMOKE_DESTINATION:-}"
if [[ -z "$destination" ]]; then
  destination="$(
    python3 - <<'PY'
import json, subprocess, sys
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
data = json.loads(raw)
best = None
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if not device.get("isAvailable", True):
            continue
        name = device.get("name", "")
        if not name.startswith("iPhone"):
            continue
        candidate = (runtime, name, device["udid"])
        if best is None or candidate > best:
            best = candidate
if not best:
    sys.exit("No available iPhone simulator")
_, name, _ = best
print(f"platform=iOS Simulator,name={name}")
PY
  )"
fi

echo "Smoke tests → $destination"
set -o pipefail
# Prefire's snapshot tests are pinned to a specific device/OS config (see
# .prefire.yml) and already run, pinned, in `just verify` / CI; this script
# picks whatever simulator is available, so it skips them rather than fail
# on an unrelated OS mismatch. -skipPackagePluginValidation is required for
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
