# ADR 0016 — Pro is a cosmetic bundle

Status: Accepted (owner, 2026-10-05)

## Context

[ADR 0014](0014-hide-pro-for-3-0.md) hid the Pro surface for 3.0.x, made every functional gate
free and planned Pro's return in 3.2.0 as premium colours and a choice of alternate icons
(PRO-VIS-1), followed by a Pro launch presentation in 3.3.0 (PRO-VIS-2). The products in the
StoreKit configuration are two auto-renewable subscriptions.

## Decision

The owner decided on 2026-10-05:

- Every useful feature stays free. Pro unlocks nothing functional.
- Pro is one non-consumable, cosmetic bundle made of what already exists: the Pro alternate app
  icon, the crown badge and the gold tab accent.
- Purchase and restore are a compact flow. StoreKit 2 stays in the app and stays demonstrated.
- The large paywall, the additional icon sets (PRO-VIS-1) and the Pro launch presentation
  (PRO-VIS-2) are parked.
- The bundle may be built and tested with the local StoreKit configuration. Its product ID,
  display name and price, and every App Store Connect step, wait for the owner's approval.

## Consequences

- `docs/core.md` "Symbolic Pro (exception)" describes the cosmetic bundle; ADR 0007's Pro
  matrix is superseded for functional capabilities, which remain free as ADR 0014 made them.
- The functional gates that ADR 0014 made return true stay that way permanently.
- A buyer of an earlier subscription keeps the cosmetics while that entitlement is active, so
  nobody loses what they paid for when the product type changes.
- PRO-VIS-1 and PRO-VIS-2 move to the parked section of the backlog.

## Implementation (2026-10-15)

Built as specified in `specs/PRO-COSMETIC-cosmetic-pro/`: the toolbar crown and a Details row open
a compact sheet; the owner chose `regioncheck.pro.cosmetic` at 0.99 for the local StoreKit
configuration and an icon switch in the sheet. REQ-SURF-007 is amended and REQ-SURF-004 is in force
again for the decoration. App Store Connect setup, the final name and price, and the release stay
with the owner.
