#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/hooks"

if [[ ! -d "$HOOKS_DIR" ]]; then
  echo "Git hooks directory not found: $HOOKS_DIR" >&2
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
  cat >"$dst" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
exec "$ROOT/.githooks/$(basename "$0")" "$@"
HOOK
  chmod +x "$dst" "$src"
  echo "Installed $name → $dst (delegates to .githooks/$name)"
}

chmod +x "$ROOT/scripts/smoke-tests.sh"
install_hook pre-commit
install_hook pre-push
git -C "$ROOT" config --local agentsKit.allowTrackedHooks true

echo "pre-commit → format + lint"
echo "pre-push → scripts/smoke-tests.sh"
