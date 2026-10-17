# DUO: iPhone Duo readiness

## Goal

Drive Check stays usable and looks intended on iPhone Duo in every pose once the app is built with
the iOS 27.1 SDK, which the next Xcode Cloud build uses. With that SDK the app fills both displays
and the system shows tab bars and navigation bars vertically on the side in most poses. The
release also carries the Duo App Store screenshot set, which earns the product page's Duo badge
now and becomes required in April 2027 for apps on the iOS 27.1 SDK.

## Acceptance criteria

- **AC-1** Given the onboarding screen on a display shorter than the one the design was drawn for
  (the iPhone Duo's outer display, 466×678 pt) at the default text size, then all three rows of the
  card are visible above the pinned "Get Started" bar without scrolling; on iPhone 16 and
  iPhone 17 heights the layout is unchanged.
- **AC-2** Given the region list with regions under alert, then the alert section header reads
  "ALERT ACTIVE · N" (and its Ukrainian and Russian equivalents) as before, built without the
  `Text` `+` operator that iOS 26 deprecated.
- **AC-3** (D1, REQ-SURF-013) Given the Status tab on a display where the hero, the nearby line
  and the whole map card do not fit in the visible height, such as the open iPhone Duo in
  landscape, then the hero ring shrinks first, to the compact size, and the map card takes at most
  the remaining height, so the whole map is visible without scrolling, unless that would make it
  narrower than 280 pt; where everything fits, as on iPhone 17 in portrait, the layout is unchanged.
- **AC-4** The iPhone Duo App Store screenshots exist for every store state at an outer
  (1398×2034) and an inner (2007×2853 or 2853×2007) size, as opaque PNGs, in the ignored artifacts
  directory, with the capture steps written down.
- **AC-5** The 3.2 release notes list the iPhone Duo device checks (each pose) and the owner's
  App Store Connect step for the Duo screenshots.

## Out of scope

- Moving the Pro crown into a system toolbar item (P4): decided later by the owner.
- A two-pane layout on the inner display (an arrangement view or a split view).
- CarPlay, widgets and the Live Activity layout, which the system sizes.
- Uploading anything to App Store Connect (the owner's).

## Decisions

| Question | Owner's answer (2026-10-17) |
|----------|-----------------------------|
| Which fixes go into 3.2? | P1 (pose check), P2 (onboarding spacing), P3 (notice comment); P4 later |
| Map or hero first when space is short (D1)? | "Приоритет у карты, а радар может быть меньше" (the map has priority; the radar can be smaller) |
| The deprecated `Text` `+` warning in the region list | Fix it in this task |

## Assumptions

- The design's top spacing (116 pt) applies wherever the space above the pinned bar is at least
  640 pt, which covers iPhone 16 (645 pt) and iPhone 17 (664 pt); below that the missing height
  comes out of the top spacing first, down to 24 pt.
- The compact hero for D1 is the existing AX5 hero set (108 pt ring), not a new size.

## Source

Apple, "Preparing your app for iPhone Duo" and HIG "Designing for iPhone Duo" (read 2026-10-17);
App Store Connect screenshot specifications (iPhone Duo row); the audit in the backlog item
"iPhone Duo spike" and its evidence under `.artifacts/iphone-duo-toolbars/`.
