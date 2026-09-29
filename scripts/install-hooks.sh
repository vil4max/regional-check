#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/hooks"

if [[ ! -d "$HOOKS_DIR" ]]; then
  echo "Git hooks directory not found: $HOOKS_DIR" >&2
  exit 1
fi

WRAPPER='#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
exec "$ROOT/.githooks/$(basename "$0")" "$@"'

install_hook() {
  local name="$1"
  local src="$ROOT/.githooks/$name"
  local dst="$HOOKS_DIR/$name"
  if [[ ! -f "$src" ]]; then
    echo "Missing hook source: $src" >&2
    exit 1
  fi
  printf '%s\n' "$WRAPPER" >"$dst"
  chmod +x "$dst" "$src"
  echo "Installed $name → $dst (delegates to .githooks/$name)"
}

# Without .githooks/pre-push, the pre-push wrapper that earlier versions installed fails every push.
remove_retired_wrapper() {
  local name="$1"
  local dst="$HOOKS_DIR/$name"
  if [[ -f "$dst" && "$(cat "$dst")" == "$WRAPPER" ]]; then
    rm "$dst"
    echo "Removed the retired $name wrapper → $dst"
  fi
}

install_hook pre-commit
remove_retired_wrapper pre-push
git -C "$ROOT" config --local agentsKit.allowTrackedHooks true

echo "pre-commit → format + lint"
echo "pre-push → no repository hook: builds and tests run in just verify and CI"
