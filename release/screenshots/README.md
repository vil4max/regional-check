# English screenshot set for 3.0.0

The five PNGs in `asc/` are the set uploaded to App Store Connect on 2026-09-21
for version 3.0.0, iPhone 6.5" display, in this storefront order. The Ukrainian
and Russian localizations use the same English set.

1. `asc/01-onboarding.png` — first launch: what the app does, "Get Started".
2. `asc/02-status-no-alert.png` — Status, Kyiv with no alert, the nearby-alert
   line and the inline alert map.
3. `asc/03-status-alert.png` — Status, Kharkiv Oblast under alert.
4. `asc/04-region-list.png` — the read-only region list opened from the map.
5. `asc/05-details.png` — Details: summary, Live Activity switch, purchases,
   data source.

All five are 1284 x 2778 portrait images.

## Capture provenance

Captured from the final two-tab build on a dedicated, freshly created iPhone 17
simulator with live provider data, not with `just screenshots`. That script's
Status phases render the offline fixture, whose map is a stylized grid of
squares rather than the map of Ukraine, and a store screenshot must not show a
map the app never draws.

The simulator's location was set to Kyiv city for the no-alert shot and to
Kharkiv for the alert shot, chosen from the live feed at capture time, so each
screen's status, nearby line, map and region counts agree with each other.
Counts differ slightly between shots because the feed changed during the
session. The status bar was overridden to the capture time with a full
battery, and the region change notice was dismissed before the alert shot. The
raw 1206 x 2622 captures were resized to 1284 x 2778 with `sips`, as the
capture script does.

Until the capture script can render the provider map, recapture the store set
the same way.
