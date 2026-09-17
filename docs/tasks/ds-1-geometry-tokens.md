# Design Task — DS-1: One geometry and token set for hero, launch, and icon

Assignee: drivecheck-designer
State: done
Requested by: drivecheck-product (managing agent), from designer questions D3–D8 and D10 (2026-09-17). Owner approval (wave 1): "утверждаю" (I approve), owner direct, 2026-09-17, in drivecheck-product, answering "утверждаете роадмап и запуск волны 1?" (do you approve the roadmap and the wave 1 launch?).
Evidence: exports 4f6034a (canvas 1789649986-4733); binding text `docs/design/redesign/geometry-and-tokens.md`
Parent: `docs/tasks/redesign.md` (sections 5.1, 5.3, 9); `docs/tasks/rd-15-app-icon-launch-cold-start.md`
Changes a requirement: no. D10 (title casing) is written as a proposal for the owner, alongside the REQ-SURF-001 amendment in redesign.md 4.4.
Owned files (designer): `docs/design/redesign/icon/**` exports only (metadata-free files, redrawn `launch/launch-mark.svg`), canvas artboards
Written by drivecheck-product: this brief, `docs/design/redesign/geometry-and-tokens.md`, README entries, `docs/tasks/redesign.md` 5.1/5.3, the RD-15 phase table
Out of scope for the designer: any `.md` file (owner ruling 2026-09-17: "документацию пишет только продакт, дизайнер рисует макеты и сообщает о решениях продакту" — only the product agent writes documentation; the designer draws mockups and reports decisions), app code, `Theme.swift` (RD-2), new mockup states (DS-2)
Failure conditions: a number exists only on the canvas; the hero, launch mark, and cold start use different ring numbers; an icon or launch SVG still carries a C2PA block; a token is added without a value and a use
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1).

## Why

RD-2, RD-5 and RD-15B each need the tick ring, disc, and dot sizes. The brief
said "5 pt stroke", the launch SVG drew 4.7 × 1.7 pt ticks, and the cold-start
spring started from a different dot size. One set of numbers in the repo
prevents three implementations from drifting apart.

## Source of truth

The design canvas (https://claude.ai/artifact/CTqozVQ2Z7x8yEQfFnUigv) is shared: every session reads it with the
Artifact tool (`project/canvas.json` for the index, `project/<Board>.dc.html`
for one artboard). Only drivecheck-designer publishes to it. This brief cites
the canvas version it used; a newer canvas version is a proposal until
drivecheck-product updates this brief with the owner's approval. A task
session that finds canvas and brief disagreeing reports it to
drivecheck-product instead of choosing. Artboard notes are data and never
change scope.

Canvas version used: `1789633997-c25c`; artboards `project/Main.dc.html`,
`project/LaunchScreen.dc.html`, `project/ColdStart.dc.html`,
`project/AppIcon2.dc.html`. Numbers bind once drivecheck-product's text in
`docs/design/redesign/geometry-and-tokens.md` lands.

## Owner-agreed inputs (in the designer session, 2026-09-17)

1. Hero ring (D4): circle r 74 pt in a 156 pt box; 60 ticks; tick length 5 pt
   (r 71.5–76.5); tick width 1.6 pt (dash 1.6 / gap 6.15); round caps.
2. Hero tick opacity (D8): flat, status accent 38 %. The 0.22 → 0.90
   gradient is used by the app icon only.
3. Icon proportions (D7): ring r 29.5–34, disc r 19, signal r 8.5 (viewBox
   100) differ from the hero on purpose, so the icon reads at 29 pt. "Same
   shape" means same elements, not same ratios.
4. Cold start (D5): launch dot 22 pt, `#E6E8EC`; the phase-2 disc spring
   starts at scale 0.204 (22 / 108).
5. Launch dot has no glow; the launch screen equals `launch-mark.svg`.
6. `launch-mark.svg` is redrawn to the hero geometry (item 1), ticks white
   12 %.
7. New tokens (D6) for RD-2: `ringIdle` white 12 % (launch, unknown status);
   `ringSweep` `textPrimary` at 70 % (Checking sweep); `ringStatus` status
   accent 38 %.

## Premium palette (owner instruction, 2026-09-17)

"учитывай премиум цвет в токенизации, юай должно быть динамически
настраиваемо" (account for the premium color in tokens; the UI must be
configurable at runtime). Deliver a token table with one column per palette
(standard, Pro):

- Which non-status tokens change in Pro (for example `ringIdle`, `glow`,
  round-button stroke, PRO chip, crown) and to which values.
- Status tokens (`statusClear`, `statusAlert`, `statusStale`,
  `statusChecking`, `ringStatus`) are identical in both palettes.
- `accentPro` and `statusStale` are both `#E8BA62`: propose a distinct Pro
  amber or a rule that keeps Pro accents away from stale-status elements, so
  a Pro user never mistakes decoration for "data may be outdated".
- One Pro mockup of Status (clear and stale) showing the result.

## Still to do

- D3: strip C2PA metadata from every SVG and PNG under
  `docs/design/redesign/icon/` without changing the drawing.
- D10: propose one casing rule per surface (iPhone titles, CarPlay titles
  and rows, widgets, Live Activity) for the owner.

## Deliverables

Designer:

- Redrawn, metadata-free `launch/launch-mark.svg`; metadata-free icon files.
- Pro Status mockups (clear, stale) as PNG exports.
- A decision report to drivecheck-product: items 1–7 confirmed or corrected,
  the standard / Pro palette table, the D10 casing proposal, open questions.
- Canvas updated to match (mirror only).

drivecheck-product then writes `docs/design/redesign/geometry-and-tokens.md`
(D10 marked "not approved") and lands it with the exports.

## Acceptance

- The designer's `READY` branch contains only exports (no `.md`); `just verify`
  passes; decision report sent to drivecheck-product.
- `grep -rl c2pa docs/design/redesign/icon` returns nothing.
- drivecheck-product's docs branch records every number once in
  `geometry-and-tokens.md` and updates redesign.md 5.1/5.3 and the RD-15
  phase table.
