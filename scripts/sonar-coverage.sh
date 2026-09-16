#!/usr/bin/env bash
# Converts Xcode test coverage into SonarQube generic coverage XML.
#
# Usage: scripts/sonar-coverage.sh <derived-data-dir> <output.xml> <profile.profdata>...
#
# Uses llvm-cov rather than `xccov`: DriveCheckKit runs from a dynamic package
# framework that xccov does not attribute to any target, so its lines would be
# missing. Several profiles (for example unit and snapshot test runs) are merged.
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <derived-data-dir> <output.xml> <profile.profdata>..." >&2
  exit 64
fi

DERIVED_DATA="$1"
OUTPUT="$2"
shift 2

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PRODUCTS="$DERIVED_DATA/Build/Products/Debug-iphonesimulator"
APP_BINARY="$PRODUCTS/RegionalCheck.app/RegionalCheck.debug.dylib"
KIT_BINARY="$(find "$PRODUCTS/RegionalCheck.app/Frameworks" -type f -name 'DriveCheckKit_*PackageProduct' 2>/dev/null | head -1)"

[[ -f "$APP_BINARY" ]] || { echo "missing app binary: $APP_BINARY" >&2; exit 1; }
[[ -n "$KIT_BINARY" ]] || { echo "missing DriveCheckKit framework binary under $PRODUCTS" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

xcrun llvm-profdata merge -sparse -o "$WORK/merged.profdata" "$@"
xcrun llvm-cov export -format=lcov -instr-profile "$WORK/merged.profdata" \
  "$APP_BINARY" -object "$KIT_BINARY" > "$WORK/coverage.lcov"

mkdir -p "$(dirname "$OUTPUT")"
python3 - "$WORK/coverage.lcov" "$ROOT" "$OUTPUT" <<'PY'
import os
import sys
from xml.sax.saxutils import quoteattr

lcov_path, root, output = sys.argv[1], sys.argv[2].rstrip("/") + "/", sys.argv[3]
included = ("RegionalCheck/", "Packages/DriveCheckKit/Sources/")

files = {}
current = None
with open(lcov_path) as lcov:
    for line in lcov:
        line = line.strip()
        if line.startswith("SF:"):
            path = os.path.realpath(line[3:])
            rel = path[len(root):] if path.startswith(root) else None
            current = files.setdefault(rel, {}) if rel and rel.startswith(included) else None
        elif line.startswith("DA:") and current is not None:
            number, count = line[3:].split(",")[:2]
            number, count = int(number), int(count)
            current[number] = current.get(number, 0) + count

with open(output, "w") as xml:
    xml.write('<coverage version="1">\n')
    for rel in sorted(files):
        xml.write(f"  <file path={quoteattr(rel)}>\n")
        for number in sorted(files[rel]):
            covered = "true" if files[rel][number] > 0 else "false"
            xml.write(f'    <lineToCover lineNumber="{number}" covered="{covered}"/>\n')
        xml.write("  </file>\n")
    xml.write("</coverage>\n")

lines = sum(len(v) for v in files.values())
covered = sum(1 for v in files.values() for c in v.values() if c > 0)
print(f"sonar coverage: {len(files)} files, {covered}/{lines} lines ({covered / max(lines, 1):.1%})")
PY
