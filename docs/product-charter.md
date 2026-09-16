# Product Charter

Status: binding. **Product name: Drive Check.**

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

Domain may use `AlertStatus` / `alarm` / `quiet`. UI uses All Clear / Alert Active / Checking / Unavailable with matching circle SF Symbols.

## Never

Accounts, auth, ads, history, user analytics, social features, favorites. Do not sell the app as an “alert monitor.” Do not paywall the current region’s alarm vs clear signal — the map picture of that signal stays free too.

## Symbolic Pro (exception)

Drive Check Pro is a StoreKit 2 entitlement: session Live Activity, Pro badge, extended detail (phone, CarPlay, widget, Siri), home-screen widgets with refresh, Control Center control, pinned secondary region, and alternate app icon. Core glanceable status stays free everywhere.

## Analytics

Apple-only observability (App Analytics, crash reports, TestFlight). No third-party analytics SDK. Details: `docs/analytics.md`.

## App Store copy

Paste-ready for App Store Connect (alerts only in description, not in the name).

| Field | Copy |
| --- | --- |
| Name | DriveCheckUA |
| Subtitle (≤30) | Regional alerts for CarPlay |
| Promo / first line | DriveCheckUA brings regional alert status to CarPlay, helping drivers stay informed without handling their phone. |
| Description opening | DriveCheckUA brings regional alert status to CarPlay, helping drivers stay informed without handling their phone. |
| Onboarding (EN) | Regional alert status, designed for CarPlay. |
| Primary CTA | Get Started |

Keywords: put alert-related terms in keywords / description only — not in the app name.

Full paste-ready **2.0** ASC fields (Description, What’s New, Review Notes, Privacy URL): [docs/release-2.0.md](release-2.0.md#asc-copy-20--english-us).

## Next

Apple Release: assets, metadata, CarPlay entitlement, TestFlight, Review.
