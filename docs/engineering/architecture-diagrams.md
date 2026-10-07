# Architecture diagrams

DriveCheckUA in five Mermaid diagrams: where the app sits, how the code is split, which states a region's status can be in, how a refresh travels, and how the Live Activity lives. Diagram names follow the C4 model and the arc42 views. Each diagram was checked against the source files named under it. The architecture text is in [architecture.md](architecture.md); product rules stay in [core.md](../core.md) and [requirements/](../requirements/); where a diagram and a document disagree, the code is what is drawn.

## 1. System context diagram

Who and what the app talks to. The only network source is the Ubilling alerts service, called by the app and by the widget and Siri paths separately; every other surface reads what the app (or the widget) saved to the App Group.

```mermaid
flowchart LR
    Driver["Driver"]

    subgraph AppProc["App process"]
        App["Phone screens: Status, Details, region list"]
        CarPlay["CarPlay: one Status screen"]
        Core["Status controller and region tracking"]
    end

    subgraph Ext["Widget extension and Siri"]
        Widget["Status widget"]
        Control["Control Center and Lock Screen control"]
        Live["Live Activity and Dynamic Island"]
        Siri["Siri and Shortcuts: check status"]
    end

    Store[("App Group shared store")]
    Ubilling["Ubilling alerts service: JSON and map image"]
    FM["Apple Foundation Models"]
    Loc["Core Location and MapKit geocoding"]

    Driver --> App
    Driver --> CarPlay
    Driver --> Ext

    App --> Core
    CarPlay --> Core
    Loc -->|"region from location"| Core
    Core -->|"fetch alerts, load map image"| Ubilling
    Core -->|"save snapshot and region"| Store
    Core -->|"start, update, end"| Live
    Core -->|"Status details text"| FM
    Live -->|"Refresh button runs in the app"| Core

    Widget -->|"fetch on timeline reload"| Ubilling
    Siri -->|"one fetch within 4 s"| Ubilling
    Widget <-->|"read, save"| Store
    Control -->|"read"| Store
    Siri <-->|"read, save"| Store
```

Checked against: `RegionalCheck/App/AppDelegate.swift`, `RegionalCheck/App/CarPlaySceneDelegate.swift`, `RegionalCheck/Resources/RegionalCheck.entitlements`, `RegionalCheck/AI/StatusDetailsProvider.swift`, `RegionalCheck/Data/ReverseGeocoding.swift`, `RegionalCheckWidgets/DriveCheckLiveActivity.swift` (bundle), `RegionalCheckWidgets/DriveCheckStatusControl.swift`, `RegionalCheckWidgets/DriveCheckShortcuts.swift`, `Packages/DriveCheckKit/Sources/DriveCheckKit/UbillingProvider.swift`, `.../SharedStore.swift`, `.../AlertStatusAnswerBuilder.swift`, `.../RefreshLiveActivityIntent.swift`.

## 2. Building block view

The three build targets and the layers inside the app. Arrows point from a caller to what it uses. The widget extension is embedded in the app and never shares its live objects; they meet only through the App Group store.

```mermaid
flowchart TB
    subgraph AppTarget["App target: RegionalCheck"]
        Comp["AppDelegate, RegionalCheckApp, AppContainer"]

        subgraph ViewsL["Views"]
            Views["Cold start, Onboarding, Status, Details, Region list, Map card, Paywall"]
        end

        subgraph VMsL["View models"]
            VMs["MainTab, Home, Details, RegionList, Map, StatusDetails, Paywall"]
        end

        subgraph CtrlL["Controllers"]
            SC["StatusController: state, polling, freshness"]
            LAC["LiveActivityController"]
            CPG["CarPlay: scene delegate, refresh coordinator, template builder"]
        end

        subgraph SvcL["Services"]
            Reg["LocationManager, RegionTracker, RegionSelection"]
            Sub["SubscriptionManager on StoreKit 2"]
            Sum["Status details summarizers: Foundation Models with fallback"]
            Rel["WidgetReloader"]
        end
    end

    subgraph ExtTarget["Widget extension: RegionalCheckWidgets"]
        Wdg["Status widget, Status control, Live Activity UI, Shortcuts provider"]
    end

    subgraph KitPkg["Swift package: DriveCheckKit"]
        Dom["Domain: AlertRegion, AlertsSnapshot, NearbyRegionPolicy"]
        Prov["UbillingProvider and retry policy"]
        Shared[("SharedStore")]
        WTL["WidgetTimelineBuilder and WidgetTimelineRefresh"]
        Intents["App Intents: check status, refresh, refresh Live Activity"]
    end

    Tests["RegionalCheckTests"]

    Comp --> Views
    Comp --> CPG
    Views --> VMs
    VMs --> SC
    VMs --> Sub
    VMs --> Sum
    CPG --> SC
    CPG --> LAC
    SC --> Prov
    SC --> Shared
    SC --> Rel
    Reg --> SC
    LAC --> Dom
    Wdg --> WTL
    Wdg --> Intents
    WTL --> Prov
    WTL --> Shared
    Intents --> Prov
    Intents --> Shared
    Prov --> Dom
    AppTarget -.->|"embeds"| ExtTarget
    AppTarget --> KitPkg
    ExtTarget --> KitPkg
    Tests -.->|"hosted in the app"| AppTarget
```

Checked against: `RegionalCheck.xcodeproj/project.xcproj` (targets and package membership), `RegionalCheck/App/AppContainer.swift`, `RegionalCheck/Views/StatusController.swift`, `RegionalCheck/Views/MainTabViewModel.swift`, `RegionalCheck/Views/HomeViewModel.swift`, `RegionalCheck/LiveActivity/LiveActivityController.swift`, `RegionalCheck/App/WidgetReloader.swift`, `RegionalCheck/Subscription/SubscriptionManager.swift`, `RegionalCheck/AI/FallbackStatusDetailsProvider.swift`, `Packages/DriveCheckKit/Package.swift` and its `Sources/`.

## 3. State diagram: alert status of a region

What the Status screen, CarPlay and the widget can show for the current region. The phase (Checking, No Alert or Stay Alert, Alert, Unavailable, Region Unavailable) comes from `StatusState`; old data and Stay Alert are not phases but colour rules layered on a quiet phase.

```mermaid
stateDiagram-v2
    [*] --> Checking : no saved snapshot
    [*] --> Quiet : saved snapshot, region quiet
    [*] --> Alarm : saved snapshot, region in alarm

    state "No data yet" as NoData {
        Checking --> Unavailable : fetch failed, no snapshot
    }

    NoData --> Quiet : fetch ok, region quiet
    NoData --> Alarm : fetch ok, region in alarm
    NoData --> RegionMissing : fetch ok, region not in snapshot

    Quiet --> Alarm : fetch ok, region in alarm
    Alarm --> Quiet : fetch ok, region quiet
    Quiet --> RegionMissing : region not in snapshot
    Alarm --> RegionMissing : region not in snapshot
    RegionMissing --> Quiet : region back, quiet
    RegionMissing --> Alarm : region back, in alarm

    state "Checking" as Checking
    state "Unavailable" as Unavailable
    state "Region Unavailable" as RegionMissing
    state "Alert" as Alarm

    state Quiet {
        [*] --> NoAlert
        NoAlert --> StayAlert : fresh and half of neighbours in alarm
        StayAlert --> NoAlert : neighbours calm down
        NoAlert --> OldData : request failed or age over 2 x interval
        StayAlert --> OldData : request failed or age over 2 x interval
        OldData --> NoAlert : fresh fetch
        state "No Alert (green)" as NoAlert
        state "Stay Alert (yellow)" as StayAlert
        state "Old data (grey)" as OldData
    }

    note right of Alarm
        Old data or a failed request keeps Alert red.
        Only the meta line says it is old.
    end note
    note right of NoData
        Unavailable only without any saved snapshot.
        A failed fetch never replaces a saved phase.
    end note
```

Checked against: `RegionalCheck/Views/StatusState.swift`, `RegionalCheck/Data/StatusStateResolver.swift`, `RegionalCheck/Views/StatusController.swift` (`applySnapshotToState`, `refresh`, `isDataStale`), `RegionalCheck/Data/DataFreshness.swift`, `RegionalCheck/App/Theme+Redesign.swift` (`RedesignStatusAccent`), `Packages/DriveCheckKit/Sources/DriveCheckKit/NearbyRegionPolicy.swift`, `.../WidgetTimelineBuilder.swift` (`isCaution`), `RegionalCheck/App/CarPlayLoadState.swift`. "Half of neighbours" is simplified: the full rule (Kyiv city exception, more than half of the country) is in `NearbyRegionPolicy.isSurrounded`.

## 4. Runtime view: refresh

From a trigger to the surfaces. Phone and CarPlay share one `StatusController`; the widget extension and Siri run their own fetch and meet the app only in the shared store.

```mermaid
sequenceDiagram
    participant Trig as Phone triggers
    participant CPS as CarPlay scene
    participant CC as CarPlay refresh coordinator
    participant SC as StatusController
    participant UP as UbillingProvider
    participant API as Ubilling service
    participant SS as SharedStore
    participant LA as Live Activity controller
    participant UI as Phone views and CarPlay screen
    participant WK as WidgetKit
    participant WX as Widget extension

    Trig->>SC: refresh on app open, pull to refresh, timer
    Note over Trig,SC: timer base 60 s, 30 s in alarm, 300 s when constrained, plus or minus 10 percent
    CPS->>CC: connect or Refresh button
    CC->>SC: refresh, up to 3 attempts with 2 s then 4 s backoff

    SC->>SC: skip if last success under 10 s ago, or a scheduled poll inside a 429 window, or join the request in flight
    SC->>UP: fetchAlerts
    UP->>API: GET alerts JSON
    opt transient URLError
        UP->>UP: wait 2 s
        UP->>API: GET once more
    end

    alt HTTP 429
        API-->>UP: 429 with Retry-After
        UP-->>SC: rate limited until deadline
        SC->>SC: pause scheduled polls, keep saved snapshot
    else success
        API-->>UP: alerts JSON
        UP-->>SC: AlertsSnapshot
        SC->>SS: save snapshot
        SC->>WK: reload timelines and control, skipped for an unchanged scheduled poll
        SC->>SC: resolve status, clear failure flag
        SC-->>UI: observed state change re-renders
        UI->>LA: sync Live Activity content
    else other failure
        UP-->>SC: error
        SC->>SC: mark refresh failed, state Unavailable only if no snapshot
        SC-->>UI: shows old data
    end

    Note over WK,WX: Widget path, independent of the app
    WK->>WX: getTimeline
    WX->>UP: fetch with its own provider
    UP->>API: GET alerts JSON
    WX->>SS: save snapshot, keep last good one on failure
    WX-->>WK: timeline with aging at 3 min, expired at 10 min, next poll 120, 180 or 300 s
    Note over WX,SS: Siri check does one fetch within 4 s, else reads the saved snapshot
```

Checked against: `RegionalCheck/Views/StatusController.swift` (`refresh`, `isFetchHeld`, `applyFetched`, periodic loop), `RegionalCheck/Data/RefreshPolicy.swift`, `RegionalCheck/Views/HomeView.swift`, `RegionalCheck/Views/HomeViewModel.swift`, `RegionalCheck/Views/MainTabViewModel.swift`, `RegionalCheck/Views/MainTabView.swift`, `RegionalCheck/App/CarPlayRefreshCoordinator.swift`, `RegionalCheck/App/CarPlaySceneDelegate.swift`, `Packages/DriveCheckKit/Sources/DriveCheckKit/UbillingProvider.swift`, `.../RetryAfterParser.swift`, `.../WidgetTimelineBuilder.swift`, `.../WidgetTimelineRefresh.swift`, `.../AlertStatusAnswerBuilder.swift`, `RegionalCheckWidgets/DriveCheckStatusWidget.swift`.

## 5. State diagram: Live Activity lifecycle

When the activity starts, updates and ends. It is started from a foreground session (phone or CarPlay) on an alert, and after that only a confirmed all-clear, or turning the activity off, ends it; leaving the app does not.

```mermaid
stateDiagram-v2
    [*] --> NoActivity

    NoActivity --> Active : alert, session open, activity allowed
    Active --> Active : update on each status change
    Active --> OldMarked : iOS stale date, 15 min after last check
    OldMarked --> Active : update from the app
    Active --> Ended : confirmed all-clear
    OldMarked --> Ended : confirmed all-clear
    Active --> Ended : switch turned off or system disallows
    OldMarked --> Ended : switch turned off or system disallows
    Ended --> NoActivity

    NoActivity --> Active : new process adopts a surviving activity while alert
    NoActivity --> Ended : new process ends a surviving activity after all-clear

    state "Active (alert shown)" as Active
    state "Marked old by iOS" as OldMarked

    note right of Active
        Leaving the app or disconnecting CarPlay
        does not end it. Unknown or failed status
        only updates it and marks it old.
    end note
```

Checked against: `RegionalCheck/LiveActivity/LiveActivityLifecyclePolicy.swift`, `RegionalCheck/LiveActivity/LiveActivityController.swift`, `RegionalCheck/LiveActivity/LiveActivityStaleDate.swift`, `RegionalCheck/LiveActivity/LiveActivityRefresher.swift`, `RegionalCheck/LiveActivity/LiveActivityPreferenceStore.swift`, `RegionalCheck/LiveActivity/LiveActivityPermission.swift`, `RegionalCheck/App/RegionalCheckApp.swift`, `RegionalCheck/App/CarPlaySceneDelegate.swift`.
