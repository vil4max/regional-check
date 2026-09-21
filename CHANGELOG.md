# Changelog

## [3.0] - unreleased

### Features

- Two tabs on iPhone, Status and Details. Status shows the region's status at a glance, a nearby-alert line even while your own region is under alert, and the alert map inline under it.
- The region always follows your location; without location access the app shows Kyiv and says that enabling location gives a more precise region. Tapping the map opens a read-only list of every region's status.
- Details holds the full summary, the Live Activity switch, Restore Purchases, the data source and the disclaimer.
- CarPlay has two tabs, Status and Alert map: the regional map as a reference image, the number of regions under alert, the affected list, and Refresh on demand.
- Redesigned widgets and Live Activity.
- Real first-launch onboarding, and a clearer sheet when you leave Ukraine.
- New app icon with Dark and Tinted appearances.
- Faster, steadier launch: a cached status appears immediately instead of waiting behind a checking animation.

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
