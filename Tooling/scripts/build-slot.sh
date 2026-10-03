#!/usr/bin/env bash
# Machine-wide limit on concurrent Xcode builds and tests, shared by every app,
# worktree and self-hosted CI job on this Mac (BUILD_SLOTS, default 2).
#
#   build-slot.sh run <command…>          hold a slot while the command runs
#   build-slot.sh acquire <label> [min]   hold a slot for Xcode MCP work; prints a token
#   build-slot.sh release <token>         free a slot taken with acquire
#   build-slot.sh status                  list holders
#
# Parallel sessions otherwise starve each other: at load averages of 500–900 a
# concurrency test sat at 0 % CPU for 12 minutes and timed out. Drive Check first
# kept its slots inside its own Git directory, so they were per repository: a
# pitstop test run outside them pushed load to about 800 on 10 cores and failed
# Drive Check's gate. The slot directory therefore lives outside any repository.
set -euo pipefail

slots="${BUILD_SLOTS:-2}"
poll_seconds="${BUILD_SLOT_POLL_SECONDS:-5}"
max_hold_minutes=60
slot_root="${BUILD_SLOT_DIR:-$HOME/Library/Caches/ios-agent-toolchain/build-slots}"
command -v python3 >/dev/null 2>&1 || { echo "build-slot: python3 not installed. Fix: brew bundle --file \"$(dirname "${BASH_SOURCE[0]}")/../Brewfile\", then rerun just build-slot status." >&2; exit 1; }
mkdir -p "$slot_root"

# Bound the delay under sustained load; unavailable readings leave slot locking in charge.
load_poll_seconds="${BUILD_SLOT_LOAD_POLL_SECONDS:-15}"
load_timeout_seconds="${BUILD_SLOT_LOAD_TIMEOUT_SECONDS:-90}"

current_loadavg() {
  if [[ -n "${AGENT_RUNTIME_LOADAVG:-}" ]]; then
    echo "$AGENT_RUNTIME_LOADAVG"
  else
    sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}' || true
  fi
}

current_ncpu() {
  if [[ -n "${AGENT_RUNTIME_NCPU:-}" ]]; then
    echo "$AGENT_RUNTIME_NCPU"
  else
    sysctl -n hw.ncpu 2>/dev/null || true
  fi
}

load_exceeds_cores() {
  local load="$1" ncpu="$2"
  awk -v l="$load" -v n="$ncpu" 'BEGIN{exit !(l>n)}'
}

wait_for_load() {
  [[ "$load_poll_seconds" =~ ^[1-9][0-9]*$ && "$load_timeout_seconds" =~ ^[0-9]+$ ]] \
    || { echo "build-slot: load poll must be a positive integer and timeout a non-negative integer" >&2; return 2; }
  local load ncpu waited=0 pause
  load_poll_seconds=$((10#$load_poll_seconds))
  load_timeout_seconds=$((10#$load_timeout_seconds))
  load="$(current_loadavg)"
  ncpu="$(current_ncpu)"
  [[ -n "$load" && -n "$ncpu" ]] || return 0
  while load_exceeds_cores "$load" "$ncpu"; do
    if ((waited >= load_timeout_seconds)); then
      echo "build-slot: load $load still exceeds $ncpu cores after ${waited}s, taking a slot anyway" >&2
      return 0
    fi
    ((waited == 0)) && echo "build-slot: load $load exceeds $ncpu cores, waiting for it to drop (poll ${load_poll_seconds}s, timeout ${load_timeout_seconds}s)" >&2
    pause="$load_poll_seconds"
    ((pause <= load_timeout_seconds - waited)) || pause=$((load_timeout_seconds - waited))
    sleep "$pause"
    waited=$((waited + pause))
    load="$(current_loadavg)"
    ncpu="$(current_ncpu)"
  done
}

usage() {
  sed -n '5,8p' "$0" | sed 's/^# //' >&2
  exit 2
}

where() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Keep the lock file permanently: deleting it would let two processes lock
# different inodes. A crashed initializer releases this lock automatically.
slot_state() {
  python3 - "$slot_root" "$@" <<'PY'
import fcntl
import os
from pathlib import Path
import re
import shutil
import signal
import sys
import time

root, mode = Path(sys.argv[1]), sys.argv[2]

def owner(path):
    try:
        return (path / 'owner').read_text().splitlines()[0]
    except (OSError, IndexError, UnicodeError):
        return ''

def alive(pid):
    # Slot holders are this user's processes, so a PID this user may not signal
    # was reused by someone else's process and no longer holds the slot.
    try:
        numeric_pid = int(pid)
    except ValueError:
        return False
    try:
        os.kill(numeric_pid, 0)
        return True
    except (ProcessLookupError, PermissionError, OverflowError):
        # An out-of-range PID cannot identify a live holder on this platform.
        return False

try:
    # A cache cleaner may remove the root while a command runs. Nothing is left
    # to release then; claim and reclaim recreate it.
    if mode == 'release' and not root.is_dir():
        if sys.argv[5] == 'terminate':
            print(f'build-slot: {sys.argv[3]}:{sys.argv[4]} no longer holds a slot', file=sys.stderr)
        sys.exit(0)
    root.mkdir(parents=True, exist_ok=True)
    with (root / '.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if mode == 'release':
            name, pid, terminate = sys.argv[3:6]
            if not re.fullmatch(r'slot-[0-9]+', name) or not pid.isdigit() or int(pid) <= 0:
                raise ValueError('invalid slot token')
            path = root / name
            held = owner(path) == pid
            if held:
                if terminate == 'terminate':
                    try:
                        os.kill(int(pid), signal.SIGTERM)
                    except (ProcessLookupError, PermissionError):
                        pass
                shutil.rmtree(path)
            if terminate == 'terminate':
                message = f'released {name}' if held else f'{name}:{pid} no longer holds a slot'
                print('build-slot: ' + message, file=sys.stderr)
            sys.exit(0)

        for path in root.glob('slot-*'):
            if not re.fullmatch(r'slot-[0-9]+', path.name):
                continue
            try:
                if not path.is_dir() or path.is_symlink():
                    continue
                pid = owner(path)
                if re.fullmatch(r'[0-9]+', pid) and pid.lstrip('0'):
                    stale = not alive(pid)
                else:
                    # Older scripts do not hold this lock. Give an incomplete
                    # claim a grace period before treating it as an abandoned one.
                    stale = time.time() - path.stat().st_mtime >= 60
                if stale:
                    shutil.rmtree(path)
            except FileNotFoundError:
                # An older non-locking releaser can remove this entry after listing.
                continue

        if mode == 'claim':
            pid, label, repository, started, count = sys.argv[3:8]
            if not alive(pid):
                raise ValueError('slot holder exited before acquisition')
            for index in range(1, int(count) + 1):
                path = root / f'slot-{index}'
                try:
                    path.mkdir()
                except FileExistsError:
                    continue
                (path / 'owner').write_text('\n'.join((pid, repository, started, label)) + '\n')
                print(path)
                sys.exit(0)
            sys.exit(1)
except Exception as error:
    print('build-slot: ' + str(error), file=sys.stderr)
    sys.exit(2)
PY
}

try_acquire() {
  slot_state claim "$1" "$2" "$(where)" "$(date '+%H:%M:%S')" "$slots"
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
  local holder_pid="$1" label="$2" waited=0 dir status
  until dir="$(try_acquire "$holder_pid" "$label")"; do
    status=$?
    ((status == 1)) || return "$status"
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
    # A command already inside a slot (verify calling build and test) must not
    # take a second one: with two slots, two such sessions would deadlock.
    if [[ -n "${BUILD_SLOT_HELD:-}" ]]; then
      exec "$@"
    fi
    wait_for_load
    held="$(wait_for_slot "$$" "run: $(basename "$1")")"
    # The wrapped command's status is the script's status: a failing release
    # (for example after a cache cleaner removed the root) must not replace it.
    rc=0
    trap 'rc=$?; slot_state release "$(basename "$held")" "$$" keep || true; exit "$rc"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    BUILD_SLOT_HELD="$held" "$@"
    ;;
  acquire)
    label="${2:?acquire needs a label}"
    minutes="${3:-30}"
    ((minutes > 0 && minutes <= max_hold_minutes)) || { echo "minutes must be 1–$max_hold_minutes" >&2; exit 2; }
    wait_for_load
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
    pid="${token##*:}"
    slot_state release "${token%%:*}" "$pid" terminate
    ;;
  status)
    slot_state reclaim
    echo "build-slot: $slots slot(s) in $slot_root" >&2
    print_holders
    ;;
  *)
    usage
    ;;
esac
