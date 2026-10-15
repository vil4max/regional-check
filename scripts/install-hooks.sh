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

install_hook pre-commit
git -C "$ROOT" config --local agentsKit.allowTrackedHooks true

echo "pre-commit → swift-format and SwiftLint on the staged Swift files"
echo "pre-push → no repository hook: builds and tests run in ios-verify and CI"
