#!/usr/bin/env bash
# Rewrites .swiftlint.baseline.json: the violations that exist today, so that only new ones fail.
#
# `swiftlint --write-baseline` stores absolute file URLs, and SwiftLint matches a baseline entry by
# that path. A baseline written that way does not match in another checkout, another worktree or
# CI, and it publishes the author's home path. This script writes the same baseline with
# repository-relative paths, which SwiftLint resolves against the working directory.
#
# Usage: scripts/swiftlint-baseline.sh
# Run it only when a violation is deliberately accepted or after a refactor removes some;
# review the diff of the baseline like any other change.
set -euo pipefail

case "${1:-}" in
  -h | --help)
    sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;
  *)
    echo "usage: scripts/swiftlint-baseline.sh [--help]" >&2
    exit 2
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
command -v swiftlint >/dev/null || { echo "swiftlint not found (brew install swiftlint)" >&2; exit 2; }

RAW="$(mktemp "${TMPDIR:-/tmp}/swiftlint-baseline.XXXXXX")"
trap 'rm -f "$RAW"' EXIT

# The exit status counts the violations being recorded, so it is not a failure here.
swiftlint lint --config .swiftlint.yml --quiet --write-baseline "$RAW" >/dev/null 2>&1 || true
[[ -s "$RAW" ]] || { echo "swiftlint wrote no baseline" >&2; exit 1; }

python3 - "$RAW" "$ROOT" >.swiftlint.baseline.json <<'PY'
import json
import os
import sys
from urllib.parse import unquote, urlparse

raw, root = sys.argv[1], sys.argv[2]
roots = {root, os.path.realpath(root)}
entries = json.load(open(raw))
for entry in entries:
    location = entry["violation"]["location"]
    path = unquote(urlparse(location["file"]).path)
    relative = [os.path.relpath(path, base) for base in roots if path.startswith(base + os.sep)]
    if not relative:
        sys.exit(f"baseline entry outside the repository: {path}")
    location["file"] = relative[0]
entries.sort(key=lambda e: (
    e["violation"]["location"]["file"],
    e["violation"]["location"]["line"],
    e["violation"]["ruleIdentifier"],
))
json.dump(entries, sys.stdout, indent=1, sort_keys=True)
sys.stdout.write("\n")
PY
echo "wrote .swiftlint.baseline.json ($(python3 -c 'import json;print(len(json.load(open(".swiftlint.baseline.json"))))') violations)"
