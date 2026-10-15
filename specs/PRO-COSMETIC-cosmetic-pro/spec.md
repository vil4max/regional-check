# PRO-COSMETIC: Pro as a cosmetic bundle

## Goal

A driver can buy Drive Check Pro once to decorate the app: the Pro alternate app icon, a crown
badge and a gold accent on the selected tab. Pro unlocks nothing functional; every safety and
convenience feature stays free. Buying and restoring happen in one compact sheet that opens
from a crown in the Status toolbar or from a row in Details, and an owner switches the Pro icon
on or off in that sheet. A driver who bought an earlier Pro subscription that is still active
gets the same decoration.

## Acceptance criteria

- **AC-1** Given a driver without Pro, when they tap the crown in the Status toolbar or the Pro
  row in Details, then a compact sheet opens that names the three cosmetic items, shows the
  product's localized price, and offers Buy and Restore.
- **AC-2** Given the sheet is open, when the purchase succeeds and is verified, then the app
  shows the filled crown badge and the gold selected-tab accent without a relaunch, and the
  sheet shows the owned state with the icon switch.
- **AC-3** Given an owner, when they turn the Pro icon switch on, then the app requests the Pro
  alternate icon; when they turn it off, it requests the primary icon. The choice persists
  across launches.
- **AC-4** Given an owner whose entitlement is lost (refund or revocation), then the crown
  badge and gold accent disappear and the primary icon is restored.
- **AC-5** Given a driver with an active entitlement to an earlier Pro subscription product,
  then they are treated as an owner (AC-2, AC-3).
- **AC-6** Given a driver without Pro, then every capability that is free today (status on all
  surfaces, Live Activity, widgets with refresh, Control Center control, extended detail, Siri
  answer) behaves exactly as for an owner.
- **AC-7** Given the purchase is cancelled, pending, fails or cannot be verified, then the
  sheet stays open, shows a short localized message for failures, and nothing is unlocked.
- **AC-8** Given Restore is tapped, then the app syncs with the App Store and reports either
  that Pro was restored or that there was nothing to restore.
- **AC-9** Manage Subscription is offered only to a driver whose entitlement is an earlier
  subscription; the one-time purchase has nothing to manage.
- **AC-10** Every new user-visible string exists in English, Ukrainian and Russian.

## Out of scope

- App Store Connect configuration, the real product ID, display name and price, review notes
  and any release (the owner's).
- The large paywall, additional icon sets and a Pro launch presentation (PRO-VIS-1/2, parked).
- Removing the earlier subscription products.

## Decisions

| Question | Owner's answer (2026-10-15) |
|----------|-----------------------------|
| Where does the sheet open from? | A crown in the Status toolbar and a row in Details |
| Product ID in the local StoreKit configuration | `regioncheck.pro.cosmetic` |
| Placeholder price | 0.99 |
| How is the Pro icon applied? | An owner switches it on or off in the sheet |

## Assumptions

- The non-consumable is added next to the existing subscription group in
  `Products.storekit`; the two subscription IDs stay recognised for AC-5.
- The crown is shown to everyone (outline for non-owners, filled for owners), because it is the
  entry point; the gold tab accent and filled crown are the owner's decoration.
- The icon switch defaults to on right after a purchase.
- The existing `PaywallView` is replaced by the compact sheet; its unused code is deleted.

## Source

Backlog item PRO-COSMETIC and ADR 0016 (owner decision 2026-10-05): "Pro is one non-consumable
cosmetic bundle of the existing Pro icon, the crown badge and the existing gold tab accent, with a
compact purchase and restore flow (StoreKit 2 stays demonstrated) … The cosmetic bundle may be
implemented with StoreKit configuration only; its product ID, name and price need the owner's yes
before any App Store Connect step."
