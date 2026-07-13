#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_SRC="$ROOT/.githooks/pre-push"
HOOK_DST="$ROOT/.git/hooks/pre-push"

if [[ ! -d "$ROOT/.git/hooks" ]]; then
  echo "Not a git checkout with .git/hooks" >&2
  exit 1
fi

cp "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST" "$HOOK_SRC" "$ROOT/scripts/smoke-tests.sh"
echo "Installed pre-push hook → .git/hooks/pre-push"
echo "Push will run scripts/smoke-tests.sh"
