# ADR 0007: Surface matrix and Pro gating

## Context

Drive Check 2.0 adds widgets, controls, App Intents, CarPlay detail, alternate icons, and a secondary pinned region. We must monetize sustainably without hiding life-safety signal from non-subscribers.

## Decision

- **Free everywhere:** current region alarm vs clear, region name, last check time (where space allows), manual region selection, full regions list.
- **Pro:** session Live Activity toggle, Pro badge, friendly source label, CarPlay source line, widget refresh + source, extended Siri answer, secondary region pin + widget, alternate icon.
- **Not sold:** background monitoring, notification feed, historical log, extra API sources (future).

## Alternatives

- Paywall CarPlay or widgets entirely — rejected; CarPlay is the core product surface.
- Charge per region in the list — rejected; data is already in one response.

## Consequences

- Marketing and App Review copy must describe Pro as **extra surfaces and detail**, not access to alerts.
- `SharedStore.shared.entitlement.v1` must stay in sync when subscription state changes offline.
