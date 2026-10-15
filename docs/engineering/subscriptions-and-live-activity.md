# Drive Check Pro — StoreKit 2 & Live Activity

## Product IDs

| ID | Type | Local price | Sold |
| --- | --- | --- | --- |
| `regioncheck.pro.cosmetic` | non-consumable | $0.99 | yes |
| `regioncheck.pro.monthly` | subscription, month | $0.29 | no; still recognised |
| `regioncheck.pro.yearly` | subscription, year | $0.99 | no; still recognised |

> **Pro is cosmetic** (REQ-SURF-007 as amended, [ADR 0016](../decisions/0016-cosmetic-pro.md)).
> Every capability is free. The one-time product unlocks the Pro app icon (an owner's switch),
> the filled crown and the gold selected tab. An active earlier subscription also counts.
> `regioncheck.pro.cosmetic`, its name and price exist only in the local StoreKit configuration;
> nothing is set up in App Store Connect until the owner approves it.

Local StoreKit config: `RegionalCheck/Resources/Products.storekit` (wired in the `RegionalCheck` scheme Run action as `RegionalCheck/Resources/Products.storekit`).

If the Pro sheet says **Pro isn't available right now** (an empty catalog):

1. Confirm Scheme → Run → Options → StoreKit Configuration = `Products.storekit` (name must not be red).
2. Do **not** enable a custom working directory on Run.
3. Delete the app from the device/simulator, then Run from Xcode (not a cold icon tap).
4. Prefer **Simulator** for local `.storekit`; on a physical device an empty catalog usually means the configuration was not injected and StoreKit queried ASC instead.
5. Filter the console for subsystem category `Subscription` (`vil4max.RegionalCheck`).

## Architecture

- `Subscription/` — protocols, StoreKit service, `EntitlementSelection` (the pure rule that picks the entitlement), entitlement cache, `SubscriptionManager`, `ProAppearance` (owner state and the icon switch)
- `Views/Subscription/` — `ProSheetView` and `ProSheetViewModel` (Buy, Restore, icon switch), `PurchaseSettingsViewModel` (Details' Restore and Manage rows)
- Views never import StoreKit except `ProSheetView` and `DetailsView`, both for `manageSubscriptionsSheet`
- Entitlement comes from verified StoreKit transactions + offline cache with expiry
- Pro is decoration only: the alternate icon, the filled crown and the gold tab accent
- Shared state: App Group `group.vil4max.RegionalCheck` via `SharedStore` — see `docs/requirements/surfaces-and-pro-gating.md`

## Live Activity session

Live Activity is **session-scoped on purpose**. There is no background polling of the alert feed, so a Lock Screen Activity that outlives the session would show a stale air-raid status — worse than showing nothing. Ending the Activity when the phone backgrounds (unless CarPlay still holds a session) is a safety choice, not an unfinished feature.

| Client | Holds Activity | Ends when |
| --- | --- | --- |
| iPhone foreground | `scenePhase == .active` | background → end if no CarPlay (`dismissalPolicy: .immediate`) |
| CarPlay scene | connected | disconnect |

Updates are silent (no alert configuration). `staleDate` is derived from the last `checkedAt` plus twice the current refresh interval, so aged content is marked stale instead of looking fresh forever.

## Testing

```bash
ios-verify lint --fix
ios-verify   # or xcodebuild with an explicit simulator id
```

Unit tests use fakes for StoreKit. Manual: purchase/restore via StoreKit Configuration; open Pro app → Island; background → Activity ends.

## ASC (human)

1. Host Privacy + Terms on GitHub Pages
2. Create subscription group + products at minimum prices
3. App Privacy: Purchases; Live Activities (no push notify product claim)
4. Review Notes: symbolic pricing; session Live Activity; restore path

## Design notes

- Verified transactions + `Transaction.updates`, not a purchase-button bool
- Cache is UX with expiry, not source of truth
- Honest CarPlay / foreground session scope — no background monitoring claim
