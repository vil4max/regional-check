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

### REQ-SURF-001 — One wording per status key

Status: approved

Core: P2

Each status key shows one wording per locale on every surface (phone,
CarPlay, widgets, Live Activity, Siri / Shortcuts). Every String Catalog that
defines the key (app, widgets, DriveCheckKit) carries the same value for that
locale.

| Key | en | uk | ru |
|-----|----|----|----|
| `All Clear` | No Alert | Тривоги немає | Тревоги нет |
| `Alert Active` | Alert | Тривога | Тревога |

## Pro loss behavior

- Extended strings and secondary UI hide immediately.
- Secondary region **remains stored** in `shared.secondaryRegion.v1`.
- Alternate app icon reverts to primary via `AlternateIconManager`.

See ADR 0007.

## Requirements

Numbered requirements (RD-R, 2026-09-17). They restate the principles and matrix above without changing them; tests cite these IDs. Text approval: owner (gate G1).

### REQ-SURF-002 — No paywall on the safety signal

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P2

Given any user, with or without Pro\
When the current region is in alarm or clear, or the alert map is shown\
Then the signal and the map are available without Pro on every surface

### REQ-SURF-003 — Honest age on widgets

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P2

Given a widget or Live Activity shows aging data\
When the data ages\
Then it shows the timestamp and stale marker, and a known alarm stays visible

### REQ-SURF-004 — Pro loss

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P5

Given a Pro user loses the entitlement\
When the loss is detected\
Then extended strings and secondary UI hide immediately, the secondary region stays stored, and the app icon reverts to the primary icon

### Proposed amendment to REQ-SURF-001 — Full and short status forms

Status: proposed — owner rulings R3 and casing rule (2026-09-17); replaces REQ-SURF-001 when approved

Core: P2

Given a status key\
When it is shown on any surface\
Then iPhone and CarPlay titles use the full form ("Air Raid Alert") and pills, widgets, Live Activity, Dynamic Island and Control Center use the short form ("Alert"); each form is identical in every String Catalog and locale where it is used; a status word standing alone is Title Case and explaining sentences are sentence case

### REQ-SURF-005 — Nearby alerts in every status

Status: proposed — owner ruling R4 (2026-09-17)

Core: P1, P2

Given neighboring regions are under alert\
When the Status screen or CarPlay Status tab shows the current region, whether quiet or in alarm\
Then the nearby-alerts line is shown

### REQ-SURF-006 — CarPlay tabs stay free

Status: proposed — redesign 4.1 #4, R1, Q14 (2026-09-17)

Core: P2

Given a CarPlay session\
When the Details tab, or the Map tab once RD-3 confirms Variant B, is shown\
Then it is available without Pro

