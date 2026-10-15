# PRO-COSMETIC plan (specs/PRO-COSMETIC-cosmetic-pro/spec.md)

## Context

ADR 0016 (owner, 2026-10-05): Pro becomes one non-consumable cosmetic bundle — the existing Pro
alternate icon, a crown badge and the gold tab accent — with a compact buy/restore sheet; every
useful feature stays free. Owner answers (2026-10-15): entry from a toolbar crown and a Details
row; local product `regioncheck.pro.cosmetic` at 0.99; the icon is an owner's on/off switch in
the sheet. No App Store Connect step.

## Baseline

Commit `d59b5a4` (= gate-passed `81f47b1` plus a docs-only commit): `ios-verify` PASS,
423 tests, trace 40/40. Log: `build/verify/baseline.log`. Two other writers are working in their
own worktrees on test isolation (G6) and feed/geocoding (G9); they do not touch Subscription/.

## Approach

Keep `SubscriptionManager` and `StoreKitSubscriptionService` (StoreKit 2 stays as built) and add
the non-consumable next to the two subscription IDs, which stay recognised so earlier buyers keep
Pro. Extract the entitlement selection into a pure function so a non-consumable (no expiry) and
the subscriptions are judged by one tested rule. A small `ProAppearance` store owns the icon
switch and applies the icon on entitlement or switch changes, replacing the unconditional
"pin to primary" call. A compact `ProSheet` (view + view model) replaces the unpresented
`PaywallView`/`PaywallViewModel`, which are deleted. The crown returns in `StatusToolbar`, a Pro
row joins Details' purchases section, and `MainTabView` tints with
`Theme.RedesignPalette.current(isProEntitled:)`. Functional gates stay `true`.

## Files and types

- `RegionalCheck/Subscription/SubscriptionProductID.swift`: add `cosmetic`; `isSubscription`.
- `RegionalCheck/Subscription/EntitlementSelection.swift` (new): pure
  `best(from: [EntitlementFact], now: Date) -> EntitlementSnapshot?`; called by
  `StoreKitSubscriptionService.verifyEntitlements` (which shrinks; rc-platform-08).
- `StoreKitSubscriptionService.mapProduct`/`sortRank`: one-time product without a period first.
- `RegionalCheck/Resources/Products.storekit`: a NonConsumable `regioncheck.pro.cosmetic`, 0.99,
  "Drive Check Pro" (placeholders), subscription group kept.
- `SubscriptionManager`: no default `SharedStore.shared`/`EntitlementCache()` (rc-platform-04);
  listener starts before the first await, weak self, cancelled on deinit (rc-platform-16); drop
  the unconditional `AlternateIconManager.sync(isPro: false)`.
- `RegionalCheck/Subscription/ProAppearance.swift` (new, `@MainActor @Observable`): `isOwner`,
  `usesProIcon` persisted in standard defaults (default on), `setUsesProIcon(_:)`; observes
  `entitlementChanges()` and calls `AlternateIconManager.sync(isPro: isOwner && usesProIcon,
  presenter:)`.
- `RegionalCheck/Views/Subscription/ProSheetViewModel.swift` + `ProSheetView.swift` (new);
  delete `PaywallView*.swift`, `PaywallViewModel.swift`, `PaywallViewModelTests.swift` and their
  now-unused catalog keys.
- `StatusToolbar`: crown button (outline / filled gold), accessibility label; `StatusView` and
  `DetailsView` present the sheet; `DetailsView` purchases section gets a Pro row.
- `PurchaseSettingsViewModel.canManageSubscription` → only for a subscription entitlement.
- `MainTabView`: `.tint(RedesignPalette.current(isProEntitled:).tabSelectedLabel)`.
- `AppContainer` / `AppContainerFixture`: build `ProAppearance`, pass explicit dependencies.
- Docs: `docs/requirements/surfaces-and-pro-gating.md` (REQ-SURF-007 amended: cosmetics return;
  REQ-SURF-004 applies to cosmetics only; matrix updated), `docs/core.md` (implemented),
  ADR 0016 consequence note, `docs/engineering/subscriptions-and-live-activity.md`, backlog Done.

## Tests (AC → test, discriminating cases)

- AC-5, AC-4: `EntitlementSelectionTests` — non-consumable with no expiry is active; revoked
  non-consumable is not; active monthly/yearly is; expired subscription is not; unknown ID is
  ignored; non-consumable + expired subscription → active.
- AC-2, AC-7, AC-1, AC-8, AC-9: `ProSheetViewModelTests` with a fake `PurchaseManaging` — price
  shown from the product; success → owned state; cancelled/pending → stays, no message;
  failed/unverified → localized message, not owned; restore restored/empty/failed messages;
  manage offered for a subscription entitlement only.
- AC-3, AC-4: `ProAppearanceTests` with the recording `AlternateIconPresenting` — owner + switch
  on → `AppIcon-Pro`; switch off → nil; entitlement lost → nil even with switch on; switch
  persists in a temporary defaults suite.
- AC-6: `ProHiddenGateTests` renamed `FreeCapabilitiesTests`: `allows` is true with and without
  an entitlement.
- AC-2 decoration: `ThemeRedesignTests` palette by entitlement; snapshot of `StatusToolbar`
  owned / not owned (Snapshots plan, new baselines recorded).
- AC-10: `StatusWordingConsistencyTests`-style catalog check that every new key has en/uk/ru.
- Isolation: `SubscriptionTests` use an isolated `SharedStore` (rc-tests-01/02).

## Risks

- `UIApplication.setAlternateIconName` shows a system alert; tests use the injected presenter
  only, never `UIApplication.shared` (existing `HostProcess` guard stays).
- Entitlement stream ordering: `ProAppearance` must apply after `SubscriptionManager.apply`;
  it reads `isPro` on each change event (no cached copy).
- StoreKit in tests: no `SKTestSession`; the service boundary stays faked.
- Snapshots: the crown changes every Status/Details snapshot; re-record and review them.
- Lint baseline: `SubscriptionManager`, `StoreKitSubscriptionService` and `DetailsView` are
  baselined; they must shrink or stay equal, then regenerate the baseline.

## Tasks

## Group 1: entitlement model and product
- [ ] T001 Test: EntitlementSelectionTests prove AC-5, AC-4 (selection). Files: RegionalCheckTests/EntitlementSelectionTests.swift
- [ ] T002 Implement: `cosmetic` product ID, EntitlementSelection, service uses it, Products.storekit entry, mapProduct/sortRank. Files: Subscription/*, Resources/Products.storekit
- [ ] T003 Test+Implement: SubscriptionManager explicit dependencies, listener fix; SubscriptionTests isolated. Files: SubscriptionManager.swift, EntitlementCache.swift, SubscriptionTests.swift, AppContainer*.swift

## Group 2: Pro appearance (icon switch)
- [ ] T004 Test: ProAppearanceTests prove AC-3, AC-4. Files: RegionalCheckTests/ProAppearanceTests.swift
- [ ] T005 Implement: ProAppearance; remove the unconditional pin; wire in AppContainer. Files: Subscription/ProAppearance.swift, SubscriptionManager.swift, AppContainer*.swift, AlternateIconManagerTests.swift

## Group 3: compact sheet
- [ ] T006 Test: ProSheetViewModelTests prove AC-1, AC-2, AC-7, AC-8, AC-9. Files: RegionalCheckTests/ProSheetViewModelTests.swift
- [ ] T007 Implement: ProSheetViewModel, ProSheetView, catalog keys (en/uk/ru); delete Paywall*. Files: Views/Subscription/*, Resources/Localizable.xcstrings

## Group 4: entry points and decoration
- [ ] T008 Test: FreeCapabilitiesTests (AC-6), palette-by-entitlement test, toolbar snapshots (AC-2), catalog completeness (AC-10). Files: tests as above
- [ ] T009 Implement: crown in StatusToolbar, sheet presentation in Status and Details, Pro row, manage rule, tab tint. Files: StatusToolbar.swift, StatusView.swift, DetailsView.swift, MainTabView.swift, PurchaseSettingsViewModel.swift

## Group 5: documents
- [ ] T010 Docs: requirements, core.md, ADR 0016, engineering doc, backlog Done, progress. Files: docs/**

## Review lows

Review by `ios-agentic-sdlc:code-reviewer` (2026-10-15): no high; five medium, all repaired
(owner read through rather than cached and started before StoreKit; AC-2, AC-6 and AC-9 tests;
one Manage rule on `SubscriptionState`; AC-10 resolved through the built bundle; red runs were not
recorded, the gate ran on each repaired tree). Lows fixed: presenter in the persistence test,
injected Pro defaults, stale gate comments, a loading state while the sheet loads products,
fixture owns the cosmetic product. Lows left in the backlog (PRO-LOWS): a generation stamp so a
slow `currentEntitlement()` read cannot overwrite a newer listener update at launch; protocols
declared next to their classes (`ProOwnershipSource`, `ProIconSwitching`).

## Verification

Each group: `IOS_VERIFY_IDLE_SECONDS=900 IOS_VERIFY_UNIT_CAP_SECONDS=900 ios-verify`; Group 4 also
the Snapshots plan; end: `scripts/spec-trace.sh`, a run on the worktree's simulator
(`ios-verify run-sim`) with the StoreKit configuration to buy, toggle the icon and restore, and
one review by the `ios-agentic-sdlc:code-reviewer` agent.
