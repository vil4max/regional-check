#!/bin/bash
# Turns the owner's road-and-signal artwork (road-source.png, 2026-09-22) into the app icon set:
# a road into a sunrise over Kyiv under two red alert-signal arcs.
# Usage: docs/design/redesign/icon/road/render-road-icon.sh <AppIcon.appiconset dir>
#
# The source's "transparent" background is a checkerboard baked into opaque pixels. It is keyed out
# as the neutral light pixels (chroma < 6 %, every channel > 60 %) connected to the image border, so
# the bluish road markings and the white-hot sun stay. Edge colours are taken from 3 px inside the
# shape and pushed outward before the soft mask is applied, which removes the grey checkerboard
# fringe. The artwork is scaled evenly so the hills and road span the full width, with a 30 px
# margin above the arcs; the road runs on past the bottom edge. Each appearance gets its own sky:
# day for Default, night for Dark, and black under a grey foreground for Tinted.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$1
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
src="$here/road-source.png"
magick "$src" -fx 'chroma = max(r,max(g,b)) - min(r,min(g,b)); (chroma < 0.06 && min(r,min(g,b)) > 0.6) ? 1 : 0' \
  -fill gray50 -fuzz 1% -draw "color 0,0 floodfill" -draw "color 1253,0 floodfill" \
  -draw "color 0,1253 floodfill" -draw "color 1253,1253 floodfill" \
  -fx 'abs(u-0.5) < 0.1 ? 0 : 1' "PNG24:$work/alpha.png"
magick "$work/alpha.png" -morphology Erode Disk:3 "PNG24:$work/alpha-core.png"
magick "$src" "$work/alpha-core.png" -alpha off -compose CopyOpacity -composite "$work/ext.png"
for radius in 2 4 8 16; do
  magick "$work/ext.png" \( +clone -channel RGBA -blur "0x$radius" \) +swap -compose Over -composite "$work/ext.png"
done
magick "$work/alpha.png" -morphology Erode Disk:1.5 -blur 0x0.9 "PNG24:$work/alpha-soft.png"
# The artwork's bounding box in the 1254 px source is 1102 x 1126 at (76, 68).
magick "$work/ext.png" -alpha off "$work/alpha-soft.png" -compose CopyOpacity -composite \
  -crop 1102x1126+76+68 +repage -resize 1024x "$work/fg.png"
sky() { # out top middle horizon; the horizon colour sits behind the skyline
  magick \( -size 1024x460 gradient:"$2"-"$3" \) \( -size 1024x180 gradient:"$3"-"$4" \) \
    \( -size 1024x384 xc:"$4" \) -append "$1"
}
sky "$work/day.png" '#0E4FB8' '#3F8AE0' '#F3AA70'
sky "$work/night.png" '#03060F' '#0C1733' '#3A2745'
magick "$work/day.png" "$work/fg.png" -geometry +0+30 -compose Over -composite -alpha off -strip "PNG24:$out/AppIcon.png"
magick "$work/night.png" "$work/fg.png" -geometry +0+30 -compose Over -composite -alpha off -strip "PNG24:$out/AppIcon-Dark.png"
magick -size 1024x1024 xc:black \( "$work/fg.png" -colorspace Gray -colorspace sRGB \) -geometry +0+30 \
  -compose Over -composite -alpha off -strip "PNG24:$out/AppIcon-Tinted.png"
sips -z 120 120 "$out/AppIcon.png" --out "$out/AppIcon-Car-120.png" >/dev/null
sips -z 180 180 "$out/AppIcon.png" --out "$out/AppIcon-Car-180.png" >/dev/null
