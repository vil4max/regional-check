#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUNDLE_ID="vil4max.RegionalCheck"
SCHEME="RegionalCheck"
OUT_DIR="$ROOT/release/screenshots/asc"
mkdir -p "$OUT_DIR"

SIM="${SCREENSHOT_SIM:-iPhone 17}"
# ASC «iPhone 6.5" Display» accepted portrait size
HEIGHT=2778
WIDTH=1284

# One entry per App Store shot: status:phase:stem[:extra launch args].
# status is "live" (RegionalCheckApp.swift's screenshotRoot already renders the
# redesigned screen for this phase — captured every run) or "pending" (the
# screen's redesign has not landed yet; skipped so this script never fails or
# captures a stale design). Flip an entry to "live" once its screen lands.
#
# Status phases (allClear/alertActive/unavailable) render HomeView with a
# StatusController.applyScreenshotFixture(_:) fixture — RD-5's Status redesign
# replaces HomeView's body in place, so these need no change when it lands.
# "regions"/"regions-search"/"regions-search-empty" boot MainTabView on the
# Regions tab; the search phases were already in RegionalCheckApp.swift but
# missing here.
#
# "map-fullscreen" (RD-6) and "paywall" (RD-16) have no screenshotRoot case
# yet: add `case "map-fullscreen":` and `case "paywall":` there, analogous to
# the existing "about"/"onboarding" cases, then flip these to "live". Prefer a
# direct case over the separate onAppear-triggered -ShowPaywall flag `just
# paywall` uses interactively — a screenshot needs an immediate, deterministic
# root view, not a sheet presentation racing this script's capture delay.
# "about" already has a case, but it stands in for RD-16's real About screen
# (OnboardingView(purpose: .about)) — kept pending until RD-16 replaces it, at
# which point this phase name renders the redesign with no script change.
phases=(
  "live:launch:00-launch"
  "live:allClear:01-all-clear-kyiv"
  "live:alertActive:02-alert-active-kharkiv"
  "live:unavailable:04-unavailable-kyiv"
  "live:onboarding:05-onboarding-get-started"
  "live:regions:06-regions-tab"
  "live:regions-search:07-regions-search-results"
  "live:regions-search-empty:08-regions-search-empty"
  "pending:map-fullscreen:09-map-fullscreen"
  "pending:about:10-about"
  "pending:paywall:11-paywall"
)

udid="$(xcrun simctl list devices available -j | python3 -c "
import json,sys
name=sys.argv[1]
data=json.load(sys.stdin)
for devices in data.get('devices',{}).values():
  for d in devices:
    if d.get('name')==name and d.get('isAvailable', True):
      print(d['udid']); raise SystemExit
raise SystemExit('missing simulator: '+name)
" "$SIM")"
xcrun simctl boot "$udid" 2>/dev/null || true
echo "Using $SIM ($udid) → ${WIDTH}x${HEIGHT} → $OUT_DIR"

DERIVED="/tmp/regional-check-screenshot-derived"
rm -rf "$DERIVED"

xcodebuild \
  -project RegionalCheck.xcodeproj \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$udid" \
  -derivedDataPath "$DERIVED" \
  -configuration Debug \
  build \
  >/tmp/regional-check-screenshot-build.log

APP="$(find "$DERIVED" -name 'RegionalCheck.app' -type d | head -1)"
if [[ -z "$APP" ]]; then
  echo "Built app not found" >&2
  exit 1
fi

xcrun simctl uninstall "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$udid" "$APP"
xcrun simctl privacy "$udid" grant location "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl privacy "$udid" grant location-always "$BUNDLE_ID" >/dev/null 2>&1 || true

# A fixed delay after launch is not reliable: under host load, the static
# Launch Screen can still be on screen well past 2.5s, and a screenshot taken
# during its fade-out into the real content captures a half-transitioned frame
# (observed directly: two shots came back showing the launch artwork instead
# of Regions search while other worktrees' builds were competing for CPU).
# Poll instead: capture small probe frames until two consecutive ones are
# byte-identical (the transition has settled), capped so a screen that never
# stabilizes still gets a capture instead of hanging. Return code distinguishes
# "settled" (0) from "hit the cap still changing" (1) so the caller can warn —
# a frame captured after the cap is a guess, not a confirmed-stable shot.
wait_for_stable_frame() {
  local udid="$1" probe="$2" previous_hash="" current_hash=""
  sleep 2.5 # floor: the delay that was reliable before load got heavier partway through a run
  for _ in $(seq 1 12); do # up to 6s more, only while the frame keeps visibly changing
    xcrun simctl io "$udid" screenshot --type=png "$probe" >/dev/null 2>&1
    current_hash="$(shasum -a 256 "$probe" 2>/dev/null | awk '{print $1}')"
    if [[ -n "$current_hash" && "$current_hash" == "$previous_hash" ]]; then
      return 0
    fi
    previous_hash="$current_hash"
    sleep 0.5
  done
  return 1
}

skipped=()
capped=()
written=()
for entry in "${phases[@]}"; do
  IFS=':' read -r status phase stem extra_args <<<"$entry"
  if [[ "$status" == "pending" ]]; then
    skipped+=("$stem")
    echo "Skipping $stem (phase '$phase' has no redesigned screen yet)"
    continue
  fi

  raw="/tmp/${stem}-asc-raw.png"
  out="$OUT_DIR/${stem}.png"

  xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
  # shellcheck disable=SC2206 # extra_args is a small, script-defined word list, not user input.
  launch_args=(-ScreenshotPhase "$phase" ${extra_args:-})
  xcrun simctl launch "$udid" "$BUNDLE_ID" "${launch_args[@]}" >/dev/null
  if ! wait_for_stable_frame "$udid" "$raw"; then
    capped+=("$stem")
    echo "WARNING: $stem never settled within the 6s stabilization cap — frame was still changing between probes. Inspect $out visually before uploading; it may show a mid-transition frame." >&2
  fi
  xcrun simctl io "$udid" screenshot --type=png "$raw"
  sips -z "$HEIGHT" "$WIDTH" "$raw" --out "$out" >/dev/null
  written+=("$out")
  echo "Wrote $out ($(sips -g pixelWidth -g pixelHeight "$out" 2>/dev/null | awk '/pixel/{print $2}' | paste -sd x -))"
done

rm -rf "$DERIVED"
if [[ "${#skipped[@]}" -gt 0 ]]; then
  echo "Skipped (screen not landed): ${skipped[*]}"
fi
if [[ "${#capped[@]}" -gt 0 ]]; then
  echo "WARNING: never settled, verify visually before upload: ${capped[*]}" >&2
fi

# $OUT_DIR is never cleared, so a run that skips or caps phases still leaves
# an earlier run's files sitting next to this run's output — "upload ALL
# files" would then tell the owner to upload a stale mix. Name exactly what
# this run wrote instead.
echo "This run captured (upload only these):"
for out in "${written[@]}"; do
  echo "  $out"
done
if [[ "${#skipped[@]}" -gt 0 || "${#capped[@]}" -gt 0 ]]; then
  echo "Any OTHER files already in $OUT_DIR are from an earlier run and are NOT part of this set — do not upload them."
fi
