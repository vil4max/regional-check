# ALERT-push: a push when the alert starts, and a Live Activity the server keeps current

## Request

Owner, 2026-11-10 (verbatim): «И пуши нужны не только для отбоя тревоги, но и когда тревога
появляется, сообщать об этом. Для этого, конечно, нужен какой-то полинг. Потому что какой смысл в
пуше, когда только отбой? Если пуш должен контролировать и отбой, и начало тревоги. Потому что пуш
может запустить, перевести апку в состояние, что тревога, запустить все процессы, life activity,
например.»

And (verbatim): «Если пишем регион красным, когда в Life Activity тревога, то нужно Life Activity
каждые 5 минут обновлять и делать key в зеленым, когда тревога кончится. И после после того, как
тревога кончилась, и key в зеленым, Life Activity убирать.»

Owner's answers the same day: a notice and a Live Activity started by push; one switch for alert
start and all-clear; the alert-start notice is time-sensitive.

## Goal

A driver who switched on alert notices learns that the alert in their region started and ended
without opening the app: a time-sensitive notice and a red Live Activity at the start, the Live
Activity refreshed every 5 minutes while the alert lasts, a green Live Activity and a notice at the
all-clear, after which the Live Activity goes away.

## Acceptance criteria

- **AC-1** One switch on Details ("Notify me about alerts in my region") covers both notices; it
  keeps the permission, region and failure rules of ALLCLEAR-push (REQ-PUSH-001, -003..-006).
- **AC-2** While Live Activities are allowed (Details switch and iOS), whatever the notice switch
  (owner, 2026-11-10, plan point 2 option a), the app sends the server its ActivityKit push-to-start
  token, and for the running Drive Check Live Activity its update token; a token change replaces the
  old one, and turning Live Activities off deletes them.
- **AC-3** On a confirmed alarm in the region (fresh feed, a clear status seen before it), the server
  sends one time-sensitive notice and starts the Live Activity in red by push.
- **AC-4** While the alarm lasts, the server updates the Live Activity every 5 minutes with the new
  check time and stale date, at low priority.
- **AC-5** On a confirmed all-clear, the server updates the Live Activity to green, sends the
  all-clear notice, and ends the activity so it leaves the Lock Screen after a short delay.
- **AC-6** A stale, failing or unknown feed changes nothing: no notice, no start, no end
  (REQ-SURF-009), and the Live Activity shows its stale footer when updates stop.
- **AC-7** The app never shows two Drive Check Live Activities: an activity started by push is
  adopted, and the app does not start a second one.
- **AC-9** A Live Activity never hangs stale after an all-clear the app did not see (owner, 2026-11-10:
  «на старой версии апп я пропустил отбой и лайвактивити висел устаревшим»): every Drive Check
  Live Activity, including one the app starts itself, is requested with a push update token that
  reaches the server, so the server's all-clear ends it while the app is not running.
- **AC-8** Every new string exists in English, Ukrainian and Russian; core, requirements, privacy
  policy and release notes describe the alert-start notice and the push-started Live Activity.

## Out of scope

- Notices for neighbouring regions, other threat types, broadcast channels.
- Monetization of any kind.

## Decisions

- Owner, 2026-11-10: the request and the three answers above.

## Assumptions

- ActivityKit push-to-start (iOS 17.2+) and update tokens, `apns-push-type: liveactivity`, topic
  `<bundle id>.push-type.liveactivity`, `event` start/update/end, `dismissal-date`, `stale-date`,
  priority 5 outside the budget: Apple, "Starting and updating Live Activities with ActivityKit
  push notifications".
- The content state is decoded with default JSON strategies, so `checkedAt` travels as seconds since
  2001-01-01 (Foundation's default `Date` encoding).
