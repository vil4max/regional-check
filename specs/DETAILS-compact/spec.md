# DETAILS-compact: a shorter Details tab

## Request

Owner, 2026-11-10, about the Details tab of 3.3.0 (126) (verbatim): «Нужно пересобрать этот экран,
оптимизировать его.»

Owner's answers the same day: one "Alerts" section (Live Activity and notifications), drop the
country card, shorter captions, purchases and data at the bottom in one compact block with the
version.

## Goal

Details shows the settings a driver changes, in fewer blocks and fewer words: one Alerts section,
then a compact About block. The country summary (the "N of 25 regions" card with its segment bar
and region list) leaves Details.

## Acceptance criteria

- **AC-1** Details has no country summary card: no "N of 25" sentence, segment bar or list of
  regions under alert.
- **AC-2** One section titled "Alerts" holds the Live Activity switch and the alert notification
  switch, each with a caption of at most one short sentence.
- **AC-3** The Live Activity and notification switches keep their behaviour: each reads off while
  iOS refuses it, with the note and Open Settings (REQ-SURF-008, REQ-PUSH-005).
- **AC-4** The notification switch still says that a device token and the last region are sent
  (REQ-PUSH-006), in one short line.
- **AC-5** The bottom block holds Restore Purchases, the data source link with the disclaimer, and
  the version, as one compact block; the location-denied row stays above Alerts when access is off.
- **AC-6** Every new or changed string exists in English, Ukrainian and Russian.

## Out of scope

- The alert-start push itself (ALERT-push, a separate spec); this spec only regroups the switch.
- The Status tab, CarPlay, widgets.

## Decisions

- Owner, 2026-11-10: the four answers above.

## Assumptions

- The nearby-alerts signal stays on the Status tab as its own row (REQ-SURF-005), so removing the
  summary from Details removes no P1 signal.
