# STATUS-two-states: two statuses, and the neighbours as a note

Status: draft (owner's answers of 2026-11-13 below; the plan gate approves this text). Ships in
3.4.0, which is not yet submitted (TestFlight round 3).

## Request

Owner, 2026-11-13, about the CarPlay screen:

> Надпись в CarPlay «Будьте внимательны» не информативна. Лучше оставить желтый, но писать «тревоги
> нет». Как-то так написать, что есть тревога в соседних регионах. Будьте внимательны. Потому что
> непонятно, есть тревога или нет. Что такое «будьте внимательны»? Как будто есть тревога, как будто
> желтый уровень. Нет, надо писать все-таки, наверное, ставить цвет зеленый и ставить тревога в
> соседних регионах. Не знаю, короче, какой-то статус такой, потому что сейчас желтый путается. Есть
> желтый уровень тревоги появился, и поэтому это путает, как будто есть желтая тревога. Нет. Все-таки
> у нас два статуса. Есть тревога и нет тревоги. А между ними, обратите внимание, есть тревога в
> соседних регионах.

Owner's answers (2026-11-13): where — «Везде»; look — «Зелёный + пометка»: the title "No Alert" in
green with the shield, and under it the line "Alert nearby: …"; no yellow status any more.

## Why

"Stay Alert" in yellow reads as a third alert level. The driver asks one question, "is there an
alert where I am", and the answer has two values. Neighbours under alert are context for that
answer, not a status of their own.

## Goal

Every surface shows one of two statuses for the driver's region, "Alert" or "No Alert" (plus the
existing grey for old or missing data), and says that a neighbour is under alert as a note where
the surface has room for one.

## Acceptance criteria

- **AC-1** A quiet region on fresh data shows "No Alert" in the status green with the shield symbol
  on the phone hero, the CarPlay title, the Status widget and the Control Center control, whatever
  its neighbours do. No surface shows "Stay Alert" ("Будьте внимательны", «Будьте уважні»), a
  yellow status colour or the warning triangle any more.
- **AC-2** The note: when a neighbour is under alert (REQ-SURF-005's names), the phone shows the
  reason line "Alert nearby: …" (STATUS-reason AC-1) and CarPlay its nearby row, both unchanged.
- **AC-3** Siri and Shortcuts answer "No Alert" for a quiet region and, when a neighbour is under
  alert, add the same note ("Alert nearby: …") to the spoken and the supporting text.
- **AC-4** The widget and the Control Center control show the two statuses only, with no note: they
  have no room for one.
- **AC-5** Alert, old data, missing data and region unavailable look as today.
- **AC-6** The "surrounded" rule (REQ-SURF-010, `NearbyRegionPolicy.isSurrounded`, the caution
  accent, title key, symbol and colour) is removed with its tests; REQ-SURF-010 is retired.
- **AC-7** Every changed string exists in English, Ukrainian and Russian; the removed
  `status.caution.title` keys leave all three catalogs.

## Out of scope

- The Live Activity: it never showed the yellow status (REQ-SURF-010) and is unchanged.
- The map: its quiet and alarm fills are unchanged.
- The neighbour list itself (`NearbyRegionPolicy.activeAlerts`, REQ-SURF-005).

## Decisions

- **D1** One status vocabulary everywhere (owner: «Везде»).
- **D2** Green "No Alert" plus a note, not yellow "No Alert" and not a "Alert nearby" title (owner:
  «Зелёный + пометка»).
- **D3** The widget and the control show no note (agent's proposal, owner confirms at the plan
  gate): a small widget has one status line, and the control one glyph and one word.
- **D4** Siri keeps the note in words, because a spoken answer has no reason line under it (agent's
  proposal, owner confirms at the plan gate).

## Requirements touched

REQ-SURF-010 (retired), REQ-SURF-011 (Siri's status list and the note), REQ-SURF-005 (the note is
the place the neighbours appear), REQ-SURF-001 (status wording), the surface table in
`docs/requirements/surfaces-and-pro-gating.md`.
