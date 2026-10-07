#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
validate_runtime_config

if ! cfg_bool lint true; then
  echo "lint skipped (runtime.yml lint: false)"
  exit 0
fi

if ! have swiftlint; then
  echo "swiftlint not installed — brew bundle --file=$(brewfile_path)" >&2
  exit 1
fi

ROOT="$(cd "$(project_root)" && pwd)"
CONF="$TOOLING_ROOT/.swiftlint.yml"
[[ -f "$CONF" ]] || CONF="$ROOT/.swiftlint.yml"
[[ -f "$CONF" ]] || CONF="$RUNTIME_ROOT/templates/swiftlint.yml"
CACHE="$ROOT/build/swiftlint"
mkdir -p "$CACHE"
(cd "$ROOT" && swiftlint --config "$CONF" --cache-path "$CACHE")
