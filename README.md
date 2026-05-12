# KievAlert (public demo)

`KievAlert` is a **pet project / public demo** iOS app (SwiftUI).

Its long-term goal is **CarPlay support** to help drivers quickly understand the **air-raid alert status** without digging into the phone — a simple, glanceable “ALARM / QUIET” experience on the car screen.

This repository is also used as a sandbox for trying out **new approaches and features**.

Currently the app shows the alert status for the **selected region** (auto-detected via location) and a **Map** tab with region status markers.

## Future work

- Use Apple Maps on CarPlay to show the driver’s position and highlight (fill) the current region based on the alert status.

## Data source

- Data source: `ubilling.net.ua/aerialalerts/` (public JSON proxy).
- Disclaimer: this is a demo project. Availability/accuracy is not guaranteed. This is not an official source.

## Architecture

Clean-ish layering (kept intentionally small):

- **Domain (SPM)**: `Modules/KievAlertDomain`
  - models: `AlertRegion`, `AlertStatus`, `AlertStatusSnapshot`
  - protocol: `AirAlertProviding`
- **Data (SPM)**: `Modules/KievAlertData`
  - `UbillingAirAlertProvider: AirAlertProviding`
  - `HTTPClient` abstraction (`URLSession` conforms)
  - ubilling DTOs / decoding
- **Status UI (SPM)**: `Modules/KievAlertStatus`
  - `KievAlertStatusView` + `KievAlertViewModel`
  - use cases: `FetchAlertStatusUseCase`, `RegionTitleUseCase`
- **Map UI (SPM)**: `Modules/KievAlertMap`
  - `UkraineMapView` + `UkraineMapViewModel`
  - use case: `FetchAllRegionStatusesUseCase`
- **App (Xcode target / composition root)**: `KievAlert/`
  - composes modules in `AppCoordinator`

**Owner note (2026-05):** keep evolving this sandbox toward **Clean Architecture** at the **app / module** level (clear domain vs adapters, dependency rule inward) and try **Clean Swift (VIP)** on **heavy screens** (View, Interactor, Presenter, Entity, Router) when a single `*ViewModel` would get too large—VIP is per-scene structure; “full” Clean is about layers across the whole app, not the same thing.

## Localization

- Uses **String Catalogs**: `KievAlert/Resources/Localizable.xcstrings`
- Languages: **EN / RU / UK**

## Technologies

- **Swift / SwiftUI**
- **Swift Concurrency** (`async/await`, `Task`)
- **SPM (Swift Package Manager)**: local packages for Domain/Data modules
- **Networking**: `URLSession` + JSON decoding (`Decodable`)
- **MapKit**: interactive map + custom annotations for region statuses
- **CoreLocation**: user location + reverse geocoding for auto region selection
- **Localization**: `.xcstrings` (String Catalog)
- **Testing**: Swift Testing framework (`import Testing`)
- **CarPlay**: `CPTemplateApplicationSceneDelegate` (best-effort demo)

## CarPlay

The project includes a CarPlay scene delegate (best-effort demo in code). With a **Personal Team**, the app may not appear in CarPlay “Customize” due to Apple’s CarPlay entitlement/capability requirements.

## Run

- Open `KievAlert.xcodeproj`
- Select the `KievAlert` scheme
- Build & Run on a simulator

## Tests

- Domain/Data/UI modules are tested in the SPM modules and the Xcode unit test target (`KievAlertTests`).

