# Surfaces and Pro gating

Drive Check 2.0 exposes the same underlying `AlertsSnapshot` across phone, CarPlay, widgets, controls, Siri, and session Live Activity. **Current-region status is free everywhere.** Pro adds detail, extra surfaces, and a pinned second region.

## Matrix

| Surface | Data source | Free | Pro |
|---------|-------------|------|-----|
| Phone Home screen | Live fetch + `StatusController` | State, region, time | Badge, source label, secondary region line |
| Phone Home screen (Alert map row, full-screen map) | Upstream raster on demand | Image, fetch time, VoiceOver label | Same (not paywalled) |
| Phone Regions tab | Same snapshot | All regions, manual pin | Pin secondary region (context menu) |
| CarPlay Status tab | `StatusController` | Title, region, explanation, refresh | Source line (length-limited) |
| CarPlay Details tab | `StatusController` | Region, country and data rows | Source line |
| CarPlay Map tab (after RD-3) | Upstream raster on demand + snapshot text | Image, image age, regions under alert | Same (not paywalled) |
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

### REQ-SURF-001 — Full and short status forms, one wording each

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given a status key\
When it is shown on any surface\
Then iPhone and CarPlay titles use the full form ("Air Raid Alert") and pills, widgets, Live Activity, Dynamic Island and Control Center use the short form ("Alert"); each form is identical in every String Catalog and locale where it is used; a status word standing alone is Title Case and explaining sentences are sentence case

The table below lists the current short forms; RD-11 adds the full forms.

| Key | en | uk | ru |
|-----|----|----|----|
| `All Clear` | No Alert | Тривоги немає | Тревоги нет |
| `Alert Active` | Alert | Тривога | Тревога |

## Pro loss behavior

Suspended while REQ-SURF-007 is in force: nothing in 3.x is Pro-gated, so a lost entitlement
hides nothing. The rules below are what Pro returns to (ADR 0007, ADR 0014).

- Extended strings and secondary UI hide immediately.
- Secondary region **remains stored** in `shared.secondaryRegion.v1`.
- Alternate app icon reverts to primary via `AlternateIconManager`.

See ADR 0007.

## Requirements

Numbered requirements (RD-R, 2026-09-17). They restate the principles and matrix above without changing them; tests cite these IDs. Text approved by the owner on 2026-09-17 (gate G1).

### REQ-SURF-002 — No paywall on the safety signal

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given any user, with or without Pro\
When the current region is in alarm or clear, or the alert map is shown\
Then the signal and the map are available without Pro on every surface

### REQ-SURF-003 — Honest age on widgets

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given a widget or Live Activity shows aging data\
When the data ages\
Then it shows the timestamp and stale marker, and a known alarm stays visible

### REQ-SURF-004 — Pro loss

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval); suspended while REQ-SURF-007 is in force (owner, 2026-09-20)

Suspended, not retired: while Pro is hidden no surface is gated, so losing the entitlement hides
nothing and the app icon is already pinned to the primary one. `AlternateIconManager` keeps this
contract and its tests for the release that brings Pro back (ADR 0014).

Core: P5

Given a Pro user loses the entitlement\
When the loss is detected\
Then extended strings and secondary UI hide immediately, the secondary region stays stored, and the app icon reverts to the primary icon

### REQ-SURF-005 — Nearby alerts in every status

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P1, P2

Given neighboring regions are under alert\
When the Status screen or CarPlay Status tab shows the current region, whether quiet or in alarm\
Then the nearby-alerts line is shown

### REQ-SURF-006 — CarPlay tabs stay free

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given a CarPlay session\
When the Details tab, or the Map tab once RD-3 confirms Variant B, is shown\
Then it is available without Pro

### REQ-SURF-007 — Pro hidden for 3.x

Status: approved — owner, 2026-09-20 (decision 2 and ADR 0014 in docs/tasks/ia-simplification-3.0.md)

Core: P3, P5

Given the Pro surface is hidden for 3.x\
When any previously Pro-gated feature is used\
Then it is available to every user; no crown, PRO chip, sparkle, alternate icon or paywall is presented; renewal transactions are still finished by `SubscriptionManager.start()`; and Restore Purchases and Manage Subscription remain reachable

The "Pro" column of the matrix above is the contract Pro returns to, not what 3.x gates: while
this requirement is in force every cell of it that is not decoration is free. The user's own
Live Activity switch still applies — hiding Pro frees the capability, it does not force it on.
Manage Subscription is offered only while a verified entitlement is active, because it has
nothing to manage otherwise. Why and the rejected alternatives: [ADR 0014](../decisions/0014-hide-pro-for-3-0.md).
