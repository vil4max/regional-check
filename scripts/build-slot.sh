#!/usr/bin/env bash
# Machine-wide limit on concurrent Xcode builds and tests across every worktree
# of this repository (BUILD_SLOTS, default 2). Parallel sessions otherwise
# starve each other: at load averages of 500–900 a concurrency test sat at 0 %
# CPU for 12 minutes and timed out.
#
#   build-slot.sh run <command…>          hold a slot while the command runs
#   build-slot.sh acquire <label> [min]   hold a slot for Xcode MCP work; prints a token
#   build-slot.sh release <token>         free a slot taken with acquire
#   build-slot.sh status                  list holders
set -euo pipefail

slots="${BUILD_SLOTS:-2}"
poll_seconds=5
max_hold_minutes=60
common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
slot_root="$common_dir/build-slots"
mkdir -p "$slot_root"

usage() {
  sed -n '7,10p' "$0" | sed 's/^# //' >&2
  exit 2
}

# The holder PID decides liveness: a dead holder's slot is reclaimed, so a crash,
# kill -9, or an expired acquire timer never blocks other sessions for good.
reclaim_dead() {
  local dir owner
  for dir in "$slot_root"/slot-*; do
    [[ -d "$dir" ]] || continue
    owner="$(head -1 "$dir/owner" 2>/dev/null || true)"
    if [[ -n "$owner" ]] && ! kill -0 "$owner" 2>/dev/null; then
      rm -rf "$dir"
    fi
  done
}

# mkdir is atomic, so two sessions cannot take the same slot.
try_acquire() {
  local holder_pid="$1" label="$2" i dir
  reclaim_dead
  for ((i = 1; i <= slots; i++)); do
    dir="$slot_root/slot-$i"
    if mkdir "$dir" 2>/dev/null; then
      printf '%s\n%s\n%s\n%s\n' "$holder_pid" "$(git rev-parse --show-toplevel)" "$(date '+%H:%M:%S')" "$label" \
        >"$dir/owner"
      echo "$dir"
      return 0
    fi
  done
  return 1
}

print_holders() {
  local dir
  for dir in "$slot_root"/slot-*; do
    [[ -f "$dir/owner" ]] || continue
    echo "  $(basename "$dir"): pid $(sed -n 1p "$dir/owner") in $(sed -n 2p "$dir/owner")" \
      "since $(sed -n 3p "$dir/owner") ($(sed -n 4p "$dir/owner"))" >&2
  done
}

wait_for_slot() {
  local holder_pid="$1" label="$2" waited=0 dir
  until dir="$(try_acquire "$holder_pid" "$label")"; do
    if ((waited % 60 == 0)); then
      echo "build-slot: all $slots slot(s) busy, waiting ${waited}s:" >&2
      print_holders
    fi
    sleep "$poll_seconds"
    waited=$((waited + poll_seconds))
  done
  if ((waited > 0)); then
    echo "build-slot: acquired $(basename "$dir") after ${waited}s" >&2
  fi
  echo "$dir"
}

mode="${1:-}"
case "$mode" in
  run)
    shift
    (($#)) || usage
    held="$(wait_for_slot "$$" "run: $1")"
    trap 'rm -rf "$held"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    "$@"
    ;;
  acquire)
    label="${2:?acquire needs a label}"
    minutes="${3:-30}"
    ((minutes > 0 && minutes <= max_hold_minutes)) || { echo "minutes must be 1–$max_hold_minutes" >&2; exit 2; }
    # A detached timer is the holder: release kills it, expiry ends it, and either
    # way the slot becomes reclaimable.
    nohup sleep "$((minutes * 60))" >/dev/null 2>&1 &
    timer=$!
    disown "$timer"
    trap 'kill "$timer" 2>/dev/null || true; exit 130' INT TERM
    if ! held="$(wait_for_slot "$timer" "acquire: $label, ${minutes} min")"; then
      kill "$timer" 2>/dev/null || true
      exit 1
    fi
    echo "$(basename "$held"):$timer"
    ;;
  release)
    token="${2:?release needs the token printed by acquire}"
    dir="$slot_root/${token%%:*}"
    pid="${token##*:}"
    if [[ "$(head -1 "$dir/owner" 2>/dev/null || true)" == "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
      rm -rf "$dir"
      echo "build-slot: released ${token%%:*}" >&2
    else
      echo "build-slot: $token no longer holds a slot (expired or reclaimed)" >&2
    fi
    ;;
  status)
    reclaim_dead
    echo "build-slot: $slots slot(s)" >&2
    print_holders
    ;;
  *)
    usage
    ;;
esac
