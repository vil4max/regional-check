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
  At an all-clear the activity never vanishes from red: it turns green and is dismissed 5 minutes
  later, whether the server's `end` push or the app's own fresh all-clear ends it, also after a feed
  gap, a cold start or a region change (owner, 2026-11-10).
- **AC-10** Each Live Activity state has its own symbol, so the states differ by shape and not only
  by colour or words, on the Lock Screen, the Dynamic Island, the Watch and the Mac: alert, a siren
  (`light.beacon.max.fill`) in red; an alert on old data, the siren with a grey clock badge; all
  clear, a shield with a check (`checkmark.shield.fill`) in green; no current data, the grey clock (old data on the Live Activity is grey, never yellow, REQ-SURF-010; the mockup's amber was a drawing slip).
  Only the Live Activity changes; widgets, CarPlay and the app keep their symbols (owner, 2026-11-10).
- **AC-11** When the region changes while an activity runs (the region follows location), the
  activity shows the new region's name and state as soon as that state is newer than what it shows;
  a quiet new region ends it as in AC-9 (owner, 2026-11-10). A new activity inside the green
  5-minute window removes the green one first, so two never show at once (AC-7).
- **AC-8** Every new string exists in English, Ukrainian and Russian; core, requirements, privacy
  policy and release notes describe the alert-start notice and the push-started Live Activity.

## Out of scope

- Notices for neighbouring regions, other threat types, broadcast channels.
- Monetization of any kind.

## Decisions

- Owner, 2026-11-10: the request and the three answers above.
- Owner, 2026-11-10, after the plan (relayed by orch, then answered in this session's chat): the
  all-clear always shows green for 5 minutes (AC-9); per-state symbols, siren and shield, on the
  Live Activity only (AC-10, mockup approved); a region change follows the new region (AC-11);
  the app's own all-clear ends the activity the same way as the server.

## Assumptions

- ActivityKit push-to-start (iOS 17.2+) and update tokens, `apns-push-type: liveactivity`, topic
  `<bundle id>.push-type.liveactivity`, `event` start/update/end, `dismissal-date`, `stale-date`,
  priority 5 outside the budget: Apple, "Starting and updating Live Activities with ActivityKit
  push notifications".
- The content state is decoded with default JSON strategies, so `checkedAt` travels as seconds since
  2001-01-01 (Foundation's default `Date` encoding).
