# Cached Launch Status

## Goal

Show the latest known regional status immediately on app launch while refreshing data in background.

## Constraints

- Network remains the source of truth.
- Cache is only a temporary snapshot.
- Existing refresh flow must continue working.
- Stale data must be identifiable.

## Acceptance Criteria

- App can display cached status on cold launch.
- Fresh network data replaces cached data.
- Offline launch works.
- Unit tests cover cache scenarios.

## Failure Conditions

- Cached data overrides fresh network data.
- Cache logic is mixed with UI code.
- Existing loading behavior is broken.