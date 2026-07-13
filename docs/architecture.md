# Architecture

See `docs/product-charter.md`.

## Identity

Regional Check · `vil4max.RegionalCheck` · modules `RegionalCheckDomain` / `RegionalCheckData` / `RegionalCheckStatus`

## Layers

- Domain: `AlertRegion`, `AlertStatus`, `AlertStatusSnapshot`, `AirAlertProviding`
- Data: `HTTPClient`, `UbillingAirAlertProvider`
- Status: use cases, `RegionalCheckViewModel`, `RegionalCheckStatusView`, `Theme`
- App: CarPlay primary, iPhone companion (`ContentView` + Refresh), GPS region selection

## Data flow

GPS → Region → provider → snapshot → Normal / Attention / Checking / Unable to update

## Run

Open `RegionalCheck.xcodeproj`, scheme `RegionalCheck`.
