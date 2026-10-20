# Drive Check — core

Status: Approved. Amended for the redesign, the 3.0.0 two-tab information architecture (Status and Details, no pinned second region) and the simplified CarPlay screen: the current status and its update time first, nearby alerts only when a neighbouring region is under alert, no second CarPlay tab.
**Product name: Drive Check.**

| | |
| --- | --- |
| Product name | Drive Check |
| Repository | `regional-check` |
| Bundle ID | `vil4max.RegionalCheck` |
| Scheme / target | `RegionalCheck` |

## Constitution

Every new line on the driver’s path must reduce complexity or improve the driver’s experience. Otherwise it should not be added. CarPlay, the alert signal, refresh and the region model live here, and nothing below may weaken them.

Decoration and experiments in rendering, motion and platform APIs are allowed on the phone companion only. They never enter CarPlay’s glanceable path, never touch the Never list, and never make the free signal slower or harder to read. An experiment exists only in builds that never go to App Review: Debug builds from Xcode, or TestFlight builds that are not submitted. It is removed, or compiled out by a compile-time condition of a build configuration that is never archived for submission, before the build that is submitted. A binary that goes to App Review carries no experiment switched off at runtime: no `AppTransaction` environment, sandbox, receipt or TestFlight check decides whether a feature exists. App Review Guidelines 2.5.19 forbids hidden, dormant or undocumented features, and App Review itself runs in the sandbox, so a sandbox switch would show App Review what App Store users never get.

## Mission

Know your region's alert status without leaving CarPlay.

## Vision

A glanceable CarPlay utility for drivers: open, see the regional alert status, close. It exists so you do not reach for your phone while driving. Not a monitor, not notifications, not navigation — closer to Maps / Compass / Weather as a system-style check. The phone companion's Status tab shows the alert status first, with the upstream alert map inline under it; tapping the map opens the region list. The map is a glanceable picture of the same free signal, never a navigation surface.

## Product principles

- One CarPlay screen: the status, the region with its update time, nearby alerts only when there are any, and Refresh — no tabs, no map · tabbed companion on phone (Status + Details)
- The Status tab shows the upstream raster alert map inline, loaded once per session on demand (no polling); it adds no new data beyond the shared snapshot. Tapping the map opens the read-only region list
- One current region, always from location; Kyiv when there is no location
- One State
- One Data Provider
- One User Action (Refresh)
- CarPlay is primary; iPhone is a companion that mirrors the same experience and adds what a driver does not need at a glance (the map, the summary, settings)

## Language

Domain: `AlertStatus` (`quiet` / `alarm`); `StatusState` adds `idle`, `error`, `regionUnavailable`. Region: one current region, resolved from location; Kyiv when location is unavailable. UI keys: All Clear / Alert Active / Checking… / Unavailable / Region Unavailable, with matching SF Symbols; displayed text lives in String Catalogs.

## Never

Accounts, auth, ads, history, third-party analytics SDKs (unless a specific product question needs one), social features, favorites. Do not sell the app as an “alert monitor.” Do not paywall the current region’s alarm vs clear signal — the map picture of that signal stays free too.

## Priorities

P1 Driver attention · P2 Free, honest signal · P3 Simplicity · P4 Scope & privacy (Never) · P5 Pro.
On conflict the lower number wins; Never items are hard limits, not trade-offs.

## Symbolic Pro (exception)

Drive Check Pro is a cosmetic StoreKit 2 purchase: one non-consumable bundle of the Pro alternate app icon, the crown badge and the gold tab accent, bought and restored through a compact sheet opened from the Status crown or Details; an owner switches the Pro icon on or off there. Every useful feature is free: the Live Activity, extended detail (phone, CarPlay, widget, Siri), home-screen widgets with refresh and the Control Center control. See [ADR 0016](decisions/0016-cosmetic-pro.md). Until the purchase exists in App Store Connect it is not on sale: only an existing owner sees the crown and the Details row (REQ-SURF-007, amended 2026-10-20).

The pinned secondary region left the product on 2026-09-20 ([ADR 0015](decisions/0015-two-tab-phone-ia.md)). For 3.0.x the Pro surface was hidden ([ADR 0014](decisions/0014-hide-pro-for-3-0.md)); the large paywall, extra icon sets and a Pro launch presentation are parked.

## Analytics

Analytics is as mandatory as functionality, and Apple-native first: third-party tools only when Apple's are not enough. Sources: App Store Connect App Analytics, Xcode Organizer and App Store Connect crash, hang and power-and-performance reports, TestFlight feedback. No metric without a product question. A third-party SDK needs a recorded decision naming the question Apple's sources cannot answer. What the app collects itself stays declared in the privacy policy and App Privacy labels. Details: `docs/operations/analytics.md`.

App Store copy: [operations/app-store-copy.md](operations/app-store-copy.md).

## Next

Apple Release: assets, metadata, CarPlay entitlement, TestFlight, Review.
