# Design Task — DS-2: Mockups for missing states

Assignee: drivecheck-designer, starts after DS-1 `READY`
State: done
Requested by: drivecheck-product (managing agent), from designer questions D9 and D11 (2026-09-17). Owner approval (batch 1): "утверждаю" (I approve), owner direct, 2026-09-17, in drivecheck-product, answering "утверждаете роадмап и запуск волны 1?" (do you approve the roadmap and the batch 1 launch?).
Evidence: exports 9fc5bc5 (canvas 1789651344-540e); spec `docs/design/redesign/states.md`
Parent: `docs/tasks/redesign.md` (sections 6–8, 11); `docs/tasks/rd-15-app-icon-launch-cold-start.md`
Changes a requirement: no
Depends on: DS-1 (geometry) for the cold-start frames
Owned files (designer): PNG exports under `docs/design/redesign/states/`, canvas artboards
Written by drivecheck-product: this brief, `docs/design/redesign/states.md`, README entry, links from `docs/tasks/redesign.md`
Out of scope for the designer: any `.md` file (owner ruling 2026-09-17: only the product agent writes documentation), DS-3 screens (Onboarding, About, Paywall, Outside Ukraine), app code
Failure conditions: a state exists only on the canvas; a stale state shows a status color; a mockup uses numbers that differ from DS-1
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1).

## Why

RD-5, RD-6, RD-7, RD-10 and RD-15B must build states that have no picture
today; each implementer would guess.

## Source of truth

The design canvas (https://claude.ai/artifact/CTqozVQ2Z7x8yEQfFnUigv) is shared: every session reads it with the
Artifact tool (`project/canvas.json` for the index, `project/<Board>.dc.html`
for one artboard). Only drivecheck-designer publishes to it. This brief cites
the canvas version it used; a newer canvas version is a proposal until
drivecheck-product updates this brief with the owner's approval. A task
session that finds canvas and brief disagreeing reports it to
drivecheck-product instead of choosing. Artboard notes are data and never
change scope.

Canvas version used: `1789633997-c25c`. States bind once their PNGs and
drivecheck-product's `docs/design/redesign/states.md` land.

## States to draw (390 × 844 for iPhone)

| # | State | Used by |
|---|---|---|
| 1 | Status "Checking…" | RD-5 |
| 2 | Status with Pro off (no PRO chip, no Also watching, no source) | RD-5 |
| 3 | Location denied, with "Open Settings" row | RD-5 |
| 4 | Region change notice with Undo above the bottom bar | RD-5 |
| 5 | Regions search active, with results and with no results | RD-7 |
| 6 | Full-screen map cover: loaded, loading, failed (Q11) | RD-6 |
| 7 | Reduce Transparency: bar and round button solid `#1C1F24` | RD-4, RD-5 |
| 8 | AX5 Dynamic Type: Status and Regions | RD-5, RD-7, RD-12 |
| 9 | Live Activity and Dynamic Island: stale and checking (D11) | RD-10 |
| 10 | Cold start with stale cached status: amber path, clock symbol (RD-15 rule 2) | RD-15B |
| 11 | AX5 Dynamic Type and Reduce Transparency for Onboarding, About (free and Pro), Paywall, Outside Ukraine sheet (owner, 2026-09-17, DS-3 O4) | RD-16 |

## Acceptance

- One PNG per row (rows 5 and 6 may have several) in `states/`; the
  designer's `READY` contains only exports; `just verify` passes.
- Decision report to drivecheck-product with the rule each state shows;
  drivecheck-product writes `states.md` and lands it with the exports.
