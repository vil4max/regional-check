# Project map

Implementation map for the 3.0 release candidate, inspected on 2026-10-06.
This describes code present in the repository, not release acceptance or a new
product decision. Product rules remain in [core](../core.md) and
[surface requirements](../requirements/surfaces-and-pro-gating.md).

The three diagrams separate user access, navigation, and component ownership
so screen transitions cannot be mistaken for network calls. Mermaid source is
kept here and renders on GitHub; no exported image is required to maintain it.

## Users and surfaces

Pro is hidden under [ADR 0014](../decisions/0014-hide-pro-for-3-0.md);
functional access does not depend on the stored entitlement.
There are no accounts, authentication, or administrator screens. The driver
uses CarPlay; the phone is the companion and configuration surface.

```mermaid
flowchart LR
    User[Driver / phone user] --> Free[Free access]
    Free --> Phone[Phone: Status with the alert map and region list, Details]
    Free --> CP[CarPlay: Status with Refresh]
    Free --> Widget[Current-region status widget]
    Free --> Siri[Siri / Shortcuts: current status]
    Free --> Control[Control Center / Lock Screen: open app]
    Free --> Detail[Extended detail and source labels]
    Free --> Refresh[Widget refresh button when non-idle]
    Free --> Activity[Alert Live Activity / Dynamic Island]
```

The current-region alarm/clear signal and phone alert map stay free. Pro decoration
is hidden and the app uses its primary icon. Live Activities require the user's
Live Activity preference and system permission; a new activity starts for an
alarm while the phone or CarPlay session is active.

## Screens and navigation

Arrows below indicate entry or navigation, not strict timing. Cold-start overlay
and first-launch onboarding are separate root presentation mechanisms.
Status details are embedded content, not an additional phone screen.

```mermaid
flowchart TD
    Launch[App launch] --> Root[ColdStartRootView / MainTabView]
    Root -. temporary overlay .-> Cold[Neutral mark / cold-start transition]
    Root --> First{Onboarding completed?}
    First -->|No| Onboarding[Onboarding]
    Onboarding -->|Get Started| Tabs[Main tabs]
    First -->|Yes| Tabs
    Tabs --> Status[Status / Home]
    Status --> Summary[Embedded summary and status details]
    Status --> Map[Inline alert map, loaded once per session]
    Tabs --> Details[Details: summary, Live Activity, restore / manage subscription, data source]
    Map -->|tap anywhere on the map| RegionList[Region list: read-only, pushed inside the Status tab]
    Root -. after onboarding, when applicable .-> Outside[Outside Ukraine sheet]
    Connect[CarPlay connection] --> CPStatus[Single Status template + Refresh]
```

| Surface or screen | Implementation entry point |
|---|---|
| Launch and root | [ColdStartRootView](../../RegionalCheck/Views/ColdStart/ColdStartRootView.swift), [MainTabView](../../RegionalCheck/Views/MainTabView.swift) |
| Status and summary | [HomeView](../../RegionalCheck/Views/HomeView.swift), [StatusView](../../RegionalCheck/Views/StatusView.swift), [StatusSummaryCard](../../RegionalCheck/Views/StatusSummaryCard.swift) |
| Region list (read-only, pushed from the map) | [RegionListView](../../RegionalCheck/Views/RegionListView.swift) |
| Inline alert map | [AlertMapCard](../../RegionalCheck/Views/MapCardView.swift) |
| Onboarding and location notice | [OnboardingView](../../RegionalCheck/Views/OnboardingView.swift), [OutsideUkraineInfoSheet](../../RegionalCheck/Views/OutsideUkraineInfoSheet.swift) |
| Details (summary, settings, restore / manage subscription) | [DetailsView](../../RegionalCheck/Views/DetailsView.swift) |
| CarPlay Status template | [CarPlaySceneDelegate](../../RegionalCheck/App/CarPlaySceneDelegate.swift), [CarPlayTemplateBuilder](../../RegionalCheck/App/CarPlayTemplateBuilder.swift) (`CPInformationTemplate`) |
| Widgets, control and Live Activity UI | [RegionalCheckWidgets](../../RegionalCheckWidgets/) |
| Siri and refresh intents | [DriveCheckKit](../../Packages/DriveCheckKit/Sources/DriveCheckKit/) |

Loading, quiet, alarm, stale, error and missing-region presentations are states
of these surfaces, not separate routes. DEBUG screenshot routes and explanation
trace sheets are development tools and are excluded from the user map.

## Component roles and data flow

Arrows show construction or information flow as labelled. App Group storage is
the cross-process boundary; extensions do not share the app's live controller.

```mermaid
flowchart LR
    App[AppDelegate / RegionalCheckApp] -->|construct and inject| Container[AppContainer]
    Container --> State[StatusController]
    Container --> VMs[Home / RegionList / MainTab ViewModels]
    Container --> Sub[SubscriptionManager]
    GPS[Location service] --> Region[RegionSelection / region tracking]
    Region --> State
    JSON[Ubilling JSON] --> Provider[UbillingProvider]
    Provider -->|snapshot| State
    State --> VMs
    VMs --> Phone[Phone views]
    State --> CP[CarPlay coordinator and builders]
    State -->|persist| Store[SharedStore / App Group]
    Region -->|selection| Store
    Apple[StoreKit] --> Sub
    Sub -->|entitlement cache| Store
    Sub -->|feature gates| Phone
    State --> Details[StatusDetailsViewModel]
    Details --> Summary[Foundation Models summarizer / deterministic fallback]
    Summary -->|presentation text| Phone
    Details --> CP
    Raster[Ubilling raster] --> Maps[Phone MapViewModel]
    Maps --> Phone
    Store --> Extensions[Widgets / control / Siri intents]
    Provider -->|widget reload or refresh intent| Store
    State --> Session[LiveActivityController]
    Sub -->|Live Activity preference| Session
    Permission[System Live Activity permission] --> Session
    Session --> Activity[ActivityKit / Live Activity UI]
```

| Role | Responsibility and boundary |
|---|---|
| AppContainer | Constructs live dependencies; owns shared instances and injects services. |
| StatusController | Shared status, refresh orchestration, freshness and reference-counted polling for app surfaces. |
| Feature ViewModels | Presentation state and user actions; views render and forward actions. |
| RegionSelection and location services | The one current region, resolved from location. |
| UbillingProvider / MapViewModel | JSON snapshot fetching / on-demand raster fetching for the phone's inline alert map; CarPlay has no map. |
| SharedStore | Persisted snapshot, selection and entitlement data used across processes. Widget reload and refresh intent paths can fetch and save snapshots. |
| StatusDetailsViewModel and summarizers | Derived explanatory text with deterministic fallback; do not replace the alert provider or authoritative status. |
| SubscriptionManager | StoreKit entitlement and feature gates, not a user account system. |
| LiveActivityController | Session lifecycle and content updates; widget extension renders the activity. |
| Runtime and tests | Build, lint and verification tooling; not shipped product screens or runtime services. |

## Known documentation boundaries

- [ADR 0014](../decisions/0014-hide-pro-for-3-0.md) records the suspended Pro
  surface. Entitlement storage and subscription management remain implemented.
- [Architecture](architecture.md) separates current behavior from its target
  migration. Widget timeline reloads attempt a fetch through `WidgetTimelineRefresh`
  and preserve the last-known-good snapshot on failure.
- Release verification and device acceptance are tracked in the release notes
  ([operations/releases](../operations/releases/)), not inferred from the presence
  of a screen in this map.

Update this document when routes, entitlement gates, platform surfaces or
cross-process ownership change. Keep implementation links current and resolve
contract changes in requirements/ADRs before presenting them here as approved.
