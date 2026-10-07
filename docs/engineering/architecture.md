# Architecture

This document separates the architecture that exists today from the target architecture used for incremental refactoring. Product boundaries remain authoritative in [core.md](../core.md). The architectural decision is recorded in [ADR 0008](../decisions/0008-mvvm-service-boundaries.md).

See the [project map](project-map.md) for user access, screen navigation and component roles, and the [architecture diagrams](architecture-diagrams.md) for the system context, building blocks, state and runtime views.

## Current architecture

Drive Check is a feature-oriented SwiftUI application with an app target, widget extension, local `DriveCheckKit` package, and App Group persistence.

```text
Packages/DriveCheckKit/   Domain models, provider, SharedStore, intents
RegionalCheck/
  App/                    Lifecycle, composition, CarPlay, theme
  Views/                  Phone presentation and presentation controllers
  Data/                   Region, location, refresh and freshness policies
  Subscription/           StoreKit 2 and entitlement state
  LiveActivity/           Session lifecycle and ActivityKit integration
  AI/                     Status details summary providers
RegionalCheckWidgets/     Widgets, Live Activity UI, control
RegionalCheckTests/       Unit, scenario and snapshot tests
Tooling/                  Shared build, lint and test commands
```

`AppContainer` is the instance-based composition root owned by `AppDelegate`. `RegionalCheckApp` injects that instance into the SwiftUI environment. System-created CarPlay scenes receive a narrow dependency bundle from `AppDelegate` before UIKit creates their delegate. `StatusController` owns shared status state, refresh orchestration, polling, and freshness; persistence and WidgetKit reload are injected side-effect boundaries. Phone and CarPlay use the same shared status instance. Widgets, controls, and App Intents read the persisted App Group snapshot.

The preview and scenario graph in [`AppContainer.fixture`](../../RegionalCheck/App/AppContainerFixture.swift)
injects `FixtureLocationManager` through the container's `CarPlayLocationSource` boundary. It does not
construct a real `LocationManager`; location authorization and fixes are fixture inputs.

### Current data flow

```text
Ubilling JSON ──► AlertsSnapshot ──► StatusController
                         │                  │
GPS ──► RegionTracker ──► region            ├──► Phone / CarPlay
                                            │
                                            └──► SharedStore
                                                    │
                                                    └──► Widget / Control / Siri
```

One network fetch fills all regions. On each `getTimeline`, the status widget attempts a fetch through `WidgetTimelineRefresh`, saves a successful snapshot to `SharedStore`, and preserves the last-known-good snapshot on failure. Its timeline uses an `.after` policy for the next refresh. Interactive refresh is handled by `RefreshStatusIntent`.

### Current limitations

- [`HomeView`](../../RegionalCheck/Views/HomeView.swift) already forwards refresh actions to
  `HomeViewModel`, but it and [`DetailsTabView`](../../RegionalCheck/Views/DetailsView.swift) still
  resolve dependencies from the environment container and pass the concrete `StatusController`
  into presentation views. Details also reads the Home view model's source label and constructs
  its purchase-settings view model inside the view.
- Those view adapters open Settings through `UIApplication.shared`.
  [`RegionalCheckApp`](../../RegionalCheck/App/RegionalCheckApp.swift) still starts subscriptions
  and forwards scene changes directly to location and Live Activity services; foreground-session
  startup also occurs in [`MainTabViewModel`](../../RegionalCheck/Views/MainTabViewModel.swift).
- [`StatusController`](../../RegionalCheck/Views/StatusController.swift) still combines shared
  state, fetch orchestration, polling and power-state observation. Status resolution and
  persistence/reload boundaries have already been extracted.
- [`RegionSelection`](../../RegionalCheck/Data/RegionSelection.swift) and `StatusController`
  both retain and persist the current region. Phone and CarPlay adapters synchronize them, and
  Live Activity content synchronization is still spread across several callers. Follow-up goals
  are recorded in the [architecture backlog](../planning/backlog.md#architecture-audit-2026-10-07).

## Target architecture

Drive Check adopts MVVM at feature boundaries, protocol-backed services where substitution is required, and an instance-based composition root.

```text
RegionalCheckApp
    │
    ▼
AppContainer
    ├── application stores and sessions
    ├── platform services
    └── feature ViewModels
              │
              ▼
         SwiftUI Views
```

### Responsibilities

| Component | Responsibility |
|---|---|
| View | Layout, bindings, presentation, forwarding user actions |
| ViewModel | Feature presentation state, user actions, feature orchestration |
| Store / Session | Long-lived application state shared by multiple surfaces |
| Service | One external integration or side-effect boundary |
| AppContainer | Construct and connect live dependencies at the app boundary |

### Dependency rules

- Views do not resolve dependencies through global service locators.
- Views do not access persistence, networking, or platform singletons directly.
- ViewModels receive dependencies through initializers.
- Long-lived state shared by phone and CarPlay belongs to an application Store or Session, not a screen ViewModel.
- Protocols represent real substitution boundaries, not naming symmetry.
- `AppContainer` is a concrete composition root and does not need its own protocol.
- `DriveCheckKit` remains the shared home for types used by the app and extensions.
- Widgets and App Intents continue to communicate through persisted App Group state rather than a live in-process ViewModel.

## Migration sequence

1. **Ongoing:** keep the verification baseline green and add characterization tests before each
   behavioral refactor; see the [testing strategy](testing-strategy.md).
2. **Done:** replace static dependencies with the instance-based
   [`AppContainer`](../../RegionalCheck/App/AppContainer.swift), owned by
   [`AppDelegate`](../../RegionalCheck/App/AppDelegate.swift).
3. **Replaced by ADR 0015; current feature implemented:** the read-only region list uses
   [`RegionListViewModel`](../../RegionalCheck/Views/RegionListViewModel.swift) with injected
   `RegionStatusSource` and `CurrentRegionSource`. The previous selectable-region screen was
   retired; see [ADR 0015](../decisions/0015-two-tab-phone-ia.md).
4. **Done for MainTabView:** [`MainTabViewModel`](../../RegionalCheck/Views/MainTabViewModel.swift)
   owns its appear/disappear, onboarding, region/location and preference actions. App-level scene
   orchestration remains in `RegionalCheckApp`, as listed above.
5. **Partial:** [`StatusStateResolver`](../../RegionalCheck/Data/StatusStateResolver.swift),
   `StatusPersisting` in [`StatusController`](../../RegionalCheck/Views/StatusController.swift) and
   `WidgetReloading` in [`ServiceBoundaries`](../../RegionalCheck/App/ServiceBoundaries.swift) are in
   use. Extracting polling and power-state observation from `StatusController` remains open.
6. **Done:** [`AppDelegate`](../../RegionalCheck/App/AppDelegate.swift) supplies
   `CarPlayDependencies` from its container to the system-created CarPlay scene delegate.
7. **Open:** remove the remaining business-sensitive global dependencies and adapter-owned
   coordination incrementally, following the architecture backlog.

Each structural step preserves observable behavior, runs focused tests, and completes with `just verify` when the configured simulator runtime is available.

## SharedStore contract

- The app writes status snapshots, selected region and entitlement state. Status snapshots also
  have extension-side writers: [`WidgetTimelineRefresh`](../../Packages/DriveCheckKit/Sources/DriveCheckKit/WidgetTimelineRefresh.swift)
  persists successful timeline fetches, [`RefreshStatusIntent`](../../Packages/DriveCheckKit/Sources/DriveCheckKit/RefreshStatusIntent.swift)
  persists explicit refreshes, and [`CheckAlertStatusIntent.perform()`](../../Packages/DriveCheckKit/Sources/DriveCheckKit/CheckAlertStatusIntent.swift)
  calls [`AlertStatusAnswerBuilder.currentSnapshot`](../../Packages/DriveCheckKit/Sources/DriveCheckKit/AlertStatusAnswerBuilder.swift),
  which saves successful snapshots and rate-limit deadlines.
- Widgets, controls and App Intents read the App Group store; extension snapshot writes do not
  change the selected region or entitlement.
- Persisted data must be visible before WidgetKit timelines are reloaded.
- Widget timelines use `.after` polling: on `getTimeline` the widget attempts a fetch via `WidgetTimelineRefresh` (last-known-good preserved on failure); the app and refresh intent still request reloads after writes. Precomputed aging/expired entries render visual freshness transitions without spending reload budget. Full policy: `docs/requirements/refresh-policy.md`.
- A fresh widget snapshot includes future aging (`checkedAt + 180 seconds`) and expired (`checkedAt + 600 seconds`) entries that preserve the last-known status; rendering those entries requires no new fetch. WidgetKit controls the actual display time.
- Scheduled app refreshes skip widget reloads when the source timestamp, regional statuses, and source label are unchanged. Explicit refreshes still request a reload.
- Package localization uses `String(localized:bundle: .module)`.

## Architecture escalation

MVVM is the current level. Add a Coordinator only when navigation becomes a first-class problem such as deep links, independent tab stacks, or multi-step flows. Add Clean Architecture only when rich domain rules, multiple data sources, or strict module ownership justify the extra layers.

## Verification

```bash
just verify
```

This command is the technical Definition of Done. A diff review for introduced defects is a separate step before a behavioral commit.
