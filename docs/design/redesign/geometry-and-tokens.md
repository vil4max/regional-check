# Redesign geometry and tokens (binding)

Status: binding for RD-2, RD-4 … RD-16 and RD-15B. Written by drivecheck-product
from DS-1 (exports landed 4f6034a, canvas version `1789649986-4733`).
`source/tokens.canvas.json` mirrors this file and is not binding; where they
differ, this file wins and the difference is a bug to report.

Owner rulings used (2026-09-17): "скруглённые везде, цвет #EAD7B0" (round caps
everywhere, color #EAD7B0); "правило заглавных утверждаю" (casing rule
approved); R6 dark only; runtime standard/Pro palette ("учитывай премиум цвет
в токенизации, юай должно быть динамически настраиваемо").

## 1. Colors (standard palette)

| Token | Value | Use |
|---|---|---|
| `background` | `#0C0E11` | Screen ground |
| `statusClear` | `#7CC39B` | No alert |
| `statusAlert` | `#F07C7C` | Alert |
| `statusStale` | `#E8BA62` | No current data, stale warnings, "Last known", filled stale Refresh button |
| `statusChecking` | `#9AA0A8` | Checking, unknown |
| `proAccent` | `#EAD7B0` | Crown, PRO chip, paywall accents. Never on a status-bearing element. Replaces `accentPro` |
| `textPrimary` | `#F2F3F5` | Titles, body |
| `textBody` | `#E6E8EC` | Summary sentence; launch dot |
| `textSecondary` | `#A3A7AE` | Captions, meta, section headers |
| `textTertiary` | `#6E737B` | Chevrons |
| `textOnStale` | `#1A1408` | Glyph on the filled stale Refresh button |
| `surface` | white 6 % | Cards, grouped lists |
| `surfaceStroke` | white 10 % | 1 pt card borders |
| `buttonStroke` | white 12 % | 1 pt round button borders |
| `separator` | white 8 % | Row dividers |
| `barGlass` | `#282B31` 72 %, blur 24 | Tab bar, round action button (prefer `.glassEffect()`) |
| `glassFallback` | `#1C1F24` | Glass under Reduce Transparency |
| `ringIdle` | white 12 % | Hero ticks while status is unknown; launch mark |
| `ringSweep` | `textPrimary` 70 % | Checking sweep |
| `ringStatus` | status color 38 % | Hero ticks once status is known |

Status tints (of the current status color): `soft` 14 % (disc fill, pills),
`edge` 40 % (disc stroke), `glow` 20 % (radial 460 × 380 pt, center 190 pt
from top, fades to 0 at 72 %), `shadow` 30 % blur 60, alert pulse 4 → 18 %.

## 2. Pro palette

Views read colors from a runtime palette (`standard`, `pro`) that follows the
Pro entitlement. **Status colors, `ringStatus`, `ringSweep`, `background` and
the stale Refresh button are identical in both palettes.** Only chrome
changes:

| Token | Standard | Pro |
|---|---|---|
| `proChipFill` | `proAccent` 16 % | `proAccent` 16 % |
| `navButtonStroke` | white 12 % | `proAccent` 28 % |
| `navButtonFill` | white 7 % | `proAccent` 8 % |
| `tabSelectedFill` | white 12 % | `proAccent` 14 % |
| `tabSelectedLabel` | white | `proAccent` |
| `barStroke` | white 10 % | `proAccent` 22 % |
| `actionButtonStroke` (glass states only) | white 10 % | `proAccent` 28 % |
| `ringIdle` (in app only) | white 12 % | `proAccent` 14 % |

The static launch screen always uses the standard palette. Mockups:
`iphone-home-pro-clear.png`, `iphone-home-pro-stale.png`,
`pro-palette-tokens.png`.

The widget extension holds a **second copy** of these values in
`RegionalCheckWidgets/DriveCheckWidgetTokens.swift` (RD-10): the extension
target cannot import `Theme+Redesign.swift`, and `RegionalCheckTests` has no
dependency on the extension target, so no test can compare the two. Until that
changes, **a token value change edits both files in the same commit** — one
side alone means the phone and its widgets disagree, and nothing will catch it.
The structural fix is to hold the values once in `DriveCheckKit`, which both
targets already import, and have `Theme+Redesign.swift` read them from there;
that is a post-3.0.0 follow-up, not a redesign change, because it rewrites
RD-2's file. When it happens, `DriveCheckWidgetTokens.swift` is deleted — the
mirror is a workaround for a target boundary, never the intended design.

Decisions recorded by drivecheck-product from RD-2 (2026-09-17): `StatusState`
`.error` without a cached status and `.regionUnavailable` use the neutral
`statusChecking` accent (never a clear or alert color); `.error` with a cached
status follows the stale path (`statusStale`). The old `tabSelected` maps to the
palette's `tabSelectedLabel`. Implemented as `Theme.Redesign*` types
(`RegionalCheck/App/Theme+Redesign.swift`, landed 67d36fb).

## 3. Hero ring (Status screen)

| Property | Value |
|---|---|
| Box | 156 pt |
| Ring radius (tick centre) | 74 pt |
| Ticks | 60, first at 12 o'clock, then every 6° |
| Tick length | 5 pt between r 71.5 and r 76.5 (centre length; round caps make it look about 5.8 pt) |
| Tick width | 1.6 pt |
| Caps | round, everywhere |
| Tick color | `ringIdle` → `ringSweep` → `ringStatus`, flat (no gradient) |
| Disc | 108 pt, fill `soft`, stroke `edge` |
| Symbol | 54 pt, plain glyph (Q9) |

## 4. Launch mark and cold start

- `icon/launch/launch-mark.svg` is the hero ring at 156 pt with `ringIdle`
  ticks (round caps) and a 22 pt dot `#E6E8EC`, no glow. The launch screen
  equals this image; the first cold-start frame equals the launch screen.
- Cold start: sweep with `ringSweep` while checking; once status is known the
  ring cross-fades to `ringStatus`, the dot fades out and the disc springs
  from **0.204** (22 / 108) to 1.0; symbol at +150 ms; at most 400 ms added
  after status arrives; no sweep with fresh cached status; stale cache uses
  `statusStale` and the clock symbol; Reduce Motion cross-fades in 200 ms.
  Behavior rules are proposed as a requirement in RD-R.

## 5. App icon ("Mark")

The icon uses the same elements with its own proportions so it reads at
29 pt (viewBox 100): ring r 29.5–34, 60 ticks, stroke 1.5, opacity 22 %
bottom → 90 % top; disc r 19; signal r 8.5; background radial `#1F2A38` →
`#07090C`; accent `#7CC39B`. Pro icon: background `#2B2213` → `#08090B`,
accent `#E8BA62`, no crown. Files: `icon/`.

## 5a. Bottom bar placement and fade (measured 2026-09-18)

These are the numbers confirmed on running devices, not the ones predicted from
the mockup — the mockup was the source of the original error.

**Bar gap from the screen's bottom edge: `max(24 - safeAreaInsets.bottom, 8)`.**
The mockup `iphone-home-clear.png` draws the bar 24.2 pt from the image bottom
and **draws no home indicator** (verified by scanning its bottom band, twice, by
two sessions). So adding 24 pt on top of a device's 34 pt safe area counted the
same space twice and put the bar ~58 pt up, which is what the owner saw on a
live build. Clamping at 8 pt keeps the bar clear of the indicator, whose drawn
height is about 5 pt.

Measured: **42.0 pt** from the physical edge on a home-indicator device
(`safeAreaInsets.bottom == 34`), **24.5 pt** on an SE3 with a physical Home
button (`safeAreaInsets.bottom == 0`, exactly 2× so 1 pt = 2 px with no scaling
ambiguity).

**Fade: opaque across the bar's footprint, then an eased four-stop gradient over
96 pt** (0 % → 0, 40 % → 0.15, 55 % → 0.97, 100 % → 1.0). The acceptance
criterion is not the distance but the outcome: **no glyph legible at the bar's
top edge**, with a region list long enough to reach it. The 40 pt fade that
shipped first met the mockup, whose content ends well above the bar, and failed
against a real list.

Measured on the no-indicator device: the summary card's last line peaks at
luminance ~26 against a background of ~14.4 — a contrast ratio of about 1.8:1,
under the 3:1 floor for large text, so not legible by any normal standard. That
margin is real but not generous: **re-measure if the fade distance or the
summary's length changes.** A faint trace survives 2× magnification and is
accepted deliberately; clipping the content at the bar's edge was considered and
rejected, because a hard cut under a glass surface reads as a rendering artefact
in a design whose language is soft.

`scrollClearance` derives from the same footprint. Where a static constant is
unavoidable it assumes a 40 pt worst-case safe area — that is a worst case on
purpose, not an observed value, and lowering it to 34 reintroduces the mismatch
this section exists to prevent.

Implementation note that cost a session an hour: measure **around** glass
content, never containing it. Wrapping a `GlassEffectContainer` inside a
`GeometryReader`'s builder closure renders the bar completely invisible — which
over a dark background reads as "fine" until the pixels are scanned. Use
`.background(GeometryReader { … }.preference(…))` with `.onPreferenceChange`.

## 5b. Unavailable status accent (drivecheck-product, 2026-09-18)

`RedesignStatusAccent` gains a fifth case, `.unavailable`, for `StatusState`'s
`.error` and `.regionUnavailable` phases — and it renders in the **same neutral
`statusChecking` colour**, deliberately. A state with no data never carries a
clear or alert colour, and a fourth neutral colour would be another meaning for
a driver to learn for a state that means "nothing is known". The case exists so
the *wording* can differ: `.error` → "Unavailable" (the app could not get data),
`.regionUnavailable` → "Region Unavailable" with `status.detail.region_unavailable`
("Pick another region or refresh") as the supporting line — an instruction
rather than a dead end. Before this, both phases fell into `.checking` and the
hero read "Checking…" forever. This closes research item 1 of
`docs/tasks/rd-2-theme-tokens.md`.

## 6. Status wording casing (owner, 2026-09-17)

- A status word standing alone as a label is Title Case on every surface:
  "No Alert", "Air Raid Alert", "No Current Data", "Checking…" (iPhone hero,
  CarPlay title, widgets, Live Activity, Dynamic Island).
- Explaining or narrating sentences are sentence case: "No air raid alert in
  your region", "Data may be outdated. Refresh to get the latest status."
- Section headers are uppercase: SUMMARY, PRO, DATA, CHOOSE A PLAN.
- Existing `driver.no_current_data` ("No current data") changes to
  "No Current Data" where it stands alone; recorded in the REQ-SURF-001
  proposal (`docs/tasks/redesign.md` 4.4).

## Open items

- The Pro app icon accent is `#E8BA62` (same as `statusStale`); the in-app
  Pro color is `#EAD7B0`. The icon is never shown next to a status, so no
  change is planned unless the owner asks.
