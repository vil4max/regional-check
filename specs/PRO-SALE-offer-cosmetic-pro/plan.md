# PRO-SALE plan: offer the cosmetic Pro in 3.3.0

Spec: `specs/PRO-SALE-offer-cosmetic-pro/spec.md`. Skill: `/spec-driven-dev:plan`.

## Context

The owner decided on 2026-10-27 to sell the cosmetic Pro (`regioncheck.pro.cosmetic`, $0.99) in the
next release, and that no donations of any kind are collected (no charity link, no tip jar). The
purchase flow was built and tested in PRO-COSMETIC and shipped off sale in 3.2.0 behind
`ProAppearance.isOffered = false`. This plan turns the sale on, updates the records and prepares
3.3.0; App Store Connect stays the owner's. The goal is an active StoreKit in production, not
earnings (owner, 2026-10-27).

## Baseline

Commit `589b04125fd3c50d6d3777f443e56f8f79426405`. `ios-verify --base HEAD`: PASS, 495 tests passed,
0 failed (`build/verify/baseline.log`).

## Approach

Revert the effect of `0ee9613` ("keep Pro off sale") with one constant: `ProAppearance.isOffered =
true`, so `showsEntry` is true for every driver and the existing crown (`StatusToolbar`) and Details row
(`DetailsView.purchasesSection`) open the existing `ProSheetView`. No new types. The requirement,
core and ADR records are amended in the same commit, as `0ee9613` did. A separate release-prep commit
sets 3.3.0 and writes the release note with the owner's App Store Connect steps.

## Files

- `RegionalCheck/Subscription/ProAppearance.swift` — `isOffered = true`; its comment names the 3.3.0 decision.
- `RegionalCheckTests/ProAppearanceTests.swift` — the off-sale test becomes the on-sale test.
- `docs/requirements/surfaces-and-pro-gating.md` — REQ-SURF-007 "Amended 2026-10-27": on sale from 3.3.0; the 2026-10-20 off-sale clause no longer applies.
- `docs/core.md` "Symbolic Pro" — drop "Until the purchase exists … not on sale"; no donations.
- `docs/decisions/0016-cosmetic-pro.md` — one line under Implementation: offered from 3.3.0 (owner, 2026-10-27).
- `docs/planning/backlog.md` — PRO-COSMETIC row: on sale from 3.3.0; add PRO-SALE row.
- Release prep: `RegionalCheck.xcodeproj/project.xcproj` (`MARKETING_VERSION` 3.3.0 in every target and configuration), `CHANGELOG.md`, `docs/operations/releases/3.3.md`, `docs/operations/app-store-copy.md`.
- Only if the Snapshots plan mismatches: the non-owner Status and Details baselines in `RegionalCheckSnapshotTests/__Snapshots__/`.

## Tests

| AC | Test | Discriminating cases |
|---|---|---|
| AC-1 | `ProAppearanceTests` "REQ-SURF-007 PRO-SALE AC-1 every driver reaches the Pro sheet while Pro is on sale" (replaces `entryOnlyForOwnersWhileNotOffered`) | `isOffered == true`; driver without Pro → `showsEntry == true` (false today); owner → `true` |
| AC-1 | existing `ProSheetViewModelTests` "PRO-COSMETIC AC-1 a driver without Pro is offered the cosmetic product at its price" | unchanged, must stay green |
| AC-2 | existing `ProAppearanceTests` AC-2/AC-3/AC-4 tests and `EntitlementSelectionTests` | owner, earlier subscriber and revoked entitlement unchanged |
| AC-3 | existing `ProSheetViewModelTests` "an empty catalog is unavailable, not a spinner" | empty catalog → `.unavailable`, no Buy |
| AC-4 | existing `ProHiddenGateTests` (REQ-SURF-007, PRO-COSMETIC AC-6) and REQ-SURF-002 tests | driver without Pro gets every capability |
| AC-5 | review of the doc diff; `scripts/spec-trace.sh` | REQ-SURF-007 still cited, no unknown IDs |
| AC-6 | String Catalog diff | no new catalog keys; What's New and the IAP texts exist in en, uk, ru |

## Risks

- **App Review**: a purchase entry whose product is not attached to the submission shows "unavailable" to the reviewer, which is why the sale was switched off. The owner must create the IAP and attach it to version 3.3.0 before submitting.
- **Snapshots**: a driver without Pro sees the crown and the row again, so the Status and Details baselines may change. Re-record only those, only on mismatch.
- **Lifecycle, concurrency, test host**: unchanged; no live service starts in unit tests (`iconPresenter: nil`).
- **Localization**: no new UI strings; What's New and the IAP display name and description are written in en, uk, ru.
- No device family or entitlement change.

## Tasks

```
## Group 1: Pro is on sale (one commit: feat(pro): offer the cosmetic pro)
- [ ] T001 Test: "REQ-SURF-007 PRO-SALE AC-1 every driver reaches the Pro sheet while Pro is on sale" proves AC-1; red on the baseline. Files: RegionalCheckTests/ProAppearanceTests.swift
- [ ] T002 Implement: isOffered = true and its comment. Files: RegionalCheck/Subscription/ProAppearance.swift
- [ ] T003 Docs: REQ-SURF-007 amendment, core "Symbolic Pro", ADR 0016 line, backlog (AC-5). Files: docs/requirements/surfaces-and-pro-gating.md, docs/core.md, docs/decisions/0016-cosmetic-pro.md, docs/planning/backlog.md
- [ ] T004 Check: run the Snapshots plan; re-record only the mismatching non-owner Status and Details baselines and look at each. Files: RegionalCheckSnapshotTests/__Snapshots__/
- [ ] T005 Gate: ios-verify and scripts/spec-trace.sh green (AC-2, AC-3, AC-4)
## Group 2: Prepare 3.3.0 (one commit: build(release): prepare 3.3.0)
- [ ] T006 MARKETING_VERSION 3.3.0 in every target and configuration. Files: RegionalCheck.xcodeproj/project.xcproj
- [ ] T007 Release note: What's New en/uk/ru, App Review "In-app purchases" paragraph, owner steps (create the non-consumable regioncheck.pro.cosmetic at $0.99, display name "Drive Check Pro" and description in en/uk/ru, review screenshot of the sheet, attach it to 3.3.0, apply the description with the Pro paragraph and the vil4max.com links, tf- and v tags). Files: docs/operations/releases/3.3.md (AC-5, AC-6)
- [ ] T008 CHANGELOG 3.3.0 and app-store-copy: the Pro paragraph now applies. Files: CHANGELOG.md, docs/operations/app-store-copy.md
- [ ] T009 Gate: ios-verify and scripts/spec-trace.sh green
## Review lows
(filled by implement)
```

## Verification

- `ios-verify` (background, 10-minute timeout) and `scripts/spec-trace.sh` after each group.
- The Snapshots plan for Group 1.
- `ios-verify run-sim`: as a driver without Pro, the crown and the Details row open the sheet, and a purchase in the local StoreKit configuration shows the gold accent and the icon switch. Screenshots go to `.artifacts/` through `python3 scripts/project-artifacts.py task pro-sale`.
- Not covered here: the real App Store product, App Review, TestFlight and the tags (the owner's).
