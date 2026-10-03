#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# An installed Tooling/scripts/verify.sh targets the app around it (below, DoD).
# The Runtime source checkout has no app to build: its own `just verify` is the
# contract-test gate instead, every tests/*.sh plus each generator's --check
# (none exist yet) (KIT-D-037).
if [[ "$(basename "$(dirname "$SCRIPT_DIR")")" != "Tooling" ]]; then
  exec "$SCRIPT_DIR/run-contract-tests.sh"
fi

# An installed Tooling/ that cannot find its own scripts is broken (a partial
# install, an interrupted worktree checkout) rather than missing an optional
# extra: fail with one clear message instead of whichever script happens to
# crash first with a raw "No such file" (KIT-D-037). capabilities.sh and
# baseline.py stay optional below (older minimal installations may lack
# either) and are not required here.
required_scripts=(lib.sh verification-state.py format.sh lint.sh build.sh test.sh)
missing_scripts=()
for required in "${required_scripts[@]}"; do
  [[ -f "$SCRIPT_DIR/$required" ]] || missing_scripts+=("$required")
done
if [[ "${#missing_scripts[@]}" -gt 0 ]]; then
  echo "verify: installed Tooling/scripts/ is missing ${missing_scripts[*]}; run \`just harness-update\` to repair it" >&2
  exit 1
fi

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
require_runtime_tool python3
receipt() { python3 "$SCRIPT_DIR/verification-state.py" "$@"; }
receipt invalidate
validate_runtime_config
for check in format lint tests; do
  cfg_bool "$check" true || { echo "verify: required check $check is disabled; enable it in runtime.yml/runtime.local.yml, then rerun just verify." >&2; exit 1; }
done
if cfg_bool todo_scan false; then require_runtime_tool rg; fi
# Older minimal installations may not include backend capability detection.
if [[ -f "$SCRIPT_DIR/capabilities.sh" ]]; then
  # shellcheck source=capabilities.sh
  source "$SCRIPT_DIR/capabilities.sh"
fi

# The shared baseline first: drifted pipeline files or simulator settings fail
# before any build. A sibling Runtime source checkout, when IOS_AGENT_RUNTIME_ROOT
# names one, adds lag and style warnings; there is no default path to reach back
# into (KIT-D-037) — without it, baseline just skips that comparison.
if [[ -f "$SCRIPT_DIR/baseline.py" ]]; then
  runtime_checkout="${IOS_AGENT_RUNTIME_ROOT:-}"
  if [[ -n "$runtime_checkout" && -d "$runtime_checkout/scripts" && "${CI:-}" != true ]]; then
    python3 "$SCRIPT_DIR/baseline.py" "$(project_root)" --runtime "$runtime_checkout"
  else
    python3 "$SCRIPT_DIR/baseline.py" "$(project_root)"
  fi
fi
"$SCRIPT_DIR/format.sh"
verified_state="$(receipt fingerprint)"
"$SCRIPT_DIR/lint.sh"

# Capture both streams: some backends emit compiler diagnostics on stderr.
build_log="$(mktemp "${TMPDIR:-/tmp}/ios-agent-toolchain-verify-build.XXXXXX")"
trap 'rm -f "$build_log"' EXIT
# Build test artifacts once; a second xcodebuild test would compile them again.
if declare -F select_build_backend >/dev/null && [[ "$(select_build_backend)" == xcodebuild ]]; then
  RUNTIME_XCODEBUILD_BUILD_FOR_TESTING=true "$SCRIPT_DIR/build.sh" 2>&1 | tee "$build_log"
  RUNTIME_XCODEBUILD_WITHOUT_BUILDING=true "$SCRIPT_DIR/test.sh"
else
  "$SCRIPT_DIR/build.sh" 2>&1 | tee "$build_log"
  "$SCRIPT_DIR/test.sh"
fi

# Resolve main first: an absent branch-local file cannot disable its ceiling.
root="$(cd "${PROJECT_ROOT:-$PWD}" && pwd)"
baseline_rel="Tooling/.deprecation-baseline"
baseline_ref=""
baseline_count=""
baseline_source=main
baseline_found=false
verification_summary="verify OK (DoD)"
if git -C "$root" rev-parse --show-toplevel >/dev/null 2>&1; then
  baseline_rel="$(git -C "$root" rev-parse --show-prefix)$baseline_rel"
  current_branch="$(git -C "$root" symbolic-ref --short -q HEAD || true)"
  if [[ "$current_branch" == main ]]; then
    baseline_ref=HEAD
  else
    if git -C "$root" remote get-url origin >/dev/null 2>&1; then
      # No --depth: history is shared with sibling worktrees. Bound the whole
      # process group, including credential helpers and SSH children.
      if ! python3 - "$root" <<'FETCH'
import os
import signal
import subprocess
import sys

try:
    child = subprocess.Popen(
        ["git", "-C", sys.argv[1], "fetch", "--quiet", "origin", "main:refs/remotes/origin/main"],
        env=dict(os.environ, GIT_TERMINAL_PROMPT="0"), stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    try:
        status = child.wait(timeout=30)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGKILL)
        child.wait()
        print("verify: origin/main refresh timed out after 30 seconds", file=sys.stderr)
        status = 1
    sys.exit(status)
except OSError as error:
    print(f"verify: cannot refresh origin/main: {error}", file=sys.stderr)
    sys.exit(1)
FETCH
      then
        echo "verify: origin/main refresh failed; comparing with an available local main ref" >&2
      fi
    fi
    origin_main="$(git -C "$root" rev-parse --verify 'refs/remotes/origin/main^{commit}' 2>/dev/null || true)"
    local_main="$(git -C "$root" rev-parse --verify 'refs/heads/main^{commit}' 2>/dev/null || true)"
    baseline_ref="${origin_main:-$local_main}"
    if [[ -n "$origin_main" && -n "$local_main" ]]; then
      # An unpushed local main is authoritative only if it includes origin/main.
      ancestry_status=0
      git -C "$root" merge-base --is-ancestor "$origin_main" "$local_main" || ancestry_status=$?
      case "$ancestry_status" in
        0) baseline_ref="$local_main" ;;
        1) ;;
        *) echo "verify: could not compare local main with origin/main (exit $ancestry_status)" >&2; exit 1 ;;
      esac
    fi
  fi
fi
if [[ -n "$baseline_ref" ]]; then
  baseline_entry="$(git -C "$root" ls-tree "$baseline_ref" -- ":(top,literal)$baseline_rel")"
  if [[ -n "$baseline_entry" ]]; then
    baseline_count="$(git -C "$root" show "$baseline_ref:$baseline_rel")"
    baseline_found=true
  elif [[ -f "$root/Tooling/.deprecation-baseline" ]]; then
    echo "verify: main has no $baseline_rel; validating the proposed baseline (enforced after landing on main)"
    baseline_count="$(cat "$root/Tooling/.deprecation-baseline")"
    baseline_source=proposed
    baseline_found=true
  fi
elif [[ -f "$root/Tooling/.deprecation-baseline" ]]; then
  echo "verify: no main ref to read the deprecation baseline from; fetch origin main" >&2
  exit 1
else
  echo "verify: no main ref available; optional deprecation ceiling could not be determined" >&2
  verification_summary="verify OK (required checks; deprecation ceiling NOT CHECKED: no main ref)"
fi
if $baseline_found; then
  if ! [[ "$baseline_count" =~ ^[0-9]+$ ]]; then
    echo "verify: $baseline_rel does not hold a plain non-negative integer" >&2
    exit 1
  fi
  count_status=0
  current_count="$(grep -ic -e 'is deprecated' -e 'was deprecated' "$build_log")" || count_status=$?
  if [[ "$count_status" -gt 1 ]]; then
    echo "verify: could not count deprecation warnings (grep exit $count_status)" >&2
    exit 1
  fi
  if ! git -C "$root" check-ignore -q -- "$root/build/verify/deprecation-warnings.txt"; then
    echo "verify: build/verify/deprecation-warnings.txt must be ignored; add the app's /build/ to .gitignore before rerunning just verify" >&2
    exit 1
  fi
  mkdir -p "$root/build/verify"
  printf '%s\n' "$current_count" > "$root/build/verify/deprecation-warnings.txt"
  if ! python3 -c 'import sys; sys.exit(0 if int(sys.argv[1]) <= int(sys.argv[2]) else 1)' "$current_count" "$baseline_count"; then
    echo "verify: deprecation warnings grew from $baseline_count ($baseline_source) to $current_count — fix the new warnings or agree a baseline change on main" >&2
    exit 1
  fi
  echo "verify: deprecation warnings $current_count ($baseline_source baseline $baseline_count)"
  echo "verify: incremental count is a lower bound; only a clean build re-emits warnings for all built targets (test output is not counted)"
fi

if cfg_bool todo_scan false; then
  scan_status=0
  rg -n 'TODO\(|FIXME\(|#warning' --glob '*.swift' "$(project_root)" || scan_status=$?
  case "$scan_status" in
    0) echo "todo_scan found markers" >&2; exit 1 ;;
    1) ;;
    *) echo "todo_scan failed (exit $scan_status); repair the scan, then rerun just verify." >&2; exit "$scan_status" ;;
  esac
fi

receipt record "$verified_state"
echo "$verification_summary"
