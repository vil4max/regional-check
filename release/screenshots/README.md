# English screenshot set for 3.0.0

The six PNGs in `asc/` are the set for version 3.0.0, iPhone 6.5" display, in
this storefront order. They replace the five uploaded to App Store Connect on
2026-09-21, which showed the earlier radar and had no "Stay Alert" screen; the
owner uploads them. The Ukrainian and Russian localizations use the same
English set.

1. `asc/01-onboarding.png` — first launch: what the app does, "Get Started".
2. `asc/02-status-no-alert.png` — Status, Lviv Oblast with no alert and the
   inline alert map.
3. `asc/03-status-stay-alert.png` — Status, Cherkasy Oblast in yellow "Stay
   Alert": quiet, with most of its neighbours under alert, and the nearby line.
4. `asc/04-status-alert.png` — Status, Kharkiv Oblast under alert.
5. `asc/05-region-list.png` — the read-only region list opened from the map.
6. `asc/06-details.png` — Details: summary, Live Activity switch, purchases,
   data source.

All six are 1284 x 2778 opaque portrait images.

## Capture provenance

Recaptured on 2026-09-22 from the 3.0.0 round-9 candidate (Debug build of the
same tree) on a freshly erased iPhone 17 simulator reserved for one agent
session, with live provider data, not with `just screenshots`. That script's
Status phases render the offline fixture, whose map is a stylized grid of
squares rather than the map of Ukraine, and a store screenshot must not show a
map the app never draws.

The app ran with `-ScreenshotPhase live` (and `onboarding`, `region-list`,
`details`), which uses the live container and only suppresses the first-launch
cover; `hasCompletedOnboarding` was set in the app's defaults so the location
request is not held back (REQ-REGION-010). The simulator's location was set to
Lviv, Cherkasy and Kharkiv, chosen from the live feed at capture time, and each
location was opened once before the shot so the region change notice was not
on screen. Status, nearby line, map and region counts on each screen come from
the same feed. The status bar was overridden to the capture time with a full
battery. The raw 1206 x 2622 captures were resized to 1284 x 2778 with `sips`,
as the capture script does, and flattened to opaque RGB.

Until the capture script can render the provider map, recapture the store set
the same way.
