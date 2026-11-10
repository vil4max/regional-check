Base: 82d2ed89d79d50319b23dcb30cffb475488f4e8f

# UI-simplify: plan

Spec: `specs/UI-simplify/spec.md`. Branch `claude/ui-simplification`, stacked on
`claude/alert-push` (PR #29) at 82d2ed8.

## Business rules (read first)

| Rule | Source |
|---|---|
| Calm, informative, never frightening or nagging; built-in look, Apple's wording, no invented labels or design | owner, 2026-11-10 |
| The simplification proposal, "All of it", Details in two groups "Alerts" and "Notifications" | owner, 2026-11-10 (spec Decisions) |
| Nearby alerts stay on Status as their own row; CarPlay keeps its line | REQ-SURF-005 |
| The glow reaches the top; the hero goes compact before the map shrinks | REQ-SURF-012, REQ-SURF-013 |
| A switch never reads "on" while iOS refuses it; a note offers Open Settings | REQ-SURF-008, REQ-PUSH-005 |
| The notification switch says what leaves the device | REQ-PUSH-006 |
| Fetch only for an active surface; one map load per session plus driver-initiated retries | REQ-REFRESH-001, REQ-PROVIDER-002 |

## Acceptance criteria and blast radius

AC-1..AC-10 of the spec. Blast radius: `StatusHeroGraphic.swift`, `StatusView.swift`,
`StatusNearbyLine.swift`, `MapCardView.swift`, `MapViewModel.swift`, `HomeView.swift`,
`NearbyAlertsLine.swift` (one extracted function, same output), `DetailsView.swift`,
`DetailsLayout.swift`, `AllClearPushSwitch.swift`, `OnboardingView.swift`,
`Localizable.xcstrings`, their tests and the Prefire baselines. Must not touch: CarPlay templates,
widgets, Live Activity UI, the push controller. Risk class: normal (UI only, one map retry path).

## Approach

Decided by the owner (the approved proposal and mockup); no alternatives are reopened.

- **Hero.** `StatusHeroGraphic` keeps its frame, glow and matched-geometry hook, so the layout
  requirements and the cold-start hand-off are untouched; the radar, the lit ticks, the tick ring,
  the disc and the repeating pulse/rotate effects go. The symbol becomes the filled SF Symbol at
  the disc's size in the status colour (palette: white glyph on the accent). The cold-start copy
  shows the disc only before its symbol appears, so that step keeps a shape.
- **Status rows.** One inset-grouped card under the hero: "Nearby · names" (only with a
  neighbour under alert) and "Regions under alert · N of 25 ›" (only with a snapshot and a list
  route). Pure helpers: `StatusNearbyLine.names(region:phase:snapshot:)` and
  `StatusRegionsCount.text(snapshot:)`.
- **Map.** No caption; a failed load renders an empty zero-height view that keeps the lifecycle
  modifiers. `MapViewModel.retryIfFailed()` is called from the pull to refresh in `HomeView`.
- **Details.** `List` + `.listStyle(.insetGrouped)`, `Section(header:footer:)`; sections from
  `DetailsLayout.sections(isLocationBlocked:hasNotifications:)` →
  `[.location?, .alerts, .notifications?, .about]`; About rows lose `.disclaimer` and `.version`
  (they are the footer). Restore is a plain `Button` (system tint). Toggles use the system tint.
- **Onboarding.** `ScrollView` with the large bold title, three `Label`-like rows (symbol in the
  tint colour, headline + subheadline), and a `.borderedProminent` "Continue" button pinned with
  `safeAreaInset`.

## Strings (en / uk / ru, Apple key where one exists)

| Key | en | uk | ru | Apple source |
|---|---|---|---|---|
| `details.liveActivities` | Live Activities | Дії наживо | Эфир активности | CarPlaySettings.app, BridgeManifests.bundle `LIVE_ACTIVITIES` |
| `details.section.notifications` | Notifications | Сповіщення | Уведомления | Preferences.app `Notifications` |
| `details.push.delivery.immediate` (changed) | Immediate | Негайно | Мгновенно | NotificationsSettings.bundle `IMMEDIATE` |
| `details.dataSource` | Data Source | Джерело даних | Источник данных | GPUIExtension.appex `Data Source` |
| `onboarding.title` | Welcome to Drive Check | Зустрічайте Drive Check | Добро пожаловать в Drive Check! | VideoSubscriberAccount.framework `SETUP_TITLE_STB` "Welcome to %@" |
| `onboarding.continue` | Continue | Продовжити | Продолжить | AccessorySetupUI.app `Continue` |
| `details.allClear.toggle` (changed) | Alerts in My Region | Тривоги в моєму регіоні | Тревоги в моём регионе | app feature, no Apple key |
| `status.nearby.title` | Nearby | Поруч | Рядом | the CarPlay line's word |
| `status.regions.title` | Regions under alert | Регіони під тривогою | Регионы под тревогой | the old map caption's words |
| `status.regions.count` | %lld of %lld | %lld із %lld | %lld из %lld | the old map caption's words |

Changed values: `about.pro.liveActivity.caption` becomes a footer sentence; `about.disclaimer`
stays in full (REQ-PROVIDER-003's tested wording; owner, 2026-11-10: keep it full); onboarding row titles "CarPlay", "Follows Your Location", "Free" and
captions end with a period. Removed: `map.error`, `map.fullscreen.refresh`,
`map.fullscreen.caption`, `driver.age.minutes`, `driver.age.hours` (the caption's age, now
unused), `Onboarding body`, `Get Started`, `subscription.liveActivity.toggle`,
`about.source_link`. Kept: `status.details.nearby_alerts*`, still read by the unshown summary
provider (`StatusDetailsProvider`).

Requirement texts are not edited: REQ-SURF-005's row still names the neighbours in the CarPlay
line's words, and REQ-SURF-012/013 hold with the hero's frame unchanged (the word "radar" in
REQ-SURF-013's note is part of its locked text and stays). DUO AC-1's onboarding spacing rule
(`OnboardingLayout`) is kept with a new design spacing of 72 pt.

## Tests

| AC | Test | Discriminating cases |
|---|---|---|
| AC-2 | `StatusNearbyLineTests` (REQ-SURF-005) now expects the names only | quiet with neighbour; alarm with neighbour, region itself excluded; none; idle/error/no snapshot → nil |
| AC-3 | `StatusNearbyLineTests.regionsRowCountsAlarms` | 2 alarms → "2 of 25"; no snapshot → nil; 0 alarms → "0 of 25" |
| AC-4 | `MapViewModelSessionTests` "a pull retries a failed map, never a loaded one" | failed → one request and loaded; loaded → no request; loading → no second request |
| AC-5..AC-8 | `DetailsLayoutTests` | blocked + push → `[.location, .alerts, .notifications, .about]`; no push → no `.notifications`; About rows without disclaimer and version |
| AC-10 | `DetailsStringsTests` | every new key in en/uk/ru; Apple values exact |
| AC-1, AC-5..AC-9 visual | Prefire baselines re-recorded (Snapshots plan) | not in the gate; screenshots sent to the owner |

Edited existing tests, each for a spec decision: `DetailsStringsTests.switchTitleCoversStartAndEnd`
and `NotificationMirrorTests.labelsAreApples` (new switch title and "Immediate", AC-7),
`DetailsLayoutTests` (Notifications section, footer instead of rows, AC-5..AC-8),
`StatusNearbyLineTests` (names only, AC-2), `OnboardingLayoutTests` (comment and the button's
name), `MapViewModelSessionTests` and `CarPlayRefreshCoordinatorTests` (the removed caption),
`MapViewModelTests` (two retry tests moved out for the file-length limit).
Outside the file list: `Theme+Redesign.swift` (unused ring tokens removed), `MainTabView.swift`
(comments name "Continue"), `AppContainer.swift` (`pullToRefresh`, the AC-4 wiring),
`docs/operations/releases/3.3.md` and `specs/ALERT-push/spec.md` (new labels).

AC-1 and AC-9 are visual and are proven by the Prefire baselines (Snapshots plan, outside the
gate) and the simulator screenshots, not by a unit test: a unit test of "no symbol effect" or
"button pinned" would assert view internals, not behaviour (review round 1, medium, accepted
with this reason).

## Review

Round 1 (`spec-driven-dev:code-reviewer`, CHANGES): repaired — the pull's map retry now waits for
the status to settle and `postStatusDelay` (it was sent in the same instant as the status
request); the pull wiring moved to `AppContainer.pullToRefresh()` with
`AppScenarioTests.pullBringsBackAFailedMap`; the ALERT-push spec and the 3.3 App Review note name
the new labels; the regions test uses the literal 25; a comment no longer says "short
disclaimer". Lows left: no test calls `retryIfFailed()` mid-load (guarded by `isLoading`); the
About section has no header (the mockup has none; `details.section.about` stays in the catalog);
a hidden failed map leaves one `screenInset` gap at the bottom.

## Tasks

## Group 1: Status
- [ ] T001 Test: nearby names, regions count, map retry. Files: `RegionalCheckTests/StatusNearbyLineTests.swift`, `MapViewModelSessionTests.swift`
- [ ] T002 Implement: static hero, status rows, map without caption or error card, pull retry. Files: `StatusHeroGraphic.swift`, `StatusView.swift`, `StatusNearbyLine.swift`, `MapCardView.swift`, `MapViewModel.swift`, `HomeView.swift`
## Group 2: Details
- [ ] T003 Test: `DetailsLayoutTests`. Implement: grouped `List`. Files: `DetailsLayout.swift`, `DetailsView.swift`, `AllClearPushSwitch.swift`
## Group 3: Onboarding and strings
- [ ] T004 Implement: welcome sheet. Files: `OnboardingView.swift`
- [ ] T005 Test + Implement: strings. Files: `Localizable.xcstrings`, string tests
## Group 4: Evidence
- [ ] T006 Re-record Prefire baselines; simulator screenshots of Status, Details and onboarding.

## Verification

`ios-verify --base 82d2ed8` through `sdd-run gate`, `scripts/spec-trace.sh`, the Snapshots plan,
simulator screenshots with `-ScreenshotPhase alertActive|allClear`.
