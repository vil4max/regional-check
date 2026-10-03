#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON=false
for a in "$@"; do
  [[ "$a" == "--json" ]] && JSON=true
done
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
if validate_runtime_config; then
  :
else
  status=$?
  if $JSON; then
    echo '{"ok":false,"checks":[{"id":"configuration","ok":false,"message":"Configuration could not be read; see stderr"}]}'
  fi
  exit "$status"
fi
if ! require_runtime_tool jq; then
  $JSON && echo '{"ok":false,"checks":[{"id":"jq","ok":false,"message":"jq missing; see stderr"}]}'
  exit 2
fi
# shellcheck source=capabilities.sh
source "$SCRIPT_DIR/capabilities.sh"

CAPS="$(emit_capabilities_json)"
BACKEND="$(select_build_backend)"
VERSION="$(harness_version)"
WARNINGS=()
CHECKS=()
OK=true

cap_field() {
  local name="$1" field="$2"
  if have jq; then
    echo "$CAPS" | jq -r --arg n "$name" --arg f "$field" '.[$n][$f]'
  else
    echo false
  fi
}

add_check() {
  local id="$1" ok="$2" msg="$3"
  CHECKS+=("$(jq -cn --arg id "$id" --argjson ok "$ok" --arg message "$msg" '{id:$id,ok:$ok,message:$message}')")
  if [[ "$ok" != true ]]; then
    OK=false
  fi
}

for tool in python3 git just swift swiftlint; do
  if have "$tool"; then
    add_check "$tool" true "$tool available"
  else
    add_check "$tool" false "$tool not installed; install the declared prerequisites, then rerun just doctor"
  fi
done
for check in format lint tests; do
  if cfg_bool "$check" true; then
    add_check "$check.enabled" true "$check enabled"
  else
    add_check "$check.enabled" false "required check $check disabled; enable it in runtime.yml/runtime.local.yml, then rerun just doctor"
  fi
done
if [[ "$(cap_field swift-format healthy)" == true ]]; then
  add_check swift-format true "swift-format available"
else
  add_check swift-format false "swift-format missing; install/select Xcode, then rerun just doctor"
fi
if cfg_bool todo_scan false && ! have rg; then
  add_check todo_scan false "rg missing for enabled todo_scan; install the declared prerequisites, then rerun just doctor"
fi

if [[ "$BACKEND" == swiftpm ]]; then
  if [[ -f "$(project_root)/Package.swift" ]]; then
    add_check package true "Package.swift available"
  else
    add_check package false "Package.swift missing for swiftpm backend"
  fi
else
  add_check xcodebuild "$(cap_field xcodebuild healthy)" "xcodebuild required; install/select Xcode if unhealthy"
  if [[ "$(cap_field simulator healthy)" == true ]]; then
    add_check simulator true "simulator device type or reserved device available"
  else
    add_check simulator false "configured simulator unavailable; install its runtime or correct simulator settings, then rerun just doctor"
  fi
  scheme="$(scheme_name)"
  if [[ -n "$scheme" ]]; then
    add_check scheme true "scheme=$scheme"
  else
    add_check scheme false "scheme missing; set Tooling/runtime.yml scheme, then rerun just doctor"
  fi
fi

xtc="$(cap_field host.xcode_tools configured)"
if [[ "$xtc" == true ]]; then
  add_check host.xcode_tools.configured true "Apple xcode-tools MCP configured"
else
  WARNINGS+=("xcode-tools MCP not configured — optional; selected backend: $BACKEND")
  add_check host.xcode_tools.configured true "xcode-tools MCP optional: not configured"
fi

xth="$(cap_field host.xcode_tools healthy)"
if [[ "$xtc" == true && "$xth" != true ]]; then
  WARNINGS+=("xcode-tools executor is reserved and unavailable; selected backend: $BACKEND")
fi

# A bundle name is a heuristic, not proof of a stable or beta release.
pinned_xcode="$(cfg_get tools.xcode "")"
local_xcode=""
if have xcodebuild; then
  local_xcode="$(xcodebuild -version 2>/dev/null | awk '/^Xcode / {print $2; exit}' || true)"
fi
# DEVELOPER_DIR selects the effective toolchain even when xcode-select differs.
selected_dev_dir="${DEVELOPER_DIR:-}"
if [[ -z "$selected_dev_dir" ]] && have xcode-select; then
  selected_dev_dir="$(xcode-select -p 2>/dev/null || true)"
fi
if [[ -n "$selected_dev_dir" ]]; then
  selected_bundle="${selected_dev_dir%/}"
  selected_bundle="${selected_bundle%/Contents/Developer}"
  selected_bundle="${selected_bundle##*/}"
  case "$selected_bundle" in
    *[Bb][Ee][Tt][Aa]*.app)
      if [[ -n "$pinned_xcode" && "$local_xcode" == "$pinned_xcode" ]]; then
        WARNINGS+=("selected toolchain $selected_dev_dir is beta-named but reports pinned version $local_xcode; the matching version does not establish release stability")
        add_check xcode.toolchain true "beta-named toolchain reports pinned $local_xcode"
      else
        add_check xcode.toolchain false "selected toolchain $selected_dev_dir is beta-named without a matching tools.xcode pin; select the intended stable developer directory, then rerun just doctor"
      fi
      ;;
    *) add_check xcode.toolchain true "selected toolchain $selected_dev_dir (name check only)" ;;
  esac
fi

# A newer runtime is advisory; its version alone does not identify a beta.
if [[ -n "$pinned_xcode" ]] && have xcrun; then
  if runtimes_json="$(xcrun simctl list runtimes -j 2>/dev/null)" &&
    runtime_rows="$(printf '%s' "$runtimes_json" | jq -er '
      if (.runtimes | type) != "array" then error("missing runtimes array")
      else [.runtimes[] | select(.platform == "iOS") | [.version, .name] | @tsv] | join("\n") end' 2>/dev/null)"; then
    while IFS=$'\t' read -r rt_version rt_name; do
      [[ -n "$rt_version" ]] || continue
      if awk -v v="$rt_version" -v p="$pinned_xcode" 'BEGIN {
        split(v, vs, "."); split(p, ps, ".")
        exit !((vs[1]+0 > ps[1]+0) || (vs[1]+0 == ps[1]+0 && vs[2]+0 > ps[2]+0))
      }'; then
        WARNINGS+=("simulator runtime $rt_name ($rt_version) is newer than pinned Xcode $pinned_xcode; confirm the intended runtime for this app")
      fi
    done <<< "$runtime_rows"
  else
    WARNINGS+=("simulator runtime versions could not be inspected against tools.xcode")
  fi
fi

# Load is advisory here; build-slot owns the bounded wait.
doctor_loadavg="${AGENT_RUNTIME_LOADAVG:-}"
[[ -n "$doctor_loadavg" ]] || doctor_loadavg="$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}' || true)"
doctor_ncpu="${AGENT_RUNTIME_NCPU:-}"
[[ -n "$doctor_ncpu" ]] || doctor_ncpu="$(sysctl -n hw.ncpu 2>/dev/null || true)"
if [[ -n "$doctor_loadavg" && -n "$doctor_ncpu" ]]; then
  if awk -v l="$doctor_loadavg" -v n="$doctor_ncpu" 'BEGIN{exit !(l>n)}'; then
    WARNINGS+=("load average $doctor_loadavg exceeds $doctor_ncpu cores — a build may stall; scripts/build-slot.sh waits for it to drop before taking a slot")
  fi
  add_check load true "load $doctor_loadavg / cores $doctor_ncpu"
fi

CHECKS_JSON="["
for i in "${!CHECKS[@]}"; do
  [[ $i -gt 0 ]] && CHECKS_JSON+=","
  CHECKS_JSON+="${CHECKS[$i]}"
done
CHECKS_JSON+="]"

WARN_JSON="["
if have jq; then
  for i in "${!WARNINGS[@]}"; do
    [[ $i -gt 0 ]] && WARN_JSON+=","
    WARN_JSON+=$(printf '%s' "${WARNINGS[$i]}" | jq -Rs .)
  done
fi
WARN_JSON+="]"

if $JSON; then
  if have jq; then
    jq -n \
      --argjson ok "$OK" \
      --arg version "$VERSION" \
      --argjson capabilities "$CAPS" \
      --arg backend "$BACKEND" \
      --argjson checks "$CHECKS_JSON" \
      --argjson warnings "$WARN_JSON" \
      '{ok:$ok,version:$version,capabilities:$capabilities,build_backend_selected:$backend,checks:$checks,warnings:$warnings}'
  else
    echo "{\"ok\":$OK,\"version\":\"$VERSION\",\"build_backend_selected\":\"$BACKEND\"}"
  fi
else
  echo "iOS Agent Runtime doctor (v$VERSION)"
  echo "backend: $BACKEND"
  echo "ok: $OK"
  for c in "${CHECKS[@]}"; do
    if have jq; then
      echo "$c" | jq -r '"  [" + (if .ok then "OK" else "FAIL" end) + "] " + .id + " — " + .message'
    else
      echo "  $c"
    fi
  done
  for w in "${WARNINGS[@]}"; do
    echo "  [WARN] $w"
  done
fi

$OK
