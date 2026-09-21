# ADR 0006: Shared module and App Group for extensions

## Context

Drive Check 2.0 adds widgets, App Intents, and a Control Center control. Extensions cannot read the host app's `UserDefaults.standard` or duplicate domain types safely.

## Decision

- Extract shared domain and networking into local SPM package `Packages/DriveCheckKit` (iOS 26, `defaultLocalization: "en"`).
- Persist cross-surface state in App Group `group.vil4max.RegionalCheck` via `SharedStore`.
- After snapshot or region writes, the app calls `WidgetCenter.shared.reloadAllTimelines()`.
- Package strings use `bundle: .module`.

## SharedStore keys

| Key | Purpose |
|-----|---------|
| `shared.snapshot.v1` | Last `AlertsSnapshot` JSON |
| `shared.region.v1` | Selected `AlertRegion` |
| `shared.region.followsLocation.v1` | GPS follow mode; vestigial since 3.0 — neither read nor written ([region model](../requirements/region-model.md)) |
| `shared.entitlement.v1` | Pro flag for extensions |
| `shared.secondaryRegion.v1` | Pro pinned second region; retired in 3.0 (ADR 0015) — never read, and removed from the App Group when the app opens its region store |
| `subscription.entitlement.v1` | Full entitlement blob (migrated from standard) |

## Alternatives

- Keep duplicated types in app + extension: rejected; Live Activity attributes already diverged once.
- App Group without package: rejected; extensions still need shared Codable models.

## Consequences

- Developer Portal must enable App Group for app and widget extension IDs before Archive.
- Entitlement and region data migrate from standard defaults on first launch after upgrade.
