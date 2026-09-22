#!/bin/bash
# Renders a Mark icon SVG to a 1024 px PNG with the Status hero's radar frozen at 45 degrees.
# Usage: docs/design/redesign/icon/render-radar-icon.sh <mark.svg> <trail-color> <beam-color> <out.png>
# A radar, not a timer (owner reference, 2026-09-22): a light beam line on the leading edge and an
# afterglow fading out behind it, counter-clockwise, over 50 degrees, with no hard trailing edge.
# StatusHeroGraphic draws the same radar. SVG has no conic gradient, so both layers are computed
# with ImageMagick (Q16 HDRI, so the ramp does not band): the afterglow goes between the tick ring
# and the r=19 ring, as in the app, and the beam on top, from the centre dot to the ticks. In the app
# the beam stops at the disc's edge so it does not cross the status symbol; the icon has no symbol,
# so its beam runs from the dot like the reference's.
set -euo pipefail
svg=$1 color=$2 beamcolor=$3 out=$4
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
# Turns clockwise from the top; pixels at 1024 px (tick ring inner edge 302, centre dot edge 87).
polar='offx = i + 0.5 - 512; offy = 512 - (j + 0.5); dist = hypot(offx, offy);
  turn = atan2(offx, offy) / (2 * pi); turn = turn < 0 ? turn + 1 : turn;
  back = 0.125 - turn; back = back < 0 ? back + 1 : back;'
magick -size 1024x1024 xc:black -fx "$polar
  (dist <= 302 ? 1 : 0) * (back <= 0.14 ? 0.8 * (1 - back / 0.14) : 0)" "$work/trail-mask.png"
magick -size 1024x1024 xc:black -fx "$polar
  side = min(back, 1 - back) * 2 * pi * dist;
  (dist <= 302 && dist >= 87 ? 1 : 0) * (side < 4 ? 1 : max(0, 1 - (side - 4) / 12))" "$work/beam-mask.png"
magick -size 1024x1024 "xc:$color" "$work/trail-mask.png" -alpha off -compose CopyOpacity -composite "$work/trail.png"
magick -size 1024x1024 "xc:$beamcolor" "$work/beam-mask.png" -alpha off -compose CopyOpacity -composite "$work/beam.png"
magick "$work/under.png" "$work/trail.png" -compose Over -composite "$work/over.png" -compose Over -composite \
  "$work/beam.png" -compose Over -composite -alpha off -strip "$out"
