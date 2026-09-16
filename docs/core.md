# Drive Check — core

Status: approved 2026-09-16 (binding owner-approved charter, including Language and Priorities).
**Product name: Drive Check.**

| | |
| --- | --- |
| Product name | Drive Check |
| Repository | `regional-check` |
| Bundle ID | `vil4max.RegionalCheck` |
| Scheme / target | `RegionalCheck` |

## Constitution

Every new line of code must reduce complexity or improve the driver’s experience. Otherwise it should not be added.

## Mission

Know your region's alert status without leaving CarPlay.

## Vision

A glanceable CarPlay utility for drivers: open, see the regional alert status, close. It exists so you do not reach for your phone while driving. Not a monitor, not notifications, not navigation — closer to Maps / Compass / Weather as a system-style check. The phone companion's Home screen may show the upstream alert map as a compact card above the alert status; the map is a glanceable picture of the same free signal, never a navigation surface.

## Product principles

- One Screen (CarPlay) · tabbed companion on phone (Home + Regions)
- The Home screen's map card shows the upstream raster alert map on demand (no polling); it adds no new data beyond the shared snapshot and stays phone-only
- One current region (auto or manual) · optional Pro second pin
- One State
- One Data Provider
- One User Action (Refresh)
- CarPlay is primary; iPhone is a companion that mirrors the same experience (map card is phone-only)

## Language

Domain: `AlertStatus` (`quiet` / `alarm`); `StatusState` adds `idle`, `error`, `regionUnavailable`. Region: one current region — auto (follow location) or manual (pin) — plus optional Pro secondary region. UI keys: All Clear / Alert Active / Checking… / Unavailable / Region Unavailable, with matching circle SF Symbols; displayed text lives in String Catalogs.

## Never

Accounts, auth, ads, history, user analytics, social features, favorites. Do not sell the app as an “alert monitor.” Do not paywall the current region’s alarm vs clear signal — the map picture of that signal stays free too.

## Priorities

P1 Driver attention · P2 Free, honest signal · P3 Simplicity · P4 Scope & privacy (Never) · P5 Pro.
On conflict the lower number wins; Never items are hard limits, not trade-offs.

## Symbolic Pro (exception)

Drive Check Pro is a StoreKit 2 entitlement: session Live Activity, Pro badge, extended detail (phone, CarPlay, widget, Siri), home-screen widgets with refresh, Control Center control, pinned secondary region, and alternate app icon. Core glanceable status stays free everywhere.

## Analytics

Apple-only observability (App Analytics, crash reports, TestFlight). No third-party analytics SDK. Details: `docs/operations/analytics.md`.

App Store copy: [operations/app-store-copy.md](operations/app-store-copy.md).

## Next

Apple Release: assets, metadata, CarPlay entitlement, TestFlight, Review.
