# LIVEACT-glance: a Live Activity readable at one glance, everywhere it appears

Status: scope chosen by the owner on 2026-11-12; plan not written yet. Target: 3.4.0.

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
- **AC-2 Alert duration**: during an alarm, a self-updating "for 12 min" timer from the alert's
  start (`Text(timerInterval:)`, no extra pushes). Needs a new optional `alertStartedAt` in
  `ContentState` and in the server's payload: a contract change in both repositories, old
  builds ignoring the new field. The feed carries no start time (`AlertsSnapshot`; see
  CARPLAY-status-clarity, Out of scope), so the start is the time the server first saw the alarm,
  up to one 30-second poll late; an alarm the server saw only after a gap has no start time and
  shows no timer.
- **AC-3 Status marker**: one marker per state shared with CarPlay's title (today 🚨 alarm,
  🟢 clear, 🟡 stay alert): either the emoji or the SF Symbols the activity uses now. Points to
  decide.
- **AC-4 Dynamic Island**: the minimal view shows the timer of AC-2 during an alarm; compact
  leading and trailing read as one piece (marker + region).
- **AC-5 Accessibility**: VoiceOver reads "Air raid alert, Kyiv, for 12 minutes" as one element
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
