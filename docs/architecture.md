# Architecture

This document separates the architecture that exists today from the target architecture used for incremental refactoring. Product boundaries remain authoritative in [product-charter.md](product-charter.md). The architectural decision is recorded in [ADR 0008](adr/0008-mvvm-service-boundaries.md).

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
RegionalCheckWidgets/     Widgets, Live Activity UI, control
RegionalCheckTests/       Swift Testing unit and smoke tests
Tooling/                  Deterministic Runtime commands
```

`AppContainer` is the instance-based composition root owned by `AppDelegate`. `RegionalCheckApp` injects that instance into the SwiftUI environment. System-created CarPlay scenes receive a narrow dependency bundle from `AppDelegate` before UIKit creates their delegate. `StatusController` owns shared status state, refresh orchestration, polling, and freshness; persistence and WidgetKit reload are injected side-effect boundaries. Phone and CarPlay use the same shared status instance. Widgets, controls, and App Intents read the persisted App Group snapshot.

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

One network fetch fills all regions. Extensions do not poll from their timelines. Interactive refresh is handled by `RefreshStatusIntent`.

### Current limitations

- `HomeView` still resolves multiple concrete services from the injected container instead of a feature ViewModel.
- Some remaining views and application services access platform singletons directly.
- `StatusController` still combines status fetching, shared state, and polling lifecycle.
- Previews and feature tests cannot assemble a complete isolated dependency graph.

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

1. Establish a green verification baseline and add characterization tests where needed.
2. Replace static `AppDependencies` with an instance-based `AppContainer` without changing behavior.
3. Introduce `RegionsViewModel` as the reference MVVM feature.
4. Move application lifecycle orchestration out of `MainTabView` into `MainTabViewModel`.
5. Separate status resolution and side-effect boundaries from `StatusController`; move polling in a later protected step.
6. Inject CarPlay dependencies from the `AppDelegate`-owned composition root.
7. Remove remaining business-sensitive global dependencies incrementally.

Each structural step preserves observable behavior, runs focused tests, and completes with `just verify` when the configured simulator runtime is available.

## SharedStore contract

- The app is the authoritative writer for status, selected region, and entitlement state.
- Widgets, controls, and App Intents read the App Group store.
- Persisted data must be visible before WidgetKit timelines are reloaded.
- Package localization uses `String(localized:bundle: .module)`.

## Architecture escalation

MVVM is the current level. Add a Coordinator only when navigation becomes a first-class problem such as deep links, independent tab stacks, or multi-step flows. Add Clean Architecture only when rich domain rules, multiple data sources, or strict module ownership justify the extra layers.

## Verification

```bash
just verify
```

The Runtime command is the technical Definition of Done. Defect-first review remains a separate gate before a behavioral commit.
