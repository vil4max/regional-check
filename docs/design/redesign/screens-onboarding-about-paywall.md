# Onboarding, About, Paywall, Outside Ukraine sheet — screen spec

Status: design landed (DS-3, `main` 649e6ad); implementation is RD-16.
Canvas: https://claude.ai/artifact/CTqozVQ2Z7x8yEQfFnUigv, version 26, row
"iPhone — Onboarding, About, Paywall". This file is the contract; a newer
canvas version is a proposal until this file changes with the owner's approval.

Tokens and type come from `docs/tasks/redesign.md` section 5 (runtime palette,
standard and Pro; status colors never themed). No new colors.

## Owner rulings used (2026-09-17, given to the designer)

| # | Ruling |
|---|---|
| Q1 | Onboarding becomes a real first-launch screen: Onboarding → Get Started → Home. The Outside Ukraine sheet shows only when the user is outside Ukraine. App Store shot `05-onboarding` stays. |
| Q2 | Outside Ukraine sheet copy: title "You're outside Ukraine", secondary button "Choose Region" (opens Regions). Body: see O1 below. |
| Q3 | Onboarding row 3 caption: "No account, no ads" ("no tracking" dropped: the app uses Apple App Analytics and crash reports). |

## Common layout

Ground `background`; SF Pro Rounded; side inset 20 pt; cards `surface` with
1 pt `surfaceStroke`, radius 22–24; row dividers `separator`; 44 pt round
glass buttons; primary CTA 56 pt tall, radius 28. Dark only (R6).

## 1. Onboarding — `onboarding.png` (`project/Onboarding.dc.html`)

Full-screen cover on first launch (`OnboardingView`, `purpose: .firstLaunch`).

- Neutral launch mark at the hero position (ring r 74 in a 156 pt box, top
  116 pt, ticks `ringIdle`, dot 22 pt `#E6E8EC`, soft neutral glow white 7 %),
  so launch → onboarding shows no status color.
- Title "Drive Check" 38 / bold; body 17 / 24 `textBody` (key `Onboarding body`).
- Grouped card, 3 rows, 60 pt minimum, 36 pt icon discs (white 8 %):

| Icon | Title (proposal) | Caption (proposal) |
|---|---|---|
| `steeringwheel` | One glance in CarPlay | Your region's status on the car screen |
| `location.fill` | Follows your location | Or pick a region yourself |
| `checkmark.shield` | Alert status is free | No account, no ads (Q3) |

- CTA "Get Started": filled `textPrimary`, `background` text, 58 pt from the
  bottom. Dismisses to Home.

## 2. About — `about.png`, `about-pro.png` (`project/About.dc.html`, `project/AboutPro.dc.html`)

Full-screen cover from the round About button (`purpose: .about`).

- Centered navigation title "About" 17 / semibold (proposal).
- Mark 96 pt; "Drive Check" 28 / bold, PRO chip for Pro users (`accentPro`
  16 % fill); body 16 / 22.
- Section "PRO" (Pro only): `iphone` icon, key
  `subscription.liveActivity.toggle`, caption "Lock Screen and Dynamic
  Island" (proposal), toggle on-color `statusClear`.
- Section "DATA": link row `about.source_link` with `arrow.up.right`
  (`textTertiary`); disclaimer row `about.disclaimer` with `info.circle`,
  14 / 19 `textSecondary`.
- Bottom: "Got It" as a secondary glass button (`barGlass`, stroke white
  12 %); version line 12 pt `textSecondary` (`about.version_build`).

## 3. Paywall — `paywall-{plans,loading,error,empty,subscribed}.png` (`project/Paywall*.dc.html`)

Sheet, large detent, top 56 pt, radius 34. Close: 44 pt round glass `xmark`,
top right, label "Close".

Header: `crown` in a 56 pt disc (`accentPro` 14 % fill, 40 % stroke);
"Drive Check Pro" 28 / bold; `subscription.paywall.subtitle` 15 / 20
`textSecondary`; chip with `checkmark.shield` "Your region's alert status
stays free" (proposal; P2, the paywall never implies status is paid).
Benefits card: `subscription.benefit.{liveActivity,badge,detail}` with
`accentPro` icons (`iphone`, `seal`, `text.bubble`), 15 / 20.

| State | Content | Footer |
|---|---|---|
| Plans | Header "CHOOSE A PLAN" (key `subscription.paywall.plans`, uppercased). Plan rows 64 pt, radius 20. Selected: 1.5 pt `accentPro` stroke, `accentPro` 10 % fill, filled check with `#1A1408` glyph. Unselected: white 4 % fill, 1 pt `surfaceStroke`, empty ring `textTertiary`. Name 16 / semibold, period 13 `textSecondary`, price 17 / semibold tabular. Radio-group semantics. Yearly first and preselected (O3). | Over an 18 pt fade: Subscribe 56 pt filled `accentPro`, `#1A1408` text, `subscription.paywall.subscribePrice`; `subscription.paywall.autoRenew` 12 / 16; link row, each link 44 pt tall: Restore Purchases (semibold) · Privacy Policy · Terms of Use |
| Loading | First plan slot: spinner + `subscription.paywall.loading`; second slot white 3 % placeholder | No Subscribe |
| Error | Card with `wifi.exclamationmark` in `textSecondary` (not a status color), title, body "Check your connection and try again." (proposal), "Try Again" 44 pt glass (`subscription.paywall.retry`) | No Subscribe |
| Empty | Same card with a tray icon; title "Plans are not available right now", body "Try again later." (proposal; replaces the developer text of `subscription.paywall.empty`) | No Subscribe |
| Subscribed (new) | Plans hidden; card "Pro is active" (`accentPro` 10 % fill, 30 % stroke, `checkmark.circle`), "{plan} · Renews {date}", "Thank you for supporting Drive Check." (proposals) | Primary glass button "Manage Subscription" (`subscription.paywall.manage`) |

Behavior changes against current code (RD-16):

1. "Manage Subscription" is not shown to non-subscribers; for subscribers it
   is the primary button.
2. The subscribed state is new (today only a DEBUG status card exists).
3. Error and empty are separate states (today one branch with an optional
   error message).

## 4. Outside Ukraine sheet — `outside-ukraine.png` (`project/OutsideUkraine.dc.html`)

420 pt detent over dimmed Home (black 45 %), radius 34, grabber white 30 %.
Map stand-in at 22 % under a fade; 44 pt icon disc `location.slash`; title
"You're outside Ukraine" 28 / bold (Q2); body 17 / 24 `textBody` (O1 below);
"Got It" 56 pt filled `textPrimary`; secondary "Choose Region" 44 pt text
button, opens the Regions tab (Q2).

Shown only when the user is outside Ukraine (Q1); trigger in O2 below.

## Existing keys kept

`Drive Check`, `Onboarding body`, `Get Started`, `Got It`, `about.disclaimer`,
`about.source_link`, `about.version_build`, `subscription.badge.pro`,
`subscription.liveActivity.toggle`, `subscription.paywall.subtitle`,
`subscription.benefit.{liveActivity,badge,detail}`,
`subscription.paywall.{plans,loading,retry,subscribePrice,restore,manage,autoRenew,privacy,terms}`,
`subscription.error.unavailable`, `subscription.period.{month,year}`, `Close`.
New and changed English copy above is marked "proposal"; RD-11 adds ru/uk.

## Later owner rulings (2026-09-17)

Collected by the designer, then confirmed with the owner by drivecheck-product
where they change a requirement.

| # | Ruling |
|---|---|
| O1 | Outside Ukraine keeps the **last selected region**; with no previous region (first launch abroad) it falls back to Kyiv city. Confirmed with the owner by drivecheck-product. Changes `docs/requirements/region-model.md` ("pin to `.kyivCity`") — proposed amendment, `docs/tasks/redesign.md` 4.4. Body copy stays "Drive Check shows alerts for Ukrainian regions. Your last region stays selected, or pick one in Regions." |
| O2 | The sheet appears when location changes from inside Ukraine to outside, and once at launch if the user is already outside; it does not repeat while the user stays outside. Confirmed with the owner by drivecheck-product. Replaces "once per session" in `region-model.md` — proposed amendment, 4.4. |
| O3 | Paywall: yearly plan first and preselected; Subscribe reads "Subscribe — {yearly price}". No conflict with the Never list (the safety signal stays free). |
| O4 | AX5 Dynamic Type and Reduce Transparency variants of these four screens join DS-2 (starts with DS-2's approval). |

## Open questions

| # | Question | Blocks |
|---|---|---|
| O5 | `accentPro` equals `statusStale` (`#E8BA62`); Paywall and About are amber throughout. Resolved in DS-1; a token value change needs no new mockups. | DS-1 |
