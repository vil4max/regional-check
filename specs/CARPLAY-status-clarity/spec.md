# CARPLAY-status-clarity: a CarPlay status screen readable at one glance

## Request

Owner, 2026-11-09 (verbatim), about the CarPlay status screen: «не информативно», then «много букв
и за рулем нет понимания с одного взгляда на экран карплей». Brief from the orchestrator: "CarPlay
status screen. The owner finds it uninformative because the current alert status for the chosen
region is unclear."

## Goal

While driving, the owner understands the state of the chosen region from one glance, with few words.
Today the screen has a title, a region row with the update time, an optional nearby row and a
Refresh button; the status is one line of text among others. The goal is one dominant, unambiguous
signal (state, tied to the region) and the least possible other text. The screen stays a single free
Status screen (REQ-SURF-006) and gains no decoration (core).

## Acceptance criteria

- **AC-1** Given a fresh snapshot, then the state is the dominant element of the screen and is
  readable without reading any other row; it is one of four distinct states (alarm, no alert,
  stay alert, no current data), each with its own marker and short wording.
- **AC-2** Given a fresh snapshot, then the region the state is for is visible with the state
  (title area or the first row), in at most one short line.
- **AC-3** Given any state, then the screen carries no more text lines than today, and every
  explanatory or secondary line (update time, location-denied, nearby) appears only when it
  changes what the driver should do or trust.
- **AC-4** Given a stale or missing snapshot, then the screen shows "no current data" and never a
  fresh-looking status (REQ-REFRESH-007).
- **AC-5** Given a quiet region with a neighbour under alert, "Stay Alert" and the nearby line
  behave as in REQ-SURF-005 and REQ-SURF-010.
- **AC-6** Every new or changed string exists in English, Ukrainian and Russian, and nothing is
  truncated to nothing at the CarPlay template's limits.

## Out of scope

- Alert start time or duration: the provider's snapshot carries none (`AlertsSnapshot`).
- Push notifications (feature 2), Siri (feature 3), a map or tabs (REQ-SURF-006).
- Colour or imagery beyond what CarPlay templates allow; the template choice is made at the plan
  gate.

## Decisions

- Owner (2026-11-09): too many words, no understanding at one glance. The remedy is chosen at the
  plan gate from the options in the plan.

## Assumptions

- CarPlay's information template renders title and rows as small text; a list or grid template may
  show the state larger (to verify in the plan against CarPlay limits and the entitlement).
