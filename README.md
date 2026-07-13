# Regional Check

Minimal Apple-style CarPlay utility that shows the current regional public-notice state for the driver’s location. Calm, one screen, one region, one refresh action. iPhone mirrors the same experience as a companion. It is not an emergency, monitoring, or notification product and does not promise safety.

## Stack

iOS 26+ · Xcode · Swift · SwiftUI · CarPlay (Driving Task) · CoreLocation · MapKit · URLSession · String Catalogs (en/ru/uk) · Swift Testing

## Layout (MVC)

```
RegionalCheck/
  App/       entry, CarPlay, Theme
  Views/     HomeView, StatusView, StatusController
  Data/      models, Ubilling, location, region, store
  Resources/
```

## Run

Open `RegionalCheck.xcodeproj`, scheme `RegionalCheck`.

Smoke tests: `./scripts/smoke-tests.sh`
