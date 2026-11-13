# STATUS-api-only: show only what the feed says, and show loading as loading

Status: approved (owner answers, 2026-11-13). Release: 3.4.0, TestFlight round `tf-3.4.0-4`.

## Request

Owner, 2026-11-13, with a screenshot of build 3.4.0 round 3 just after launch: a grey clock, "Тревоги
нет", "Тревога рядом: Черниговская область", "Последнее известное: Тревоги нет · 16:15":

> а почему часики и серое? тревоги же нет

> последнее известное - так не говорят - если ьы про последний статус, то нужно исеать когда была
> последняя тревога и ее длительность - только апи - никакой своей логики - если нечего показать то
> и не надо

> если серый экран с часами это статус загрузки то нужно как-то иначе обозначить загрузку

Answers to the follow-up questions: the stale line is «Обновлено в 16:15» (the same line as on
fresh data); the Live Activity's «Отбой в 08:54» goes too («Убрать и там»); the screen turned
green once the first response came («Позеленел»); loading on old data is «Проверка…».

## Goal

Every time and status the driver sees comes from the alert feed (Ubilling `aerialalerts`). The
feed gives, per region, `alertnow` and `changed`: the start of a current alert, and for a quiet
region only the cache time (checked 2026-11-13 18:36: all 16 quiet regions had `changed` equal to
`cachedat`). So the end of a past alert and its length are not in the feed, and the app shows
neither. Old data reads like the app's other update line, and a request in flight on old data
looks like checking, not like old data.

## Acceptance criteria

- **AC-1** The phone shows no all-clear line ("All clear at … · the alert lasted N min"), and the
  app keeps no all-clear record of its own (STATUS-two-states AC-9 is withdrawn).
- **AC-2** The green all-clear Live Activity shows "Updated: 08:54" like every other state, not
  "All clear at 08:54"; VoiceOver says the same (REQ-SURF-014 clause 1 amended).
- **AC-3** On old data the phone's meta line is "Updated 16:15", the line fresh data uses; the
  "Last known" wording leaves the app, the Live Activity footer and the widget caption in en, uk
  and ru. A stale alarm keeps its red accent and its "May be outdated" footer (REQ-SURF-003); on
  the phone, whose hero has no footer, its meta line reads "Updated 16:15 · May be outdated"
  (REQ-REFRESH-006; review round 1).
- **AC-4** While a request is in flight and the data is old (not an alarm), the Status hero shows
  "Checking…" with the checking symbol, not the grey clock; the nearby note stays (REQ-SURF-005).
  When the response comes, the status shows; when it fails, the grey clock with "Updated 16:15",
  which then stays through the retries until a request succeeds. Fresh data and a stale alarm look
  as before while a request runs.
- **AC-5** `docs/core.md` states the rule: no time or status the feed does not give.

## Out of scope

- CarPlay's stale screen ("No Current Data" with the age) and the widget's expired caption
  ("Open the app to update"): they carry no app-derived time and no "Last known".
- A history of past alerts from another source.
- Removing a leftover `status.allClear.v1` value from TestFlight testers' defaults (never released).

## Decisions

- D1 The stale meta line reuses `status.meta.updated` ("Updated %@" / «Обновлено %@»).
- D2 The checking look on old data reuses the existing checking accent, title and symbol.
