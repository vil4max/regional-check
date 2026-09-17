#!/usr/bin/env bash
# Runs a command while holding one of VERIFY_SLOTS machine-wide slots shared by
# every worktree of this repository, so parallel task sessions queue for
# `just verify` instead of overloading the Mac and timing out simulator tests.
set -euo pipefail

slots="${VERIFY_SLOTS:-1}"
poll_seconds=5
common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
slot_root="$common_dir/verify-slots"
mkdir -p "$slot_root"

held=""
release() {
  if [[ -n "$held" ]]; then
    rm -rf "$held"
  fi
}
trap release EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# A slot is a directory: mkdir is atomic, so two sessions cannot take the same one.
try_acquire() {
  local i dir owner
  for ((i = 1; i <= slots; i++)); do
    dir="$slot_root/slot-$i"
    # Reclaim a slot whose holder died without cleanup (crash, kill -9).
    owner="$(head -1 "$dir/owner" 2>/dev/null || true)"
    if [[ -n "$owner" ]] && ! kill -0 "$owner" 2>/dev/null; then
      rm -rf "$dir"
    fi
    if mkdir "$dir" 2>/dev/null; then
      printf '%s\n%s\n%s\n' "$$" "$(git rev-parse --show-toplevel)" "$(date '+%H:%M:%S')" >"$dir/owner"
      held="$dir"
      return 0
    fi
  done
  return 1
}

waited=0
until try_acquire; do
  if ((waited % 60 == 0)); then
    echo "verify-slot: all $slots slot(s) busy, waiting ${waited}s:" >&2
    for dir in "$slot_root"/slot-*; do
      [[ -f "$dir/owner" ]] || continue
      echo "  pid $(sed -n 1p "$dir/owner") in $(sed -n 2p "$dir/owner") since $(sed -n 3p "$dir/owner")" >&2
    done
  fi
  sleep "$poll_seconds"
  waited=$((waited + poll_seconds))
done

if ((waited > 0)); then
  echo "verify-slot: acquired $(basename "$held") after ${waited}s" >&2
fi
"$@"
