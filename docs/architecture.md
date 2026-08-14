# Architecture

See `docs/product-charter.md`.

MVC · app + widget extension · local SPM `DriveCheckKit` · App Group shared store.

```
Packages/DriveCheckKit/   AlertRegion, AlertsSnapshot, UbillingProvider, SharedStore, intents
RegionalCheck/
  App/           lifecycle, CarPlay, Theme, MainTabView, WidgetReloader
  Views/         HomeView, RegionsView, StatusView, StatusController, paywall
  Data/          RegionStore, RegionSelection, RegionTracker, LocationManager
  Subscription/  StoreKit 2, EntitlementCache (App Group suite)
  LiveActivity/  session controller (attributes in DriveCheckKit)
  Resources/     entitlements, privacy manifest
RegionalCheckWidgets/
  Live Activity, status widget, secondary widget, control, App Intents provider
Tooling/
  ios-engineering-runtime Runtime (just API, doctor, verify)
```

Shared dependencies live in `RegionalCheckApp.swift` (`AppDependencies`) for phone + CarPlay.

## Data flow

```text
Ubilling JSON ──► AlertsSnapshot ──► SharedStore.shared.snapshot
                         │                      │
GPS ──► RegionTracker ──► region ──────────────┤
                         │                      │
                    StatusController ◄───────────┘
                         │
              Widget / Control / Siri (read SharedStore only)
```

One network fetch fills all regions. Extensions never poll on timeline; interactive refresh uses `RefreshStatusIntent`.

## SharedStore contract

- **Writer:** app (`StatusController`, `RegionStore`, `SubscriptionManager`)
- **Readers:** widgets, control, App Intents
- **After write:** `WidgetReloader.reloadAllTimelines()`
- **Localization in package:** always `String(localized:bundle: .module)`

## Docs map

| Topic | Doc |
|-------|-----|
| Shared module + App Group | this file + ADR 0006 |
| Surfaces + Pro gating | `docs/surfaces.md` + ADR 0007 |
| Region catalog, resolver | `docs/region-model.md` + ADR 0002 / 0003 / 0005 |
| Ubilling limits | `docs/aerial-alerts-provider.md` |
| Refresh policy | `docs/refresh-policy.md` |
| StoreKit / Pro | `docs/storekit-subscription-plan.md`, `README_Subscriptions.md` |
| Agent pilot | `docs/agent-pilot-brief.md`, root `AGENTS.md` |

Smoke: `./scripts/smoke-tests.sh`
