# Surfaces and Pro gating

Drive Check 2.0 exposes the same underlying `AlertsSnapshot` across phone, CarPlay, widgets, controls, Siri, and session Live Activity. **Current-region status is free everywhere.** Pro adds detail and extra surfaces.

## Matrix

| Surface | Data source | Free | Pro |
|---------|-------------|------|-----|
| Phone Status tab | Live fetch + `StatusController` | State, region, time, nearby-alert line, inline map | Badge |
| Phone Status tab (inline alert map) | Upstream raster, once per session on demand | Image, fetch time, VoiceOver label; tapping the map opens the region list | Same (not paywalled) |
| Phone Details tab | Same snapshot + entitlement state | Full summary, location access, Live Activity switch, Restore Purchases, data source, disclaimer, version | Manage Subscription (only with an active entitlement) |
| Phone region list (pushed from the Status map, read-only) | Same snapshot | Every region's status, the current region marked | Same (not paywalled) |
| CarPlay Status tab | `StatusController` | Title, region and update time, alert count, nearby alerts, refresh | Source row (last row) |
| CarPlay Map tab | Upstream raster on demand + snapshot text | Image, image age, regions under alert | Same (not paywalled) |
| Live Activity | Push from app session | Phase, region, time | Source label, stale marker |
| Status widget | `SharedStore` | Phase, region, stale | Source + refresh button |
| Control Center / Lock Screen control | `SharedStore` | Open app + region label | Same (not paywalled) |
| Siri / Shortcuts | `SharedStore` | Region + status dialog | Source + checked time in dialog |

## Principles

1. **No paywall on safety signal** — alarm vs clear for the active region is never locked.
2. **One fetch, shared store** — widgets and app share snapshots in `SharedStore`. Widgets perform best-effort background polling on reload via `WidgetTimelineRefresh`.
3. **Honest age & safety priority** — widgets show explicit timestamp and `⚠` stale markers when data ages; known alarms stay prominently visible and never downgrade to "no connection" screens.

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
Then extended strings and secondary UI hide immediately, and the app icon reverts to the primary icon

Amended 2026-09-20: the "the secondary region stays stored" clause is deleted, because the second
region no longer exists to keep (owner: "не будет второго региона, выкинуть" — there will be no
second region, throw it out; [ADR 0015](../decisions/0015-two-tab-phone-ia.md)). The same ruling
removes the pinned second region from this file's opening sentence, the Home row's Pro cell, the
"Secondary widget" matrix row, and the principle that a second oblast is attention rather than
data. `shared.secondaryRegion.v1` is not merely unread: the app deletes it from the App Group
([region model](region-model.md)).

### REQ-SURF-005 — Nearby alerts in every status

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P1, P2

Given neighboring regions are under alert\
When the Status screen or CarPlay Status tab shows the current region, whether quiet or in alarm\
Then the nearby-alerts line is shown

Amended 2026-09-21 under the charter amendments approved on 2026-09-20 (tasks/ia-simplification-3.0.md
§3). On the phone the line is its own row on the Status tab, computed from `NearbyRegionPolicy`
and the snapshot, not a sentence inside the summary: the summary moved to the Details tab, and it
drops the nearby sentence while data is stale, which would have hidden a P1 signal after one lost
poll. The row reads the same snapshot the hero shows as last known, whose age the hero's meta line
already states. The wording is the CarPlay Status row's.

### REQ-SURF-006 — CarPlay tabs stay free

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given a CarPlay session\
When its tabs are built\
Then there are exactly two, Status and Map, and both are available without Pro

Amended 2026-09-20: CarPlay went from three tabs to two and the Details tab was removed
(owner: "должно быть просто как на айфон только с учетом карплей ограничений" — as simple as
on the iPhone, within CarPlay's limits; the two-tab reading is the agent's,
[tasks/ia-simplification-3.0.md](../tasks/ia-simplification-3.0.md) §4 Q7). Details repeated
the Status rows and the Map tab's list of regions under alert; the one fact only it carried,
the data source, is now the last Status row. `CPInformationTemplate` shows at most 10 items
and 3 actions
([Apple](https://developer.apple.com/documentation/carplay/cpinformationtemplate/init(title:layout:items:actions:)));
the Status tab uses at most 4 and 1.

### REQ-SURF-007 — Pro hidden for 3.x

Status: approved — owner, 2026-09-20 ("сторкит просто прячем пока не придумаем профит от покупок": we just hide StoreKit until we work out what purchases are for; decision 2 and ADR 0014 in docs/tasks/ia-simplification-3.0.md)

Core: P3, P5

Given the Pro surface is hidden for 3.x\
When any previously Pro-gated feature is used\
Then it is available to every user; no crown, PRO chip, sparkle, alternate icon or paywall is presented; renewal transactions are still finished by `SubscriptionManager.start()`; and Restore Purchases and Manage Subscription remain reachable

The "Pro" column of the matrix above is the contract Pro returns to, not what 3.x gates: while
this requirement is in force every cell of it that is not decoration is free. The user's own
Live Activity switch still applies — hiding Pro frees the capability, it does not force it on.
Manage Subscription is offered only while a verified entitlement is active, because it has
nothing to manage otherwise. Why and the rejected alternatives: [ADR 0014](../decisions/0014-hide-pro-for-3-0.md).
