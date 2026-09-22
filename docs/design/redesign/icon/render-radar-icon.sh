#!/bin/bash
# Renders a Mark icon SVG to a 1024 px PNG with the Status hero's radar sweep frozen at the top.
# Usage: docs/design/redesign/icon/render-radar-icon.sh <mark.svg> <sweep-color> <out.png>
# The sweep is a conic gradient, which SVG cannot express, so it is computed with ImageMagick
# (Q16 HDRI, so the ramp does not band) and composited between the tick ring and the disc,
# the order StatusHeroGraphic draws them in.
set -euo pipefail
svg=$1 color=$2 out=$3
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
anchor='<circle cx="50" cy="50" r="19"'
python3 - "$svg" "$work" "$anchor" <<'PY'
import sys
svg, work, anchor = sys.argv[1:4]
s = open(svg).read()
assert s.count(anchor) == 1
head, tail = s.split(anchor)
open(f"{work}/under.svg", "w").write(head + "</svg>")
root = s[: s.index(">") + 1]
open(f"{work}/over.svg", "w").write(root + anchor + tail)
PY
resvg -w 1024 -h 1024 "$work/under.svg" "$work/under.png"
resvg -w 1024 -h 1024 "$work/over.svg" "$work/over.png"
# Status hero radar: clear for 72 % of the turn from the top, rising linearly to 32 % back at
# the top; radius = tick ring inner edge (29.5 of 100 units).
magick -size 1024x1024 xc:black -fx '
  offx = i + 0.5 - 512; offy = 512 - (j + 0.5);
  turn = atan2(offx, offy) / (2 * pi); turn = turn < 0 ? turn + 1 : turn;
  inside = hypot(offx, offy) <= 302.08 ? 1 : 0;
  inside * (turn < 0.72 ? 0 : 0.32 * (turn - 0.72) / 0.28)' "$work/mask.png"
magick -size 1024x1024 "xc:$color" "$work/mask.png" -alpha off -compose CopyOpacity -composite "$work/sweep.png"
magick "$work/under.png" "$work/sweep.png" -compose Over -composite "$work/over.png" -compose Over -composite \
  -alpha off -strip "$out"
