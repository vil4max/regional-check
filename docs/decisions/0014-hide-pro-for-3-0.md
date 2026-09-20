# ADR 0014 — Hide Pro for 3.0.x, keep the code

Status: Accepted — owner, 2026-09-20 ("я утвердил самостоятельную работу полностью"), recorded in
[tasks/ia-simplification-3.0.md](../tasks/ia-simplification-3.0.md) §3

## Context

`docs/core.md` "Symbolic Pro (exception)" and [ADR 0007](0007-surface-matrix-and-pro-gating.md)
define Pro as session Live Activity, Pro badge, friendly source label, CarPlay source line,
widget refresh and source, extended Siri answer, secondary region pin and widget, and an
alternate app icon.

The owner decided on 2026-09-20 that the Pro offering should be only premium colours and a
choice of app icon. Both are already backlog items targeted at 3.2.0 (PRO-VIS-1), and the
premium colour tokens exist but have no live consumer — `Theme.RedesignPalette` is read only by
`RedesignBottomBar`, which the same release deletes. So for 3.0.0 the paywall would be selling
a list of things the owner no longer wants in the tier, while the tier's actual future content
is not built yet.

Three facts constrain what can be done about that:

1. `SubscriptionManager.start()` (`RegionalCheckApp.swift:33`) is what subscribes to
   `Transaction.updates` and finishes renewal transactions
   (`StoreKitSubscriptionService.swift:159`). Unwiring it would leave a paying user's renewals
   unfinished.
2. `PaywallView` is the only in-app route to Restore Purchases and Manage Subscription
   (`PaywallView.swift:147-166, 207-216`).
3. `subscription.isPro` is read directly in six places outside the two nominal gates, and some
   of those reads switch on *decoration* — the PRO chip, the Pro palette, and through
   `SubscriptionManager.apply` → `AlternateIconManager.sync`, the alternate app icon. Treating
   "hide Pro" as "make `isPro` true" would turn that decoration on for everybody.

## Decision

Suspend the Pro surface for 3.0.x. Keep the entitlement machinery.

- **Functional gates return true.** `SubscriptionManager.allows(_:)` and
  `SharedStore.loadIsPro()` grant every capability, so the Live Activity, the source label, the
  extended Siri answer and the widget source line become free. The secondary region is not
  freed but deleted — see ADR 0015.
- **Decorative gates are deleted, not flipped.** The crown button, the PRO chip, the summary
  sparkle and the Pro palette plumbing go away with the UI they gate. The palette is pinned to
  the free set and `AlternateIconManager.sync(isPro: false)` is called once, so no user gets the
  Pro icon.
- **The paywall is removed from the UI, not from the codebase.** `PaywallView`,
  `PaywallViewModel`, `Products.storekit`, `StoreKitSubscriptionService` and the entitlement
  cache keep compiling and keep their tests.
- **`SubscriptionManager.start()` stays wired.**
- **Restore and Manage Subscription move to the Details tab**, driven by a view model, using
  `.manageSubscriptionsSheet` for the latter.
- The four StoreKit defects found in the 2026-09-20 audit are fixed *before* the surface is
  hidden, so the fixes are reviewable on their own and the code is correct when Pro returns.

Pro returns in 3.2.0 as premium colours and alternate icon selection (PRO-VIS-1). Reversal is
deleting the `true` returns and restoring the paywall presentation — the model layer is
untouched.

## Rejected alternatives

- **Delete StoreKit entirely.** Twenty Swift files, ~50 catalog keys and fourteen test files,
  and any existing subscriber loses what they paid for with no restore path. Everything would
  have to be rebuilt for 3.2.0.
- **Ship the paywall as it is and only fix the defects.** The tier would advertise capabilities
  the owner has decided are not the product, and the App Store description would have to
  describe them.
- **Force `isPro = true` globally.** Turns on the PRO chip, the Pro palette and the alternate
  icon for every user — the opposite of the intent — and makes `AlternateIconManager` fight the
  free-icon decision on every entitlement change.
- **Keep the crown as a hidden entrance to Restore.** An affordance no user would find, and it
  keeps a paywall one tap from the main screen.

## Consequences

- `docs/core.md` "Symbolic Pro (exception)" needs an owner-approved amendment marking the tier
  suspended for 3.0.x. This ADR proposes it; it does not approve it.
- `docs/requirements/surfaces-and-pro-gating.md` gains REQ-SURF-007 and marks REQ-SURF-004 (Pro
  loss) suspended while it is in force.
- Already-installed surfaces change for existing users: the Status widget's source line appears
  and the Siri answer becomes the extended one. The owner acknowledged this on 2026-09-20 with
  the condition that it be done carefully — the widget must not change shape or lose
  information for anyone, and a placed widget must keep rendering a valid status through the
  update rather than falling back to a placeholder. The secondary-region widget is a separate
  matter: it is deleted, not freed, so a placed one becomes unavailable (ADR 0015).
- ADR 0007 is not superseded — its matrix is the contract Pro returns to. It is suspended.
- App Review: the products stay live in App Store Connect while nothing in the app sells them.
  Restore and Manage in Details are what keep that defensible; removing them entirely would not
  be.
