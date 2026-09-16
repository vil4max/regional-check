# Changelog

## [3.0] - 2026-09-16

### Features

- Moved the upstream alert map from its own tab onto a compact card at the top of the Home screen; the app now has two tabs (Home, Regions) instead of three.

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
