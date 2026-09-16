# Surfaces and Pro gating

Drive Check 2.0 exposes the same underlying `AlertsSnapshot` across phone, CarPlay, widgets, controls, Siri, and session Live Activity. **Current-region status is free everywhere.** Pro adds detail, extra surfaces, and a pinned second region.

## Matrix

| Surface | Data source | Free | Pro |
|---------|-------------|------|-----|
| Phone Home screen | Live fetch + `StatusController` | State, region, time | Badge, source label, secondary region line |
| Phone Home screen (map card) | Upstream raster on demand | Image, fetch time, VoiceOver label | Same (not paywalled) |
| Phone Regions tab | Same snapshot | All regions, manual pin | Pin secondary region (context menu) |
| CarPlay template | `StatusController` | Title, region, explanation, refresh | Source line (length-limited) |
| Live Activity | Push from app session | Phase, region, time | Source label, stale marker |
| Status widget | `SharedStore` | Phase, region, stale | Source + refresh button |
| Secondary widget | `SharedStore` | Hidden (paywall copy) | Configured second region |
| Control Center / Lock Screen control | `SharedStore` | Open app + region label | Same (not paywalled) |
| Siri / Shortcuts | `SharedStore` | Region + status dialog | Source + checked time in dialog |

## Principles

1. **No paywall on safety signal** — alarm vs clear for the active region is never locked.
2. **One fetch, shared store** — widgets and app share snapshots in `SharedStore`. Widgets perform best-effort background polling on reload via `WidgetTimelineRefresh`.
3. **Honest age & safety priority** — widgets show explicit timestamp and `⚠` stale markers when data ages; known alarms stay prominently visible and never downgrade to "no connection" screens.
4. **Secondary region is attention, not data** — pinning a second oblast does not add network cost; it surfaces an existing snapshot row.

## Status wording

- **REQ-SURF-001** — Each status key shows one wording per locale on every
  surface (phone, CarPlay, widgets, Live Activity, Siri / Shortcuts). Every
  String Catalog that defines the key (app, widgets, DriveCheckKit) carries the
  same value for that locale.

| Key | en | uk | ru |
|-----|----|----|----|
| `All Clear` | No Alert | Тривоги немає | Тревоги нет |
| `Alert Active` | Alert | Тривога | Тревога |

## Pro loss behavior

- Extended strings and secondary UI hide immediately.
- Secondary region **remains stored** in `shared.secondaryRegion.v1`.
- Alternate app icon reverts to primary via `AlternateIconManager`.

See ADR 0007.
