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
if command -v xcbeautify >/dev/null 2>&1; then
  xcodebuild test \
    -project RegionalCheck.xcodeproj \
    -scheme RegionalCheck \
    -destination "$destination" \
    -only-testing:RegionalCheckTests \
    -derivedDataPath "${SMOKE_DERIVED_DATA:-/tmp/RegionalCheck-Smoke}" \
    CODE_SIGNING_ALLOWED=YES \
    | xcbeautify
else
  xcodebuild test \
    -project RegionalCheck.xcodeproj \
    -scheme RegionalCheck \
    -destination "$destination" \
    -only-testing:RegionalCheckTests \
    -derivedDataPath "${SMOKE_DERIVED_DATA:-/tmp/RegionalCheck-Smoke}" \
    CODE_SIGNING_ALLOWED=YES
fi
