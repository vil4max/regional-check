# PRO-SALE: Offer the cosmetic Pro

## Goal

In the next feature release, 3.3.0, a driver without Pro can buy Drive Check Pro: the one-time
cosmetic bundle built in PRO-COSMETIC (the Pro alternate icon, the crown badge and the gold tab
accent), product `regioncheck.pro.cosmetic` at $0.99. The crown in the Status toolbar and the Drive
Check Pro row in Details lead every driver to the Pro sheet again. Nothing functional changes: every
feature stays free, and the app asks for no donation of any kind.

The purpose is a live StoreKit 2 purchase in production, not revenue: success is a real purchase
that is verified, restored and finished on a released build.

## Acceptance criteria

- **AC-1** Given a driver without Pro, then the Status toolbar shows the outline crown and Details
  shows the Drive Check Pro row, and each opens the Pro sheet with the product's localized price,
  Buy and Restore (PRO-COSMETIC AC-1).
- **AC-2** Given an owner (the cosmetic bundle, or an active earlier subscription), then the entry
  points, the decoration and the Pro icon switch behave as before.
- **AC-3** Given the product cannot be loaded (no network, or not yet available from the App
  Store), then the sheet shows its unavailable state and no Buy button, never an endless spinner.
- **AC-4** Given a driver without Pro, then every capability that is free today behaves exactly as
  for an owner (PRO-COSMETIC AC-6, REQ-SURF-002).
- **AC-5** The requirements, core, App Store copy, release note, changelog and backlog say that
  Pro is on sale from 3.3.0, and the release note gives the owner the App Store Connect steps and
  App Review notes for the In-App Purchase.
- **AC-6** Every new user-visible string exists in English, Ukrainian and Russian.

## Out of scope

- Donations of any kind: no tip jar, no charity or fund link, no outside payment link (owner,
  2026-10-27).
- App Store Connect: creating the In-App Purchase, its price, localizations, review screenshot,
  attaching it to the version, submission and the tags (the owner's).
- New cosmetic items, the large paywall and a Pro launch presentation (PRO-VIS-1/2, parked).
- Removing the earlier subscription products.

## Decisions

| Question | Owner's answer |
|----------|----------------|
| Offer the cosmetic Pro in the next release? | Yes, `regioncheck.pro.cosmetic` at $0.99 (2026-10-27) |
| Charity link? | No: no donations are collected (2026-10-27) |
| What is the sale for? | An active StoreKit, not earnings (2026-10-27) |

## Assumptions

- The release is 3.3.0: offering a purchase is a feature, so `MINOR` increases (AGENTS.md,
  Versioning).
- The App Store display name is "Drive Check Pro", the name the sheet and Details already use.
- Turning `ProAppearance.isOffered` on is the whole code change; the sheet, purchase, restore and
  entitlement paths are the ones PRO-COSMETIC built and tested.
- The Status and Details snapshot baselines may change because a driver without Pro sees the
  crown and the row again; only those baselines are re-recorded, and only if they mismatch.

## Source

Owner's decisions in this session (2026-10-27), backlog item PRO-COSMETIC ("Selling it needs
`regioncheck.pro.cosmetic` … in App Store Connect, `isOffered = true` and a release"), ADR 0016,
REQ-SURF-007 and the research shortlist of 2026-10-24.
