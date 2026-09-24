# Changelog

## [3.1.0] - unreleased

### Features

- Fold glass: the Status screen stays where it was as you tilt the phone, seen through frosted glass. It is a switch on Details, on by default, and it is off with Reduce Motion or Low Power Mode. The status is always readable.
- Kyiv shows the yellow "Stay Alert" whenever Kyiv Oblast is under alert.
- The Control Center and Lock Screen control shows the same status as the widget: the yellow warning for "Stay Alert" and the clock for old data.
- The Live Activity has a Refresh button that checks again without opening the app, and ends the activity once the alert is over.

### Bug Fixes

- The Live Activity shows old data with a grey clock instead of a yellow one, since yellow now means "Stay Alert".
- A Live Activity whose alert may be over no longer looks current: a stale alarm stays red and says "May be outdated. Open the app.", and iOS marks it stale 15 minutes after the last check.
- A widget with data 10 minutes old or more says "Open the app to update".

## [3.0] - unreleased

### Features

- Two tabs on iPhone, Status and Details. Status shows the region's status at a glance, a nearby-alert line even while your own region is under alert, and the alert map inline under it.
- The region always follows your location; without location access the app shows Kyiv and says that enabling location gives a more precise region. Tapping the map opens a read-only list of every region's status.
- Details holds the full summary, the Live Activity switch, Restore Purchases, the data source and the disclaimer. While iOS Settings has Live Activities off for the app, the switch says so and links to Settings.
- CarPlay is one uncluttered screen: the status, your region and when it was updated, nearby alerts only when there are any, and Refresh. The region row shows the update time alone, without a mode word.
- A yellow "Stay Alert" status when most regions around yours are under alert, on iPhone, CarPlay and the Home Screen widget; old data is shown in grey.
- A radar sweep on the Status screen shows the app is watching.
- Redesigned widgets and Live Activity. The Live Activity now follows the alert: it starts when an alert is seen, stays when you leave the app, and ends when the app or CarPlay sees the all-clear.
- Real first-launch onboarding, and a clearer sheet when you leave Ukraine.
- New app icon: a road into a sunrise over Kyiv under an alert signal, with Dark and Tinted appearances.
- Asking Siri for the alert status checks for fresh data first, answers "Stay Alert" when most regions around yours are under alert, and says how old the data is when it could not be refreshed. Siri no longer reads out the data provider's name.
- Faster, steadier launch: a cached status appears immediately instead of waiting behind a checking animation.
- Haptic feedback: a pull to refresh answers with a haptic instead of a message (an error haptic when the alert source fails), and tab switches and buttons respond to touch.

### Removed

- The Regions tab, region search, the follow-location switch and manual region pinning.
- The second region and its widget. A placed secondary-region widget becomes unavailable after the update.
- The full-screen map and the About screen (now inline on Status and part of Details).

### Bug Fixes

- Opening the app in a different region than the stored one switches on the first location fix instead of after 90 seconds, and a parked car no longer keeps a pending region change from completing.
- Repeated refreshes are held inside a ten-second floor, and a rate-limited provider is retried with growing delays instead of every 30 seconds.
- CarPlay no longer stays on "Checking…" after a refresh that was cancelled or superseded.
- A stale or failed refresh no longer downgrades an active alert — only a confirmed all-clear does.
- Onboarding now appears on a first launch outside Ukraine, instead of the outside-Ukraine sheet taking its place.
- Shortcuts shows the region and refresh actions in Russian and Ukrainian instead of raw identifiers.
- A region missing from the alert feed now says so, instead of showing "Checking…" indefinitely.
- The location permission prompt no longer appears over onboarding: it waits until onboarding is finished and something needs location.
- Onboarding no longer offers to pick a region, and its title and subtitle scale with Dynamic Type.
- At the largest text sizes the map caption and the summary header stay whole instead of truncating or breaking mid-word.
- The summary lists regions under alert in the same order as the region list.
- Pull to refresh shows its spinner again, and the title bar no longer covers the top of the status ring.
- CarPlay shows the new app icon instead of the pre-3.0 one.
- The alert map no longer fails to load on some launches.

### Requirements

- Minimum iOS raised to 27.

### Breaking Changes

- None.

## [2.7] - 2026-09-14

### Improvements

- Restored standard refresh frequency (60s quiet / 30s alarm) on cellular data in CarPlay.
- Preserved danger and clear alert statuses during transient connection delays instead of prematurely obscuring them with outdated data labels.
- Added a 3-tier freshness model (`fresh`, `aging`, `expired`) with clear time attribution.
- Preserved danger alerts prominently with explicit staleness markers instead of hiding them behind error screens.

## [2.6] - 2026-09-13

### Improvements

- Updated widgets with clearer alert labels and colors consistent with the app.
- Show an explicit outdated-data state when the last update is no longer current.
- Reduced unnecessary widget refreshes when the cached status has not changed.
- Added the updated layout and refresh control to the secondary-region widget.

## [2.5] - 2026-09-10

### Features

- Made CarPlay driver status clearer and more current while driving.

### Bug Fixes

- Improved the visibility of the clear status in CarPlay with a green indicator.
- Corrected alert-region classification so status alerts are interpreted consistently.

### Chores

- Prepared the app and widget for the 2.5 release.
- Expanded coverage for alert validation, shared-state migration, and refresh behavior.

### Breaking Changes

- None.
