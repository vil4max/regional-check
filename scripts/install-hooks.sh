#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$ROOT/.git/hooks"

if [[ ! -d "$HOOKS_DIR" ]]; then
  echo "Not a git checkout with .git/hooks" >&2
  exit 1
fi

install_hook() {
  local name="$1"
  local src="$ROOT/.githooks/$name"
  local dst="$HOOKS_DIR/$name"
  if [[ ! -f "$src" ]]; then
    echo "Missing hook source: $src" >&2
    exit 1
  fi
  cp "$src" "$dst"
  chmod +x "$dst" "$src"
  echo "Installed $name → .git/hooks/$name"
}

chmod +x "$ROOT/scripts/smoke-tests.sh"
install_hook pre-commit
install_hook pre-push

echo "pre-commit → format + lint"
echo "pre-push → scripts/smoke-tests.sh"
