#!/usr/bin/env bash
# Regenerates RegionalCheck/Resources/UkraineOutlines.json and
# RegionalCheck/Data/UkraineOutlines+Aspect.swift from the pinned boundary release (MAP-native AC-11).
# Offline data step, not part of the build: run it by hand and commit both outputs.
set -euo pipefail

SOURCE_URL="https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbHumanitarian/UKR/ADM1/geoBoundaries-UKR-ADM1.geojson"
MAPSHAPER="mapshaper@0.7.101"
SIMPLIFY="1%"

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL "$SOURCE_URL" -o "$work/adm1.geojson"
# Topology-aware: the whole layer is simplified at once, so neighbours keep one shared border.
npx --yes "$MAPSHAPER" "$work/adm1.geojson" \
  -simplify "$SIMPLIFY" weighted keep-shapes \
  -o format=geojson precision=0.0001 "$work/simplified.geojson"

python3 -I "$root/scripts/map/compact_outlines.py" "$work/simplified.geojson" \
  "$root/RegionalCheck/Resources/UkraineOutlines.json" \
  "$root/RegionalCheck/Data/UkraineOutlines+Aspect.swift"
