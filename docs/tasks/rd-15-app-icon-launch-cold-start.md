# Agent Task — RD-15: "Mark" app icon, launch screen, cold-start transition

Assignee: unassigned
State: open
Owner approval to start: pending. RD-15A and RD-15B each need the owner's explicit approval (`docs/engineering/agent-workflow.md`, "Owner approval gate"); record the quote and date in `Requested by` when given.
Requested by: owner (direct, 2026-09-17, redesign session: "new vision for the app"; icon concept **F · Mark** chosen)
Evidence: canvas boards "App icon · Mark", "Launch screen", "Cold start · animated", "Cold start · storyboard" (https://claude.ai/artifact/CTqozVQ2Z7x8yEQfFnUigv); exports in `docs/design/redesign/`
Parent: `docs/tasks/redesign.md` (new row RD-15 in section 12; ruling Q13 in section 4.3)
Requirements: `docs/core.md` (P1 driver attention, P2 honest signal), `docs/requirements/refresh-policy.md` (freshness), `docs/tasks/cached-launch-status.md` (cached status on launch)
Changes a requirement: Part A no. Part B yes, as a proposal: the cold-start rules below (no status color before status is known, at most 400 ms added, no sweep with fresh cache, Reduce Motion) become a new requirement with a REQ ID that the owner approves before Part B starts.
Owned files:
- Part A (icon): `RegionalCheck/Resources/Assets.xcassets/AppIcon.appiconset/*`, `AppIcon-Pro.appiconset/*` (or their Icon Composer replacements), `RegionalCheck.xcodeproj` build settings for app icons only, `RegionalCheck/App/AlternateIconManager.swift` if the icon names change
- Part B (launch + cold start): `RegionalCheck/Resources/Assets.xcassets/LaunchScreen.imageset/*` (single universal vector image, see Assets), `LaunchBackground.colorset/*`, `RegionalCheck/Resources/Info.plist` (`UILaunchScreen` only), `RegionalCheck/App/RegionalCheckApp.swift` (root overlay only), new `RegionalCheck/Views/ColdStart/*`, new tests under `RegionalCheckTests/`
- This brief

Shared files: `RegionalCheck.xcodeproj/project.pbxproj` is also edited by RD-1 (deployment target) and RD-14 (marketing version). Part A changes only the app icon build settings and does not run while RD-1 or RD-14 has unlanded `project.pbxproj` changes. Part B takes colors and hero geometry from RD-2 tokens and RD-5; it does not edit `Theme.swift` (RD-2 only) and requests token changes through drivecheck-product.
Out of scope: Status screen layout (RD-5), tab bar (RD-4), widget visuals (RD-10), App Store screenshots (RD-13), any change to fetch or refresh timing
Failure conditions: the launch screen or the first animation frame shows a status color before status is known; the animation delays showing a known status by more than 400 ms; the sweep plays when fresh cached status exists; Reduce Motion still animates; the overlay steals VoiceOver focus or taps after it finishes; the Pro alternate icon breaks; icon PNGs have alpha
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1).

## Why

The shipping icon (road into a sunset) predates the redesign, loses its thin
road lines at 29 pt, and says nothing about status. The redesign's hero is a
tick ring with a disc. Using that same shape as the icon, the launch screen,
and the hero turns app launch into one continuous motion: the driver sees the
icon, the same mark on launch, and the mark becoming the status.

## Two parts, two branches

- **Part A — icon.** Independent of other RD tasks. Branch `feat/rd-15a-mark-icon`.
- **Part B — launch screen and cold start.** Depends on RD-2 (tokens) and
  RD-5 (hero geometry). Branch `feat/rd-15b-cold-start`.

## Assets (in the repo)

`docs/design/redesign/icon/`:

| Path | What |
|---|---|
| `default/mark-default-full.{svg,png}` | Main icon, 1024 px, opaque |
| `default/layers/0-background.svg` … `4-signal.svg` | Layers for Icon Composer: background, glow, tick ring, disc, signal |
| `pro/mark-pro-full.{svg,png}`, `pro/layers/*` | Pro alternate: amber instead of green, no crown |
| `dark/`, `tinted/`, `light/` | Reference renders of how the appearances should look |
| `launch/launch-mark.svg` | Launch mark: 156 pt, faint tick ring + neutral dot, transparent. **This is the image for `LaunchScreen.imageset`.** |
| `launch/launch-mark@{1,2,3}x.png` | Reference exports only. Do not put them in the asset catalog. |

Asset catalog rule (`ios-asset-catalog`): app icon sets are exempt, but
`LaunchScreen.imageset` must hold exactly one `universal` image with no
`scale` key and `properties.preserves-vector-representation: true`. Use
`launch-mark.svg`; if the launch screen renders it wrong, convert it to a
single PDF. Strip the C2PA metadata block from the SVG before adding it to
the catalog.

Mockups: `docs/design/redesign/app-icon-mark.png`,
`launch-screen.png`, `cold-start-storyboard.png`.

Geometry (viewBox 100): background radial gradient (center 50 %/36 %,
radius 78 %) `#1F2A38` → `#07090C`; glow r 30 at accent 45 % → 0;
60 ticks between r 29.5 and r 34, stroke 1.5, opacity 0.22 at the bottom
to 0.90 at the top; disc r 19, accent 13 % fill, 45 % stroke 0.7; signal
r 8.5, radial `#C4EBD4` → `#7CC39B`. Pro: `#2B2213` → `#08090B`, accent
`#E8BA62`, signal `#F8E2B0` → `#E8BA62`.

## Part A — icon

1. Research: can Xcode 27 build an Icon Composer `.icon` file **and** an
   alternate `.icon` for `setAlternateIconName`? If not, keep asset-catalog
   app icons for both and use the full PNGs.
2. Build the default icon from the layers (Icon Composer) or the PNG. Let
   the system derive dark, clear and tinted appearances; compare against the
   reference renders and report differences with screenshots.
3. Replace `AppIcon-Pro` the same way. Keep `AlternateIconManager` behavior.
4. Check 29, 40, 60 pt on device or simulator: the ring must stay visible and
   the signal must stay the brightest element.

Acceptance: Home screen, Settings, Spotlight, CarPlay and the App Store
marketing icon show Mark; Pro users get the amber variant; no alpha in
PNGs; `just verify` green.

## Part B — launch screen and cold start

### Launch screen

- Background: the RD-2 `background` token value (`#0C0E11`) in
  `LaunchBackground.colorset`; image = `launch-mark` (single vector image).
- The dot is **neutral** (RD-2 `textBody`, `#E6E8EC`): status is unknown at
  launch.
- Research which placement works: (a) keep `UILaunchScreen` (the image is
  centered) and move the mark up to the hero position as the first part of
  the transition, or (b) a launch storyboard with the mark pinned to the hero
  position (ring top 116 pt from the top on a 390 × 844 screen; follow RD-5's
  real layout). Prefer (a) unless the move looks wrong on small or large
  phones; report with screen recordings.

### Cold-start sequence

A root overlay (above `MainTabView`) plays once per process launch, never on
foreground resume.

| Phase | Starts | Visual | Leaves when |
|---|---|---|---|
| 0 Launch | 0 ms | Launch mark exactly as the launch screen | Immediately (or after the move in placement a) |
| 1 Checking | 0–300 ms | Ticks brighten clockwise from 12 o'clock, white 70 % | Status is known |
| 2 Status known | status time | Ring cross-fades to the status color (38 %); the dot fades out while the disc (status soft fill) springs from 0.18 to 1.0 | ~250 ms |
| 3 Symbol | +150 ms | Status symbol springs in; title, region and cards fade up underneath | ~250 ms |
| 4 Ready | +400 ms max | Overlay is gone; the real hero sits in the same place | — |

Rules:

1. **Fresh cached status** (per `cached-launch-status` and refresh policy):
   skip phase 1, go to phase 2 at once.
2. **Stale cached status or error:** phase 2 uses the stale color and clock
   symbol, as the Status screen does. Never show green for stale data.
3. **Slow network:** phase 1 keeps sweeping (loop) until status is known or
   the Status screen's own timeout shows an error; never block the UI longer
   than the screen itself would.
4. **Reduce Motion:** no sweep, no spring; cross-fade launch → Status in
   200 ms.
5. Total time added after status is known: ≤ 400 ms. The overlay ignores
   touches and is hidden from accessibility; VoiceOver focus lands on the
   hero when the overlay ends.
6. Geometry comes from RD-2 tokens and RD-5's hero; no second set of numbers.

Suggested structure: a pure `ColdStartSequence` (input: cached status and
freshness, status updates, Reduce Motion; output: phase timeline) plus a thin
SwiftUI overlay that renders the phase. Test the pure type with Swift Testing,
named with the approved REQ ID, and snapshot phases 0, 2 and 4.

Acceptance: screen recordings for fresh cache, no cache (fast and slow
network), stale cache, Reduce Motion; `just verify` green; no change to
refresh timing (existing refresh tests untouched and green).

## Completion

Each part in its own worktree from current `main`
(`git worktree add .claude/worktrees/rd-15a-icon -b feat/rd-15a-mark-icon main`,
`git worktree add .claude/worktrees/rd-15b-cold-start -b feat/rd-15b-cold-start main`),
atomic commits, `just verify`, then `READY` to `drivecheck-integrator` with branch,
head SHA, worktree path, this brief, the `just verify` result, and
`release-prep: no`. Send the report to `drivecheck-product`. Never merge, push,
or tag.

`just verify` runs one at a time across all worktrees
(`docs/engineering/agent-workflow.md`, "Verification slots"). Expect to wait;
never stop another session's run; do not raise `VERIFY_SLOTS`.

## Final report

```markdown
# Agent Result

## Outcome
COMPLETED | BLOCKED_CORRECTLY | FAILED

## Summary
## Research findings (Icon Composer alternates, launch placement)
## Files changed
## Recordings and screenshots
## Tests
## Commands executed
## Verification results
## Risks
## Open questions
```
