# DUO plan (specs/DUO-iphone-duo/spec.md)

Base: 2b6dcab3e7f95cbbbce6f7c1934948459a61e0f9

## Context

The audit of 2026-10-17 ran `main` on the iPhone Duo simulator (Xcode 27.1, iOS 27.1 runtime) in
the closed pose. The owner approved its plan the same day: P1 (pose check), P2 (onboarding
spacing) and P3 (notice comment) go into 3.2, and P4 (crown as a system toolbar item) waits. The
owner added the deprecated `Text` `+` warning in the region list, and from the open pose reported
D1: the map does not fit, and the map has priority over the radar.

## Baseline

Commit `eb95eed`: `ios-verify --base HEAD` PASS, 484 tests (`build/verify/baseline.log`).
The trace was not run at the baseline.

## Approach

Keep the existing layout and adjust only what the Duo's sizes break. Onboarding derives its top
spacing from the height its `GeometryReader` already reports (`OnboardingLayout`, a pure
function). The region list header becomes one localized format with the count. D1, once
approved, adds a pure `StatusLayout` rule that the Status view feeds with its visible height and
measured content: the hero takes the compact size the AX5 shrink already uses, then the map card is
capped to the remaining height.

## Files and types

- `RegionalCheck/Views/OnboardingView.swift`: `OnboardingLayout` (design 116 pt, compact 24 pt,
  design available height 640 pt); the top `Spacer` reads it.
- `RegionalCheck/Views/MainTabView.swift`: the notice comment covers vertical bars.
- `RegionalCheck/Views/RegionListView.swift` and `Resources/Localizable.xcstrings`: key
  `regions.section.alarm %lld` (en, uk, ru) replaces `regions.section.alarm`.
- D1 (pending): `RegionalCheck/Views/StatusLayout.swift` (new, pure), `StatusView.swift`
  (measures the scroll viewport and content, applies the result), `StatusHeroCard.swift` and
  `StatusHeroGraphic.swift` (a compact flag next to the AX5 one), `MapCardView.swift` (an optional
  width cap); `docs/requirements/surfaces-and-pro-gating.md` (new requirement).
- Docs: `docs/planning/backlog.md` (Duo item), `docs/operations/releases/3.2.md` (device checks,
  owner steps), `release/screenshots/README.md` (the Duo set).

## Tests

- AC-1: `OnboardingLayoutTests` — 645 pt and 664 pt keep 116 pt; 40 pt short gives 76 pt; the
  Duo outer 526 pt and 0 pt give 24 pt. Red with a stub returning 116 pt
  (`build/verify/red-onboarding-layout.log`).
- AC-2: `RegionListLocalizationTests` — the header format gives "Alert Active · 3",
  "Тривога · 3" and "Тревога · 3" from the built `.lproj` tables.
- AC-3 (D1): `StatusLayoutTests` — iPhone 17 portrait keeps the design hero and the full-width
  map; Duo inner landscape shrinks the hero and caps the map to the remaining height; a viewport
  where even the compact hero leaves less than the minimum map width keeps that minimum and scrolls.
- AC-4, AC-5: the screenshot files and the release notes, checked by review.

## Risks

- Onboarding: the threshold is a constant, not a measurement; at accessibility text sizes on
  iPhone 16 and 17 the layout is unchanged by design, so the AX5 snapshot stays.
- D1: measuring layout and feeding it back can loop; the rule must depend only on values the
  decision does not change (content height without the map, expressed for the design hero).
- D1: the cold-start hand-off matches the hero's frame; a compact hero must not break it.
- Snapshot baselines (Snapshots plan) render on a 375×812 canvas; D1 changes a baseline only
  where that canvas leaves the map no room, which the Snapshots run shows before any re-record.
- D1: the visible height is the scroll view's own frame, measured on the Duo (52…644 pt on the
  outer display); its scroll geometry would include the refresh control's inset.

## Tasks

## Group 1: onboarding fits the Duo outer display
- [x] T001 Test: `OnboardingLayoutTests` proves AC-1 (red against a stub). Files: `RegionalCheckTests/OnboardingLayoutTests.swift`
- [x] T002 Implement: `OnboardingLayout.topSpacing(availableHeight:)` and use it. Files: `RegionalCheck/Views/OnboardingView.swift`

## Group 2: region list header without `Text` `+`, notice comment
- [x] T003 Test: `RegionListLocalizationTests` proves AC-2. Files: `RegionalCheckTests/RegionListLocalizationTests.swift`
- [x] T004 Implement: one localized format with the count. Files: `RegionalCheck/Views/RegionListView.swift`, `RegionalCheck/Resources/Localizable.xcstrings`
- [x] T005 Implement: the notice comment covers vertical bars (P3). Files: `RegionalCheck/Views/MainTabView.swift`

## Group 3: D1, the map first (approved by the owner on 2026-10-17)
- [x] T006 Spec: REQ-SURF-013 in `docs/requirements/surfaces-and-pro-gating.md`, recorded in the lock
- [x] T007 Test: `StatusLayoutTests` proves AC-3 (red against a stub returning the design layout,
  `build/verify/red-status-layout.log`). Files: `RegionalCheckTests/StatusLayoutTests.swift`
- [x] T008 Implement: `StatusLayout` and its use in the Status tab; the Prefire `Home alert`
  baseline re-recorded, because on its 375×812 canvas the nearby line leaves no room for the
  full-width map under the design hero. A real iPhone 17 keeps the design hero in that state.
  Files: see Files and types

## Group 4: evidence and release notes
- [ ] T009 P1: every pose on the duo simulator, screenshots under `.artifacts/iphone-duo-toolbars/`
  (closed portrait and open landscape done; open portrait, partial fold and closed landscape not
  run, the owner's Device Hub step pending)
- [x] T010 The Duo App Store screenshot set (AC-4) and its capture steps in
  `release/screenshots/README.md` (outer portrait and inner landscape sets)
- [x] T011 Backlog item and `docs/operations/releases/3.2.md` (AC-5)

## Review lows
