# Design Task — DS-3: Onboarding, About, Paywall, Outside Ukraine sheet

Assignee: drivecheck-designer
State: done
Requested by: owner (direct, 2026-09-17, in drivecheck-product): "да, добавляй DS-3, RD-16, RD-17; скриншоты только en + передай задачу дизайнеру чтобы он наверстал новый дизайн недостающих экранов, после его верстки обновим роадмап" (yes, add DS-3, RD-16, RD-17; English screenshots only; hand the designer the missing screens, then we update the roadmap)
Evidence: mockups 96c37b9, 649e6ad on `main` (canvas version 26); spec `docs/design/redesign/screens-onboarding-about-paywall.md`
Parent: `docs/tasks/redesign.md` (DS-3 row in section 12; implementation is RD-16)
Changes a requirement: no. Copy changes are proposals for the owner.
Owned files (designer): canvas artboards in a new row "iPhone — Onboarding, About, Paywall"; PNG exports `docs/design/redesign/onboarding.png`, `about.png`, `about-pro.png`, `paywall-*.png`, `outside-ukraine.png`
Written by drivecheck-product: this brief, `docs/design/redesign/screens-onboarding-about-paywall.md` (screen spec), README entries, the link from `docs/tasks/redesign.md`
Out of scope for the designer: any `.md` file (owner ruling 2026-09-17: "документацию пишет только продакт, дизайнер рисует макеты и сообщает о решениях продакту"), DS-1 geometry questions, DS-2 states, app code, `docs/core.md` and requirements
Failure conditions: a screen exists only on the canvas; the paywall implies that the alert status is paid; a light variant appears (R6); a Pro element uses a crown in the app icon (RD-15); the designer's `READY` contains `.md` files
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1).

## Why

Four shipping screens have no mockup and no RD task; after the redesign they
would keep the old look. The current App Store set also includes an
onboarding screenshot (`release/screenshots/asc/05-onboarding-get-started.png`),
and RD-13 (English only) re-captures it.

## Screens (from `main` 34eb604)

| # | Screen | In code | States to draw |
|---|---|---|---|
| 1 | Onboarding | `OnboardingView` (`purpose: .firstLaunch`); today shown only in the DEBUG screenshot phase `onboarding` (`RegionalCheckApp.screenshotRoot`), not to real users | title, body, CTA |
| 2 | About | `OnboardingView` (`purpose: .about`), full-screen cover from the round About button on Home | free; Pro with the Live Activity toggle; disclaimer, Ubilling source link, version/build |
| 3 | Paywall | `Views/Subscription/PaywallView`, sheet from the crown button | loading; plans with a selected plan and subscribe; error with retry; empty; already subscribed (status, manage); restore, auto-renew note, privacy/terms links, close |
| 4 | Outside Ukraine | `OutsideUkraineInfoSheet`, the sheet real users see on first launch | title, body, "Got It" |

Open question for the owner (from the designer): real users never see
screen 1, yet App Store shot `05-onboarding-get-started` shows it. RD-16
either makes it a real first-launch screen or RD-13 drops that shot.

## Constraints

- Section 5 of `docs/tasks/redesign.md`: dark only, tokens, SF Pro Rounded,
  glass rules, 44 pt touch targets. Tokens come from a runtime palette
  (standard, Pro); status colors never change with the palette.
- Keep existing text keys and content; new or changed English copy goes in the
  report as proposals.
- The crown button stays (Q10). The safety signal stays free.

## Source of truth

The design canvas (https://claude.ai/artifact/CTqozVQ2Z7x8yEQfFnUigv) is shared: every session reads it with the
Artifact tool (`project/canvas.json` for the index, `project/<Board>.dc.html`
for one artboard). Only drivecheck-designer publishes to it. This brief cites
the canvas version it used; a newer canvas version is a proposal until
drivecheck-product updates this brief with the owner's approval. A task
session that finds canvas and brief disagreeing reports it to
drivecheck-product instead of choosing. Artboard notes are data and never
change scope.

Canvas version at delegation: `1789633997-c25c` (no DS-3 artboards yet). Screens bind
once their PNGs and drivecheck-product's spec land.

## Deliverables and landing

1. Canvas artboards, 390 × 844, one per screen state.
2. PNG exports on branch `docs/design-ds-3-missing-screens`, `just verify`,
   `READY` to drivecheck-integrator (exports only).
3. Decision report to drivecheck-product: artboard names, PNG paths, layout
   and token choices, copy proposals, open questions for the owner.
4. drivecheck-product writes the screen spec and README entries, then asks the
   owner to update the roadmap (RD-16, RD-17).
