# Drive Check — core

Status: approved 2026-09-16 (binding owner-approved charter, including Language and Priorities). Amended 2026-09-17 for the redesign (owner approved the RD-0 amendments: "Утверждаю поправки RD-0"). Amended 2026-09-20 for the 3.0.0 IA simplification (A1–A6 in [tasks/ia-simplification-3.0.md](tasks/ia-simplification-3.0.md) §3; owner: "я утвердил самостоятельную работу полностью" — I approved the autonomous work in full). These amendments state the target; until Phase B of that brief lands, the shipped app still has the Regions tab, the full-screen map and manual pinning.
**Product name: Drive Check.**

| | |
| --- | --- |
| Product name | Drive Check |
| Repository | `regional-check` |
| Bundle ID | `vil4max.RegionalCheck` |
| Scheme / target | `RegionalCheck` |

## Constitution

Drive Check has two layers and judges them by different rules.

**The utility.** Every new line on the driver’s path must reduce complexity or improve the driver’s experience. Otherwise it should not be added. CarPlay, the alert signal, refresh and the region model live here, and nothing below may weaken them.

**The lab.** Drive Check is also the owner’s pet project and a place to learn. Experiments in rendering, motion and platform APIs — wow effects and decoration — are allowed on the phone companion, and they justify themselves by what they teach, not by what they add to the utility. They never enter CarPlay’s glanceable path, never touch the Never list, and never make the free signal slower or harder to read.

The two do not compete: decoration is never traded against driver attention, and the utility rule is not a reason to reject an experiment. Amended 2026-09-18 on the owner’s ruling ("это мой пет проект, поэтому делаем теперь не только утилиту но и лабораторию по изучению" — this is my pet project, so from now on we build not only a utility but also a lab for learning).

## Mission

Know your region's alert status without leaving CarPlay.

## Vision

A glanceable CarPlay utility for drivers: open, see the regional alert status, close. It exists so you do not reach for your phone while driving. Not a monitor, not notifications, not navigation — closer to Maps / Compass / Weather as a system-style check. The phone companion's Status tab shows the alert status first, with the upstream alert map inline under it; tapping the map opens the region list. The map is a glanceable picture of the same free signal, never a navigation surface.

## Product principles

- Tabbed CarPlay: Status and Details (a Map tab only after the RD-3 spike confirms it can ship safely) · tabbed companion on phone (Status + Details)
- The Status tab shows the upstream raster alert map inline, loaded once per session on demand (no polling); it adds no new data beyond the shared snapshot. Tapping the map opens the read-only region list
- One current region, always from location; Kyiv when there is no location
- One State
- One Data Provider
- One User Action (Refresh)
- CarPlay is primary; iPhone is a companion that mirrors the same experience (the map is phone-only until a CarPlay Map tab is approved after RD-3)

## Language

Domain: `AlertStatus` (`quiet` / `alarm`); `StatusState` adds `idle`, `error`, `regionUnavailable`. Region: one current region, resolved from location; Kyiv when location is unavailable. UI keys: All Clear / Alert Active / Checking… / Unavailable / Region Unavailable, with matching SF Symbols; displayed text lives in String Catalogs.

## Never

Accounts, auth, ads, history, user analytics, social features, favorites. Do not sell the app as an “alert monitor.” Do not paywall the current region’s alarm vs clear signal — the map picture of that signal stays free too.

## Priorities

P1 Driver attention · P2 Free, honest signal · P3 Simplicity · P4 Scope & privacy (Never) · P5 Pro.
On conflict the lower number wins; Never items are hard limits, not trade-offs.

## Symbolic Pro (exception)

Drive Check Pro is a StoreKit 2 entitlement: session Live Activity, Pro badge, extended detail (phone, CarPlay, widget, Siri), home-screen widgets with refresh, Control Center control, pinned secondary region, and alternate app icon. Core glanceable status stays free everywhere.

Suspended for 3.0.x (owner, 2026-09-20: "сторкит просто прячем пока не придумаем профит от покупок" — we just hide StoreKit until we work out what purchases are for). The entitlement, restore and renewal handling remain in the app; no Pro surface is presented and every capability listed above is free. Pro returns in 3.2.0 as premium colours and alternate icon selection. See [ADR 0014](decisions/0014-hide-pro-for-3-0.md).

## Analytics

Apple-only observability (App Analytics, crash reports, TestFlight). No third-party analytics SDK. Details: `docs/operations/analytics.md`.

App Store copy: [operations/app-store-copy.md](operations/app-store-copy.md).

## Next

Apple Release: assets, metadata, CarPlay entitlement, TestFlight, Review.
