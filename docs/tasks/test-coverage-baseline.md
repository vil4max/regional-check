# Agent Task — Honest Test Coverage Baseline

Assignee: unassigned
State: done
Evidence: TEST-1 shipped (`AppContainerFixture`, f4a9908)

## Role and backlog context

Backlog item **TEST-1** (`docs/planning/backlog.md`). Follows the 2026-09-16 coverage-by-layer
analysis of `RegionalCheck.app`, which found that app launch alone covered a third of the
target and that `DriveCheckKit` was missing from the report.

- Product: Drive Check
- Repository: `regional-check`

## Required reading

1. `AGENTS.md`
2. `docs/engineering/testing-strategy.md`
3. `docs/engineering/architecture.md`
4. `RegionalCheck/App/AppDelegate.swift`, `RegionalCheckApp.swift`, `AppContainer.swift`
5. `.prefire.yml`
6. This task contract

## Objective

Make coverage numbers mean what the tests do, then raise real coverage where it is cheapest:

1. The unit-test host launches inert: no live `AppContainer`, network, StoreKit, or polling.
2. Coverage of `DriveCheckKit` is measured (it runs from a dynamic package framework that
   `xccov` does not map to a target; measure with `llvm-cov` against the framework binary).
3. A deterministic, offline dependency graph (`AppContainer.fixture`) backs SwiftUI previews,
   so Prefire snapshots every main screen.
4. Scenario tests drive user flows through the real composition root with only network,
   clock, and storage replaced.
5. The largest remaining testable gaps get focused tests.

## Owner rulings

1. Production behavior does not change. New `AppContainer` parameters default to today's
   live dependencies; the fixture is `#if DEBUG` only.
2. The app target does not link Prefire. Snapshot timing is handled on the test side
   (custom Prefire template in `RegionalCheckTests/Support`).
3. Real StoreKit and ActivityKit stay out of unit tests, as the testing strategy already rules.
4. Unreferenced views (`StatusExplanationView`, `CountryOverviewSection`) are deleted after
   owner confirmation; `StatusDetailsView` keeps its own file.

## Architecture invariants

```text
Unit-test host:  RegionalCheckApp -> Color.clear   (AppDelegate.container never built)
App / CarPlay:   AppDelegate.container (lazy) -> AppContainer() live graph (unchanged)
Previews/tests:  AppContainer.fixture(...) -> same graph with FixtureNetwork,
                 fixed clock, isolated UserDefaults suite, deterministic summarizer
```

## Required test scenarios

- Launch shows cached status before any network.
- Appear + refresh reflects a new alarm on Home and persists it.
- Pinning a region in Regions switches Home status.
- Offline refresh keeps last known status, marks it stale, and recovers.
- Pro sees source and pinned secondary region; free user cannot pin.
- Map card loads once, fails offline, retries successfully.
- Status details summarize the selected region.
- CarPlay root and detail templates for quiet/nearby, alarm, offline, and Pro/free.
- Prefire snapshots: Home (all clear, alert Pro), Status (Pro secondary), Main tabs,
  Regions, Paywall, Map card (loaded), Outside Ukraine, Onboarding (2). The offline map
  card is covered by a scenario test: Prefire renders each preview twice and the first
  host's `onDisappear` cancels the load, so an error state cannot be captured.

## Acceptance criteria

- Test run with zero tests covers ~0% of `RegionalCheck.app` (was 33.3%).
- Coverage-by-layer report re-generated and compared against the pre-change baseline,
  including `DriveCheckKit`.
- All snapshot tests pass on repeat runs without re-recording.
- `just verify` succeeds, or an exact environmental blocker is reported.

## Failure conditions

Production behavior changes; Prefire is linked into the app target; a snapshot depends on
wall clock, live network, or shared persisted state; flaky waits are papered over with
retries instead of fixed; unrelated changes appear.
