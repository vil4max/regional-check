# CARPLAY-glance: a CarPlay screen a driver understands without reading

Status: draft, 2026-11-12. Not approved. Target: 3.4.0. Follows
[CARPLAY-status-clarity](../CARPLAY-status-clarity/spec.md), whose option A (fewer words in the
same information template) shipped in 3.3.0 and did not satisfy the owner.

## Request

Owner, 2026-11-12 (verbatim): «В CarPlay мне не нравится кнопка, которая... Что ж на ней написано, я
забыл. Проверяем и троеточие. Хотя статус уже получен. Нужно переработать CarPlay дизайн экрана в
максимально понятный, интуитивный.» Then: «нужно проработать карплей дизайн более качественно».

## What the code does today

- One `CPInformationTemplate` (`RegionalCheck/CarPlay/CarPlayTemplateBuilder.swift:31`): the title
  is a marker and the state ("🚨 Alert"), the rows are the region and, when relevant, nearby alerts
  or location access, and the only action is a text button.
- The button reads "Checking…" whenever a load is running and "Refresh" otherwise
  (`CarPlayTemplateBuilder.swift:41-42`). The shared timer polls every 30 to 300 seconds
  (REQ-REFRESH-002), so the button flips to "Checking…" on every background poll while a fresh
  status is already on screen. This is the button the owner describes.

## Goal

At one glance, without reading a sentence, the driver knows: alert or not, for which region, and
whether the data is current. Nothing on the screen moves or changes wording unless the state does.

## Acceptance criteria (draft)

- **AC-1** A background poll never changes any visible text or control while the shown status is
  fresh. "Checking…" appears only after the driver taps Refresh, and only until that check ends.
- **AC-2** The state is the largest element on the screen and differs between alarm, clear, stay
  alert and no current data by shape and by word, not only by colour.
- **AC-3** The region is visible with the state in one short line.
- **AC-4** Stale or missing data never looks current (REQ-REFRESH-007): it shows "No current data"
  and the time of the last good status.
- **AC-5** Every string in `en`, `uk` and `ru`; nothing truncates to nothing in the Widescreen,
  Portrait and Standard CarPlay configurations.
- **AC-6** Each candidate layout is shown to the owner as a mockup at real CarPlay sizes before
  the plan; the plan builds only the one he picks.

## Design options (to mock up, neutral order)

- **A. Keep the information template, fix the button.** AC-1 only, plus wording. Smallest change;
  the state text stays template-sized, which is what the owner calls not clear enough.
- **B. A list template with one large image row.** A rendered status tile (symbol, state word,
  region) as the first row, Refresh as a row or bar button. Large and calm; needs an image
  rendered per state and locale, and the driving-task template list must allow it.
- **C. A grid template.** One large state button tile and a Refresh tile. Symbol-led and
  tappable; grid titles are short, so the region goes in the template title.

Checked against Apple's CarPlay Developer Guide (version 2025-06-09, read 2026-11-12):

- Driving task apps may use the action sheet, alert, grid, list, tab bar, information and point of
  interest templates (template table, p. 13); "attempting to use an unsupported template triggers
  an exception at runtime". All three options are allowed.
- Driving task apps are "limited to 2 templates" of hierarchy depth, root included (p. 13).
- "Do not periodically refresh data items in the CarPlay UI more than once every 10 seconds"
  (driving task guideline 4, p. 5); the shared 30-to-300-second timer stays within it.
- Grid: "up to eight choices represented by an icon and a title", with a navigation bar title and
  leading and trailing buttons.
- List: items with icon, title, subtitle and status indicator, and image row items with row, card,
  condensed, grid and image grid element styles, plus pinned elements; images sized with
  `maximumImageSize` at the car screen's scale, for light and dark.
- Information: "a limited number of static labels with optional footer buttons", one or two columns.

## Out of scope

The Live Activity on the CarPlay Dashboard (LIVEACT-glance). A map, tabs, Pro gating
(REQ-SURF-006). Siri (SIRI-show).

## Points to decide

1. Which option to mock up: all three, A, B and C (owner, 2026-11-12, «Все три»). Markers are SF
   Symbols, as in LIVEACT-glance (owner, 2026-11-12).
2. Whether Refresh stays on CarPlay at all, since the screen refreshes itself (REQ-REFRESH-002).
