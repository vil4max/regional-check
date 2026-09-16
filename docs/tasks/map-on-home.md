# Agent Task — Move the Map onto the Home Screen

## Role and backlog context

Backlog item **MAP-2**, the **3.0 release candidate** (`docs/planning/backlog.md`), superseding
MAP-1's tab presentation (`docs/tasks/map-tab.md`).

- Product: Drive Check
- Repository: `regional-check`
- Worktree / branch: assigned at implementation time

Work only inside the assigned worktree. This task relocates the existing upstream
raster alert map from its own phone tab onto a compact card at the top of the Home
screen. It adds no new data, no polling, and no CarPlay surface.

## Required reading

Before editing, read these files in order:

1. `AGENTS.md`
2. `docs/engineering/agent-workflow.md`
3. `Tooling/runtime.yml`
4. `docs/engineering/architecture.md`
5. `docs/core.md` (amended for MAP-2: map lives on Home, not its own tab)
6. `docs/requirements/surfaces-and-pro-gating.md`
7. `docs/tasks/map-tab.md` (superseded behavior contract — MAP-2 preserves it)
8. `RegionalCheck/Views/MainTabView.swift`, `HomeView.swift`, `StatusView.swift`
9. This task contract

Repository instructions are authoritative. If this contract conflicts with them, stop
and report the conflict.

## Objective

Remove the standalone `Map` tab from `MainTabView` and embed the same map behavior as
a compact card at the top of `HomeView`'s `StatusView`, above the alert hero. Two tabs
remain: **Home** (Status + Map card) and **Regions**.

## Owner rulings (baked in, not to be re-decided)

1. Two tabs remain; the map is not a navigation destination, not a sheet — it renders
   inline at the top of Home.
2. The card is compact and fixed-height (~200pt), rounded, `ultraThinMaterial`
   background — matching the existing notice-banner card style in `MainTabView`, not
   a full-bleed banner. This preserves the charter's "one glance at alert state"
   principle: the map supports the glance, it does not compete with it.
3. All MAP-1 behavior carries over unchanged: fetch-on-appear + manual refresh only
   (no polling, no prefetch), image fetch time as the only timestamp (never
   `checkedAt`), VoiceOver label generated from the current snapshot, light/dark
   variant mapping, free on all surfaces, upstream render unmodified.
4. `MapViewModel` is unchanged — it was already tab-agnostic, owned by
   `AppContainer.mapViewModel`.

## Authorization and boundaries

You are authorized to inspect repository files and Git state, modify files required
for this feature and its tests, run `just doctor`, focused Runtime checks, and
`just verify`, and format only files within the feature diff.

You must not:

- add dependencies (no map SDK, no image pipeline library);
- poll, prefetch, or refresh the image from any path except card-appear and its own
  refresh button;
- use a WebView;
- crop, mask, or reinterpret the upstream render;
- add an entitlement or paywall check to the map card;
- touch CarPlay templates, delegates, or builders;
- change JSON fetch, persist, polling, or retry behavior;
- silently fix unrelated defects.

## Mandatory research phase

Before coding:

1. Inspect `MainTabView.Tab`, `StatusView`'s content `VStack` layout and its existing
   card/banner styling (region-change notice), and the old `MapView`'s content for
   reuse.
2. Confirm no other call site depends on the `Map` tab or the `MapView` type
   (screenshot automation, CarPlay, widgets, deep links).
3. Confirm `MapViewModel` needs no changes.
4. Run `git status --short --branch` and confirm the worktree contains no unexpected
   changes.

## Architecture invariants

```text
HomeView
    │
    ▼
StatusView (mapViewModel: MapViewModel?)
    │
    ├──► MapCardView (compact card, top of layout)
    │        │
    │        └──► MapViewModel (unchanged: card-appear load + manual refresh, no timer)
    │
    └──► existing StatusHeroView / details / refresh instrument cluster (unchanged)

MainTabView.Tab: .status, .regions   (⨯ .map removed)
```

- No new network layer; `MapViewModel` is reused as-is.
- Views do not access persistence or networking directly (unchanged rule).
- `StatusView.mapViewModel` is optional so previews/tests that don't need the map
  card can omit it.

## Required behavior

- Home screen shows the map card above the alert hero on first appearance; card
  loads the image on its own appear plus an explicit manual refresh only.
- Leaving and returning to Home reloads only if no image is cached for the session.
- Dark appearance requests the dark raster variant; light requests the default.
- Accessibility label regenerates from the latest snapshot whenever the snapshot
  changes.
- Free for all users; no Pro gating, no badge, no upsell on the card.
- `MainTabView` shows exactly two tabs: Home, Regions. No residual `.map` case,
  `tab.map` string catalog key, or `MapView` type in the codebase.

## Required test scenarios

Existing `MapViewModelTests.swift` and `MapImageSourceTests.swift` continue to cover
the ViewModel and URL/variant logic unchanged (no new ViewModel behavior was added,
so no new test scenarios are required there). Confirm via `just verify` that:

1. Existing tab selection, onboarding, paywall, and region-notice behavior do not
   regress with the `Map` tab removed.
2. Prefire-generated snapshot tests (`RegionalCheckTests/__Snapshots__`) are
   regenerated for `HomeView`, `MainTabView`, and `StatusView` baselines, and a new
   `MapCardView` baseline replaces the old `MapView` one; all are visually reviewed.

No live network in unit tests.

## Acceptance criteria

- Map card shows the upstream image on demand with correct theme variant, fetch-time
  stamp, manual refresh, and spoken snapshot-derived label, at the top of Home.
- Zero polling: image loads only on card-appear (when empty) and manual refresh.
- Upstream render unmodified; image age never presented as snapshot age.
- CarPlay, JSON flow, polling, entitlement, and the Regions tab unchanged.
- `MainTabView` has exactly two tabs.
- `just verify` succeeds, or an exact environmental/product blocker is reported.
- The Git diff contains only feature-related production code, localization, docs,
  and test/snapshot changes.

## Failure conditions

The task fails if any polling/prefetch path exists; a WebView is introduced; the
render is cropped or reinterpreted; snapshot `checkedAt` is shown as image age; any
paywall/entitlement check gates the card; CarPlay changes; JSON flow changes; a map
SDK or image dependency is added; the Map tab or `MapView` type still exists after
the change; unrelated changes appear; or commands are claimed without evidence.

## Completion procedure

1. Inspect final `git diff` and `git status`.
2. Run the smallest focused checks useful during development.
3. Run `just verify` once for final technical verification.
4. Commit per the repository's atomic-commit convention (feature commit separate
   from any release/version-bump commit).
5. Do not push and do not create a Git tag (release actions require separate owner
   authorization).

## Required final report

```markdown
# Agent Result

## Outcome
COMPLETED | BLOCKED_CORRECTLY | FAILED

## Summary
What changed or why implementation stopped.

## Research findings
Existing flow, relevant ownership boundaries, and evidence used.

## Files changed
Each file and why it changed.

## Architecture decisions
Decisions made, alternatives rejected, and how invariants were preserved.

## Tests added or changed
Scenarios covered and material gaps (including the manual snapshot review result).

## Commands executed
Exact commands, including failed commands.

## Verification results
Pass/fail result for each check. Do not summarize an unexecuted command as passing.

## Risks
Residual correctness, network, accessibility, or review risks.

## Open questions
Only unresolved decisions requiring human input. Write `None` if there are none.
```

The report will be compared with the actual Git diff and command evidence. Accuracy
and transparency matter more than presenting the work as successful.
