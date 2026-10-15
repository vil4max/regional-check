# Backlog run: plan and progress

Working file for finishing the backlog that started on 2026-10-15. A new session resumes from
here: read the plan, check `git log` against the "Done" list, and continue with the first open
group. Delete this file when the backlog is empty.

## Scope and order

1. Baseline gate on the untouched tree.
2. Record the owner's decision that Pro is a cosmetic bundle (ADR 0016) and park PRO-VIS-1/2.
3. Verify the unverified audit findings of 2026-10-10 against the code; fix the confirmed ones
   in groups, each ending green in one commit; record every rejection with a one-line reason
   in [audit-2026-10-10-findings.md](audit-2026-10-10-findings.md).
4. Remaining in-scope backlog items (LOCATION-PAUSE, GEOCODE-TIMEOUT, FEED-26-KEYS, ARCH-LOWS,
   LINT-BASELINE, PRO-COSMETIC).

Out of scope without the owner: new requirements, App Store Connect actions, product IDs,
prices, releases and `v` tags.

## Owner decisions for PRO-COSMETIC (2026-10-15)

The sheet opens from a restored crown in the Status toolbar and from a row in Details. The local
StoreKit configuration uses `regioncheck.pro.cosmetic` at 0.99 (placeholders until the owner
approves an App Store Connect step). Owners switch the Pro icon on or off in the sheet.

## Progress

| Group | State | Commit |
|-------|-------|--------|
| Baseline gate | PASS, 416 tests | on `eaa9260` |
| Cosmetic Pro decision | done | `130df44` |
| Audit verification | done, 121 findings | `24f46d9` |
| G1 privacy | done | `392eeef` |
| G2 small correctness | done | `41c3f11` |
| G3 rate-limit window (RATE-LIMIT-WINDOW) | done | `be725b7` |
| G4 region tracking (REGION-GEOCODE-OVERLAP, REGION-FIX-DROP) | done | `12bb113` |
| G7 docs and repository hygiene | done | `9ea2d11`..`8e10a7f` |
| G5 dead code | done | up to `81f47b1` |
| G6 test isolation | done, reviewed | `a68eac4`..`9e4c377` |
| PRO-LOWS | done | `7ca684b` |
| G8 status presentation and accessibility | done, reviewed (APPROVE) | up to `5df0d3b` |
| G9 feed and geocoding (FEED-26-KEYS, GEOCODE-TIMEOUT, LOCATION-PAUSE) | done | `3962781`..`21b6b03` |
| PRO-COSMETIC | done (ASC steps are the owner's) | `aa39edf` |
| Review repairs (retro review of G1–G4, review of G9) | done | `5c1ef98` |
| G10-A Live Activity seam | done, reviewed (APPROVE) | `ec309e2`..`8b9803e` |
| LA-DUP-UPDATE | done | see `git log` |
| G10-D test targets (workspace, owner-approved), baseline writer, protocol placement | done, reviewed | up to `5924aea` |
| G10-B status refresh loop, Kit refresh policy, Settings injection, G8 lows | in progress (subagent worktree) | |
| G10-C CarPlay seams, folder, comments, REQ retags, ADR 0015 | in progress (subagent worktree) | |
| LINT-BASELINE burn-down | 34 → 6 entries; left: StatusController, DetailsView, StatusHeroGraphic (G10-B), CarPlayRefreshCoordinator (G10-C), AppContainer init and AlertStatusAnswerBuilderTests (after B and C) | |

Every group from here gets an independent review before its commit (orchestrator, 2026-10-15).

