# Surfaces and Pro gating

Drive Check 2.0 exposes the same underlying `AlertsSnapshot` across phone, CarPlay, widgets, controls, Siri, and session Live Activity. **Current-region status is free everywhere.** Pro adds detail and extra surfaces.

## Matrix

| Surface | Data source | Free | Pro |
|---------|-------------|------|-----|
| Phone Status tab | Live fetch + `StatusController` | State, region, time, nearby-alert line, inline map | Badge |
| Phone Status tab (inline alert map) | Upstream raster, once per session on demand | Image, fetch time, VoiceOver label; tapping the map opens the region list | Same (not paywalled) |
| Phone Details tab | Same snapshot + entitlement state | Full summary, location access, Live Activity switch, Restore Purchases, data source, disclaimer, version | Manage Subscription (only with an active entitlement) |
| Phone region list (pushed from the Status map, read-only) | Same snapshot | Every region's status, the current region marked | Same (not paywalled) |
| CarPlay Status screen (the only CarPlay screen) | `StatusController` | Title, region and update time, nearby alerts only when there are any, refresh | Same (not paywalled) |
| Live Activity | Started by the app or CarPlay on an alert, ended on a confirmed all-clear (REQ-SURF-009) | Phase, region, time, stale marker; no source name (owner, 2026-09-21) | Same (not paywalled) |
| Status widget | `SharedStore` | Phase, region, time, stale, refresh button; no source name (owner, 2026-09-21) | Same (not paywalled) |
| Control Center / Lock Screen control | `SharedStore` | Open app + region label | Same (not paywalled) |
| Siri / Shortcuts | One fetch within 4 s, else `SharedStore` (REQ-SURF-011) | Region + status, including Stay Alert; age when stale; no source name (owner, 2026-09-22) | Same (not paywalled) |

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
When the Status screen or the CarPlay Status screen shows the current region, whether quiet or in alarm\
Then the nearby-alerts line is shown

Amended 2026-09-21 under the charter amendments approved on 2026-09-20 (tasks/ia-simplification-3.0.md
§3). On the phone the line is its own row on the Status tab, computed from `NearbyRegionPolicy`
and the snapshot, not a sentence inside the summary: the summary moved to the Details tab, and it
drops the nearby sentence while data is stale, which would have hidden a P1 signal after one lost
poll. The row reads the same snapshot the hero shows as last known, whose age the hero's meta line
already states. The wording is the CarPlay Status row's.

Amended 2026-09-21 for CarPlay (owner: "убрать из карплей второй таб и разгрузить первый - для водителя важно текущий статус + апдейт - болше воздуха меньше текста": remove the second CarPlay tab and unload the first; what matters to the driver is the current status and the update time; more air, less text). CarPlay shows the nearby row only when a
neighbouring region is under alert, as one line of names with no detail; with nothing nearby it
shows no row, instead of "Nothing nearby". The owner chose this over dropping the row, which
would have removed a P1 signal from the driver's only surface, and over always showing it,
which keeps text the driver does not need.

### REQ-SURF-006 — One free CarPlay screen

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval); amended 2026-09-21, see below

Core: P1, P2

Given a CarPlay session\
When its root template is built\
Then it is a single Status screen, with no tab bar and no map, available without Pro: the status in the title, the region with its update time, the nearby row only when a neighbouring region is under alert (REQ-SURF-005), the location-denied row only when access is blocked (REQ-REGION-009), and Refresh as the only action

Amended 2026-09-20: CarPlay went from three tabs to two and the Details tab was removed
(owner: "должно быть просто как на айфон только с учетом карплей ограничений" — as simple as
on the iPhone, within CarPlay's limits; the two-tab reading is the agent's,
[tasks/ia-simplification-3.0.md](../tasks/ia-simplification-3.0.md) §4 Q7). Details repeated
the Status rows and the Map tab's list of regions under alert; the one fact only it carried,
the data source, is now the last Status row. `CPInformationTemplate` shows at most 10 items
and 3 actions
([Apple](https://developer.apple.com/documentation/carplay/cpinformationtemplate/init(title:layout:items:actions:)));
the Status tab uses at most 4 and 1.

Amended 2026-09-21 (owner: "убрать из карплей второй таб и разгрузить первый - для водителя важно текущий статус + апдейт - болше воздуха меньше текста": remove the second CarPlay tab and unload the first; what matters to the driver is the current status and the update time; more air, less text). The Map tab is removed, and with it the tab bar
and the second raster fetch it made on selection; the map stays on the phone. The Status screen
drops the region sentence, the country-wide alert count and the source row: none of them is the
driver's current status or its age, and each added a line to read while driving. The screen now
uses at most 3 items and 1 action.

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

### REQ-SURF-008 — The Live Activity switch never promises what iOS refuses

Status: approved — owner, 2026-09-21 ("вариант 1": keep the in-app switch and show under it when Live Activities are off in iOS Settings, with Open Settings)

Core: P2

Given Live Activities are turned off for Drive Check in iOS Settings\
When the Details tab shows the Live Activity switch\
Then the switch reads off and cannot be turned on, a line under it says the Settings switch is off and offers Open Settings, and the driver's own choice is kept for when Settings allows Live Activities again

iOS has its own per-app Live Activities switch
([ActivityAuthorizationInfo](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo)),
and the app already refuses to start an activity while it is off. The two switches are not
duplicates: the system one is permission, the app's decides whether a driving session starts an
activity at all, which lets a driver keep Live Activities for other apps and not for this one.
Before this requirement the app's switch still read on while the system one was off, promising a
Lock Screen activity that could not appear. Rejected: removing the in-app switch, which would
drop that per-app choice and orphan the stored preference of existing users.

### REQ-SURF-009 — The Live Activity follows the alert

Status: approved — owner, 2026-09-21 ("Лайв Активити исчезает сразу же при сворачивании. Должна появляться при тревоге и затем исчезать когда тревога кончится": the Live Activity disappears as soon as the app is minimised; it must appear on an alert and disappear when the alert ends; the owner chose the variant without a server the same day)

Core: P1, P2

Given the in-app switch and iOS both allow Live Activities (REQ-SURF-008)\
When the phone app or a CarPlay session sees the current region in alarm\
Then a Live Activity starts and stays when the app goes to the background; it ends as soon as the app or CarPlay sees a confirmed all-clear for the region; a failed, stale or unknown refresh never ends it; and while there is no alarm no activity starts

The app has no background runtime and no server, so it learns about an all-clear only when the
phone app is opened or CarPlay is connected; while CarPlay is connected the app keeps running and
the activity stays current. While the app is in the background the activity keeps its last
content, and iOS marks it stale at the stale date the app sets (REQ-SURF-003), so it never claims
freshness it lacks. iOS ends any Live Activity after eight hours
([Apple](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)).
An activity that outlived the app's process is adopted on the next launch while the region is
still in alarm, and ended once an all-clear is seen.

Rejected: a server that polls the provider and starts and ends the activity with ActivityKit push
notifications, which would make it fully automatic but needs a server, APNs keys and a change to
the "no server of its own" privacy statement. It is a candidate for after 3.0.0. Also rejected:
the earlier session rule, which ended the activity when the app was minimised, so an alert was
never visible on the Lock Screen at the moment it mattered.

### REQ-SURF-010 — A yellow "stay alert" status when alerts surround a quiet region

Status: approved — owner, 2026-09-21 ("Задача сказать что вокруг вас в регионах тревога - будьте внимательны", then "Просто добавь статус еще один будьте внимательны. Продумай для него цвет. Лучше по правилу светофора": say that regions around you are under alert, be careful; just add one more status, "be careful", with a traffic-light colour; options 1 and 2 of the proposal, without the Live Activity)

Core: P1

Given the current region is quiet on fresh data and at least one neighbouring region is under alert\
When half or more of its neighbours are under alert, or more than half of the country is\
Then the phone Status hero and the CarPlay title show the one-line status "Stay Alert" in yellow instead of "No Alert", and the nearby line of REQ-SURF-005 keeps naming the neighbours

The status reads as a traffic light: green no alert, yellow stay alert, red alert, and light grey
for old or missing data. Stale data never turns yellow, because the neighbours' alerts are as old
as the region's. Neighbours are the ones `NearbyRegionPolicy` defines, so Kyiv city counts the
wider ring around it. The rule reads the current snapshot only. It states a fact about the
situation now and makes no forecast, so the app shows no percentage and keeps no history (core
"Never"). The Live Activity does not react to it (owner, the same day), and neither do the widgets
yet. The Siri answer does, from 3.1.0 (REQ-SURF-011).

Rejected: a probability from historical alert data, which needs an archive the provider does not
offer, a server or bundled statistics, and would put a number on safety that the app cannot stand
behind. Also rejected: a separate warning card under the hero, which the owner turned down in
favour of one more status with no extra text.

### REQ-SURF-011 — The Siri answer is current, says its age and names no provider

Status: approved — owner, 2026-09-22 ("Approve as written", for the text proposed with App Intents slice A; ships in 3.1.0)

Core: P2

Given a driver asks Siri, Shortcuts or the Action button for a region's alert status\
When `CheckAlertStatusIntent` runs\
Then all of these hold:

1. It requests fresh data once and waits at most 4 s. If that fails or runs out of time, it
   answers from the App Group snapshot. If the cached fetch is under 10 s old, no request is sent
   (REQ-REFRESH-010).
2. It names the region and one status: "Alert", "No Alert", "Stay Alert" (REQ-SURF-010, fresh data
   only) or "Region Unavailable". With no snapshot at all, the status is "No Current Data".
3. When the data is stale under REQ-REFRESH-006 (over 2× the base interval: 120 s when quiet, 60 s
   in alarm), it also says how old the data is, for example "Updated 12 minutes ago".
4. It never speaks or shows the data provider's name.
5. It uses `IntentDialog(full:supporting:)`. The full sentence is for voice-only use (CarPlay,
   AirPods). The short supporting line goes with the on-screen result.

The intent cannot see Low Power Mode or the network path, so clause 3 uses the normal quiet and
alarm intervals of REQ-REFRESH-002, not the 300 s constrained one. A fresh snapshot is written to
the App Group but does not reload widget timelines, because a widget reload is a provider trigger
of its own (REQ-PROVIDER-002). The 4 s budget leaves room inside Siri's own time limit for the
cache answer; a request that outlasts it is cancelled, and the single REQ-REFRESH-003 retry of a
transient error counts toward the same budget. A cached fetch dated in the future (the clock moved
back) does not hold the floor. The spoken age uses the language the rest of the answer resolved
to. A Shortcuts automation can run the intent unattended, so it is held
like a scheduled refresh (REQ-PROVIDER-002 clause 4): an HTTP 429 seen by the intent is stored in
the App Group, and until its deadline passes the intent answers from the cache without a request.
The app's own in-memory window is not shared with the intent yet.

This replaces the 2.x "Pro" answer, which added the source name and checked time. That path was
live in 3.0.0 because REQ-SURF-007 frees every Pro feature, so Siri spoke the provider's name.
