# Migration plan

## Done — Simplify

Removed Map, tabs; calm UI; Theme tokens; domain model names kept.

## Done — Identity

| Old | New |
| --- | --- |
| Product | Regional Check |
| Repository | `regional-check` |
| Bundle ID | `vil4max.RegionalCheck` |
| Project / targets | `RegionalCheck` |
| Modules | `RegionalCheckDomain`, `RegionalCheckData`, `RegionalCheckStatus` |

Kept: `AlertStatus`, `AlertRegion`, `AirAlertProviding`, Ubilling provider types.

## Next — Apple Release

Assets, App Store metadata, entitlement request, TestFlight, Archive, Review.
