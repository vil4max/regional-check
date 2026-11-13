# LIVEACT-glance: a Live Activity readable at one glance, everywhere it appears

Status: approved with its plan by the owner on 2026-11-12 ([plan.md](plan.md)). Target: 3.4.0.

## Request

Owner, 2026-11-12: «Прокачать Live Activity». On the candidates: neighbours «это не нужно - акцент
на текущем регионе и статусе тревоги - один взгляд на виджет должен быть понятным о статсуе»;
a region map «это лишнее - лучше подумать об эмоджи для статуса».

## Goal

On the Lock Screen, in the Dynamic Island, on the CarPlay Dashboard, on Apple Watch and in the Mac
menu bar, one glance tells the state of the driver's region and nothing else competes with it.

## What Apple documents (checked 2026-11-12)

- Since iOS 26 a running Live Activity appears on the CarPlay Dashboard and in the Mac menu bar
  with no extra declaration ([ActivityKit updates, June 2025](https://developer.apple.com/documentation/updates/activitykit)).
- With the `.small` supplemental family declared, CarPlay and the Watch Smart Stack draw the
  `.small` view; without it, they combine the compact leading and trailing views
  ([HIG, CarPlay](https://developer.apple.com/design/human-interface-guidelines/live-activities#CarPlay)).
  Drive Check already declares `.small` and `.medium`
  (`RegionalCheckWidgets/DriveCheckLiveActivity.swift:65`).
- CarPlay disables buttons and toggles in a Live Activity
  ([Displaying live data](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities#Add-Buttons-or-Toggles)).
- CarPlay sizes to verify: 240×78, 240×100 and 170×78 pt, in Widescreen, Portrait and Standard
  ([HIG, CarPlay dimensions](https://developer.apple.com/design/human-interface-guidelines/live-activities#CarPlay-dimensions)).
- An ended activity leaves the Dynamic Island and CarPlay at once; the 5-minute green all-clear
  shows only on the Lock Screen, the Watch and the Mac
  ([HIG, ending](https://developer.apple.com/design/human-interface-guidelines/live-activities#Starting-updating-and-ending-a-Live-Activity)).
- The minimal view should show live data rather than only a logo
  ([HIG, minimal](https://developer.apple.com/design/human-interface-guidelines/live-activities#Minimal-presentation)).

## Acceptance criteria (owner's pick, 2026-11-12: all of AC-1 to AC-7, SF Symbols)

- **AC-1 CarPlay and Watch (`.small`)**: the state word and the region at the sizes above, in
  medium weight or heavier, with no button and no line smaller than the caption style.
- **AC-2 Alert duration**: during a fresh alarm, a self-updating "Started 12 minutes ago" line
  from the alert's start (`Text(.currentDate, format: .reference(to:allowedFields: [.hour,
  .minute]))`, no extra pushes, no seconds; plan point 5). The system writes the unit in full;
  the abbreviated "12 min" the owner accepted is open (plan, open point 8).
  Amended 2026-11-13 (owner): «Время показываем из респонса. Не когда получили, а когда начала и
  отбой в респонс»; "Не показывать отбой"; «Цель данных для пользователя в том, чтобы понять,
  насколько актуальные данные я вижу… единственная зацепка у меня — это время». The start is the
  feed's `changed` for the region in alarm (measured: for a clear region it only repeats
  `cachedat`, so there is no all-clear time). Every presentation that has a data time shows it
  ("Updated: 08:54"), beside the start line in an alarm. Then «Время отбоя показываем.
  Передумал»: the green all-clear says "All clear at 08:54" / «Отбой в 08:54» / «Відбій о
  08:54», the time of the first response that showed the region clear (at most one poll late),
  in place of the "Updated" line. Needs a new optional `alertStartedAt` in
  `ContentState` and in the server's payload: a contract change in both repositories, old
  builds ignoring the new field. (The first draft said the feed carries no start time and used the
  time the server first saw the alarm; that was wrong, see the amendment above.)
- **AC-3 Status marker**: one marker per state shared with CarPlay's title (today 🚨 alarm,
  🟢 clear, 🟡 stay alert): either the emoji or the SF Symbols the activity uses now. Points to
  decide.
- **AC-4 Dynamic Island**: compact leading and trailing read as one piece (marker + region). The
  minimal view's timer during an alarm is open with the owner (plan, open point 8): it shows the
  state's symbol until then.
- **AC-5 Accessibility**: VoiceOver reads "Alert, Kyiv, Started 12 minutes ago" as one element
  in every presentation; Dynamic Type does not truncate the state word at the largest size.
- **AC-6 Localization**: every Live Activity string in `en`, `uk` and `ru`; the longest region
  name fits the compact trailing view (truncation rule stated, not left to chance).
- **AC-7 StandBy**: `isActivityFullscreen` gives a large layout of the state and region.

## Out of scope

Neighbouring regions and a region map (owner, 2026-11-12). Buttons in CarPlay. The
BUG-LA-push-start fix (3.3.1).

## Decisions (owner, 2026-11-12)

- Scope: AC-1 to AC-7, all of them ("CarPlay/Watch + Island, Таймер тревоги, Accessibility +
  языки, StandBy").
- AC-3 marker: SF Symbols tinted with the state colour, in the Live Activity and in CarPlay
  ("SF Symbols"); CarPlay's emoji markers go.
- AC-2 timer: accepted with its server change; the deploy stays the owner's.
