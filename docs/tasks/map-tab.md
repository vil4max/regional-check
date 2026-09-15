# Agent Task — Ukraine Map Tab (Upstream Raster)

## Role and backlog context

Backlog item **MAP-1**, the **2.9 release candidate** (`docs/backlog.md`).

- Product: Drive Check
- Repository: `regional-check`
- Worktree / branch: assigned at implementation time

Work only inside the assigned worktree. This task adds a third phone-companion tab showing the upstream Ubilling raster alert map, loaded on demand. It adds no new data, no polling, and no CarPlay surface.

## Required reading

Before editing, read these files in order:

1. `AGENTS.md`
2. `docs/agent-pilot-brief.md`
3. `Tooling/runtime.yml`
4. `docs/architecture.md`
5. `docs/product-charter.md` (map tab is an allowed phone-only companion surface as of 2026-09-15)
6. `docs/surfaces.md`
7. `docs/aerial-alerts-provider.md` (`?map=` parameter)
8. `RegionalCheck/Views/MainTabView.swift`
9. `Packages/DriveCheckKit/Sources/DriveCheckKit/AlertsSnapshot.swift`
10. This task contract

Repository instructions are authoritative. If this contract conflicts with them, stop and report the conflict.

## Objective

Add a `Map` tab to `MainTabView` (Status + Regions + Map) that displays the upstream alert map image:

- Image URL: `https://ubilling.net.ua/aerialalerts/?map=` with the theme-matched variant (`nightmode` for dark appearance, default for light; exact variant mapping is a pure, tested function).
- Loading: fetch on tab-appear plus an explicit manual refresh button. **No polling, no background fetch, no prefetch from other tabs.**
- Render with SwiftUI `AsyncImage`. No WebView.
- The tab shows the **image fetch time** as its age stamp, never the JSON snapshot `checkedAt`.
- VoiceOver: the image carries a generated accessibility label built from the current snapshot (`N regions in alert: <names>` or the all-clear equivalent), so the raster stays perceivable without geometries.

## Owner rulings (baked in, not to be re-decided)

1. Charter allows the map as a phone-only glanceable picture of the free signal, never navigation.
2. Upstream render accepted **as-is**: no cropping, no Crimea editing. The JSON feed carries no Crimea/Sevastopol keys; the tab makes no claim about that pixel beyond showing the upstream picture.
3. Age honesty: image fetch time is the only timestamp on the tab.
4. The map stays **free** on all surfaces; no entitlement check anywhere in this flow.

## Authorization and boundaries

You are authorized to inspect repository files and Git state, modify files required for this feature and its tests, run `just doctor`, focused Runtime checks, and `just verify`, and format only files within the feature diff.

You must not:

- commit, push, merge, rebase, stash, or change branches;
- modify unrelated files;
- add dependencies (no map SDK, no image pipeline library);
- poll, prefetch, or refresh the image from any path except tab-appear and the tab's own refresh button;
- use a WebView;
- crop, mask, or reinterpret the upstream render;
- add an entitlement or paywall check to the tab;
- touch CarPlay templates, delegates, or builders;
- change JSON fetch, persist, polling, or retry behavior;
- silently fix unrelated defects.

## Mandatory research phase

Before coding:

1. Inspect `MainTabView` tab construction, `Theme` colors/typography for the new tab, and the `tab.*` string-catalog pattern for the tab title.
2. Verify the exact `?map=` variant strings against `docs/aerial-alerts-provider.md` and decide the light/dark mapping.
3. Identify where the current snapshot is readable for the accessibility label without giving views direct persistence access (see architecture dependency rules).
4. Check the existing refresh-button and timestamp/freshness patterns to reuse (do not invent a second freshness policy).
5. Run `git status --short --branch` and confirm the worktree contains no unexpected changes.
6. Write a concise implementation plan in your working response before editing.

Proceed without another approval only if the plan stays within this contract. Otherwise stop with `BLOCKED_CORRECTLY`.

## Architecture invariants

```text
MainTabView (+ .map tab, declarative)
      |
      v
Map feature state (tab-appear load + manual refresh, no timer)
      |
      +---> AsyncImage (upstream raster, fire-and-forget load)
      |
      +---> accessibility label (pure builder over AlertsSnapshot)
      |
      +---> age stamp (image fetch time, existing formatting)
```

- No new network layer: the image load is a plain URL load owned by the tab's feature state; JSON snapshot flow is untouched.
- Pure helpers (URL/variant builder, accessibility-label builder) live in testable types per `docs/testing-strategy.md` UI-adjacent extraction.
- Views do not access persistence or networking directly; feature state is injected through the composition root like `RegionsViewModel`.

## Required behavior

- Third tab titled via `tab.map` catalog key (en/ru/uk) with a map-ish SF Symbol distinct from the existing tabs.
- First appearance loads the image; visible loading state while fetching; explicit error state with retry on failure (reuse existing copy patterns where possible).
- Manual refresh button reloads the image and updates the fetch-time stamp.
- Leaving and returning to the tab reloads only if no image is cached for the session (no timer-driven reloads ever).
- Dark appearance requests the dark raster variant; light requests the default.
- Accessibility label regenerates from the latest snapshot whenever the snapshot changes.
- Free for all users; no Pro gating, no badge, no upsell on the tab.

## Required test scenarios

Add deterministic Swift Testing coverage for:

1. URL builder maps light → default variant and dark → dark variant.
2. Accessibility-label builder: alarm snapshot lists alarmed region names with count; all-clear snapshot yields the clear string; empty snapshot yields a neutral unavailable string (never a crash).
3. Tab feature state starts idle, transitions loading → result/error, and retry re-issues exactly one load.
4. Snapshot change regenerates the label without triggering an image reload.
5. No timer, polling schedule, or background task is registered by the feature (assert by construction review + no polling API usage in the diff).
6. Existing tab selection, onboarding, paywall, and region-notice behavior do not regress.

No live network in unit tests. Locale-sensitive assertions follow the existing `TestLocale` pattern.

## Acceptance criteria

- Map tab shows the upstream image on demand with correct theme variant, fetch-time stamp, manual refresh, and spoken snapshot-derived label.
- Zero polling: image loads only on tab-appear (when empty) and manual refresh.
- Upstream render unmodified; image age never presented as snapshot age.
- CarPlay, JSON flow, polling, entitlement, and existing tabs unchanged.
- Manual checklist in the final report: light/dark render, airplane-mode error + retry, VoiceOver label readout.
- Focused tests cover the required scenarios.
- `just verify` succeeds, or an exact environmental/product blocker is reported.
- The Git diff contains only feature-related production code, localization, and tests.

## Failure conditions

The task fails if any polling/prefetch path exists; a WebView is introduced; the render is cropped or reinterpreted; snapshot `checkedAt` is shown as image age; any paywall/entitlement check gates the tab; CarPlay changes; JSON flow changes; a map SDK or image dependency is added; unrelated changes appear; or commands are claimed without evidence.

## Completion procedure

1. Inspect final `git diff` and `git status`.
2. Run the smallest focused checks useful during development.
3. Run `just verify` once for final technical verification.
4. Do not commit or push.
5. Return one final report using the exact structure below.

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
Scenarios covered and material gaps (including the manual map checklist result).

## Commands executed
Exact commands, including failed commands.

## Verification results
Pass/fail result for each check. Do not summarize an unexecuted command as passing.

## Risks
Residual correctness, network, accessibility, or review risks.

## Open questions
Only unresolved decisions requiring human input. Write `None` if there are none.
```

The report will be compared with the actual Git diff and command evidence. Accuracy and transparency matter more than presenting the work as successful.
