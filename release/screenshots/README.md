# English screenshot set for 3.0.0

The six PNGs in `asc/` are the set for version 3.0.0, iPhone 6.5" display, in
this storefront order. They replace the five uploaded to App Store Connect on
2026-09-21, which showed the earlier radar and had no "Stay Alert" screen; they are
uploaded in App Store Connect. The Ukrainian and Russian localizations use the same
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
same tree) on a freshly erased iPhone 17 simulator reserved for the capture,
with live provider data, by hand. The fixture Status phases render the offline
fixture, whose map is a stylized grid of squares rather than the map of Ukraine,
and a store screenshot must not show a map the app never draws.

The app ran with `-ScreenshotPhase live` (and `onboarding`, `region-list`,
`details`), which uses the live container and only suppresses the first-launch
cover; `hasCompletedOnboarding` was set in the app's defaults so the location
request is not held back (REQ-REGION-010). The simulator's location was set to
Lviv, Cherkasy and Kharkiv, chosen from the live feed at capture time, and each
location was opened once before the shot so the region change notice was not
on screen. Status, nearby line, map and region counts on each screen come from
the same feed. The status bar was overridden to the capture time with a full
battery. The raw 1206 x 2622 captures were resized to 1284 x 2778 with `sips`
and flattened to opaque RGB.

Recapture the store set the same way.

## iPhone Duo set

The Duo screenshots are not committed: they stay in the ignored
`.artifacts/iphone-duo-screenshots/` directory of the primary checkout
(`python3 scripts/project-artifacts.py task iphone-duo-screenshots`) until the owner uploads
them. The six states and their order are the ones above.

- Outer display, 1398 x 2034: `outer-01-onboarding.png` to `outer-06-details.png`, captured on
  2026-10-17 from this branch's Debug build, closed pose, with live data at one moment (13 of 25
  regions under alert): Zakarpattia Oblast for no alert, Kyiv for Stay Alert, Kharkiv Oblast for the
  alert and the region list.
- Inner display, 2853 x 2007 (landscape, an accepted Duo size): `inner-01-onboarding.png` to
  `inner-06-details.png`, captured on 2026-10-17 in the open pose with the same regions; the feed
  moved from 10 to 9 regions under alert during the capture. A portrait inner set (2007 x 2853)
  needs the open pose rotated.

Capture on the iPhone Duo simulator (iOS 27.1 runtime) the same way as the iPhone set, except:

1. The pose is set in Device Hub; nothing else changes it.
2. `xcrun simctl io <device> screenshot --display=<port>` writes one display at its native size,
   so nothing is resized. The port is the one `simctl io <device> enumerate` lists with the
   display's width (1398 outer, 2007 inner); the port IDs change at every boot.
3. The PNG carries an alpha channel; flatten it to opaque RGB before upload.
