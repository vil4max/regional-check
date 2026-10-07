#!/usr/bin/env bash
# Deletes this app's leftovers: shut-down "Clone N of <device>" simulators that
# killed or hung test runs left behind, and test devices of worktrees that no
# longer exist. Other apps' devices and every booted device are left alone.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
validate_runtime_config
require_runtime_tool python3

worktrees="$(git -C "$(project_root)" worktree list --porcelain)"
live=()
while IFS= read -r path; do
  live+=("$(basename "$path")")
done < <(printf '%s\n' "$worktrees" | sed -n 's/^worktree //p')

# Session naming also changes the default test base; retain the ordinary app prefix.
base="$(
  unset AGENT_HOST AGENT_SESSION_ID CLAUDE_CODE_HOST_SESSION_ID CLAUDE_CODE_SESSION_ID
  sim_test_base_name
)"
prune_args=()
if session_base="$(sim_session_base_name)"; then
  prune_args+=(--session-base "$session_base")
fi

python3 "$SCRIPT_DIR/sim-device.py" clean "$(sim_test_name)" "$(sim_name)"
python3 "$SCRIPT_DIR/sim-device.py" prune ${prune_args[@]+"${prune_args[@]}"} -- "$base" ${live[@]+"${live[@]}"}
