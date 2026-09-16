# Testing strategy

Drive Check uses **Swift Testing** (`@Test`) in the `RegionalCheckTests` target. UI is not automated; behavior lives in testable types with protocol seams and fakes.

## TDD workflow

Default order for logic changes:

1. **Red** — write a test for behavior that does not exist yet (or still fails).
2. **Verify red** — run tests; failure must match the intended gap, not a typo.
3. **Green** — minimal implementation.
4. **Refactor** — cleanup with tests still green.

Each plan commit ships **atomically green** (test + code together). The red step is reported in the agent handoff, not left broken on `main`.

### Where TDD applies

Domain and service logic: regions, refresh policy, StoreKit entitlement handling, paywall view model, provider parsing, Live Activity policy helpers, CarPlay connection gate.

### Where TDD does not apply

Pure UI layout, `#if DEBUG` gating, asset-only changes, privacy manifests, documentation. Those rely on `just verify` and manual checks.

### UI-adjacent extraction

When UI must change, extract the decision into a testable type first (e.g. `CarPlayConnectionGate`, `RefreshPolicy`, `LiveActivityLifecyclePolicy`).

## What we cover

| Area | Examples |
|------|----------|
| Region domain | `AlertRegion`, resolver, tracker hysteresis, store migration |
| Data / network | Fixture decode, 429/retry, non-JSON/offline errors, freshness |
| Subscriptions | Entitlement verification outcomes, restore empty vs failed, purchase results, entitlement stream |
| Live Activity | Lifecycle policy, serial pipeline ordering, stale date |
| Presentation helpers | Paywall view model dismiss/busy state, status copy |

## Test layers

| Layer | What it drives | Examples |
|-------|----------------|----------|
| Snapshot | SwiftUI previews rendered by Prefire (`PreviewTests`) | Home, Status, Main tabs, Regions, Paywall, Map card, Onboarding |
| Scenario | User flows through the real composition root (`AppContainer.fixture`) | `AppScenarioTests`, `CarPlayTemplateBuilderTests` |
| ViewModel | One feature's state machine with injected fakes | `MapViewModelTests`, `RegionsViewModelTests` |
| Pure logic | Domain rules, parsing, policies | `RefreshPolicyTests`, `RegionTrackerTests` |

## Deterministic app graph

`AppContainer.fixture(region:network:isPro:hasCachedSnapshot:defaultsSuite:)` (DEBUG only) builds the same graph as the app with `FixtureNetwork` (in-memory Ubilling feed and map image, switchable offline, request counters), a fixed clock (`AppContainer.fixtureNow`), an isolated `UserDefaults` suite, and the deterministic status-details summarizer. Previews use it so snapshots never touch live network, wall clock, or shared persisted state. Scenario tests pass a unique `defaultsSuite` so parallel tests stay isolated.

The unit-test host launches inert (`HostProcess.isUnitTesting` renders an empty scene and never builds the live container), so coverage and side effects belong to the tests.

## Snapshot tests

- Previews listed in `.prefire.yml` `sources` become snapshot tests; baselines live in `RegionalCheckTests/__Snapshots__/`.
- A preview is snapshot-ready only if it renders through `AppContainer.fixture` or static inputs.
- `RegionalCheckTests/Support/PreviewTests.stencil` is Prefire's template plus a 0.3 s settle delay so fixture-backed async state (map image, status details, refresh) finishes before capture. Re-sync it when upgrading Prefire.
- Baselines are pixel-exact for the iPhone 17 simulator on iOS 26; re-record after intentional UI changes by deleting the affected PNGs and running the `Snapshots` test plan (`-testPlan Snapshots`). The scheme default plan `TestPlans/RegionalCheck.xctestplan` skips `PreviewTests`, so `just test` and pre-push stay fast; `-only-testing` cannot re-add tests a plan skips.

## What we deliberately skip

- CarPlay scene lifecycle (`CarPlaySceneDelegate`) in simulator automation; template content is tested through `CarPlayTemplateBuilder`
- Real StoreKit or ActivityKit in unit tests (injected fakes instead)
- Multi-surface flows across widgets, Live Activity, and CarPlay (manual TestFlight / device)

## Coverage map (by test file)

| File | Focus |
|------|--------|
| `AlertRegionTests`, `AlertRegionResolverTests` | Canonical regions and geocoding normalization |
| `RegionTrackerTests`, `RegionSelectionFollowTests` | Hysteresis, manual pin |
| `RefreshPolicyTests`, `DataFreshnessTests`, `UbillingRetryTests` | Adaptive polling, retries, stale detection |
| `AerialAlertsFixtureTests`, `AlertsSnapshotTests`, `SmokeTests` | Provider parsing and failure modes |
| `SubscriptionTests`, `PaywallViewModelTests`, `EntitlementStreamTests` | StoreKit seams, paywall UX |
| `LiveActivityLifecycleTests`, `LiveActivityStaleDateTests` | Activity lifecycle without ActivityKit |
| `CarPlayConnectionTests` | Idempotent CarPlay connect/disconnect |
| `StoreKitTransactionFinishTests` | Transaction finish on verified/unverified updates |

## Fake rules

1. **Purchase fakes grant entitlement only on `.success`.** Cancelled, pending, and failed purchases must not flip `isPro`.
2. **Subscription fakes expose a controllable update stream** (`FakeSubscriptionService.push`) for grant/revoke tests.
3. **HTTP fakes** (`MockHTTPClient`, `SequencingHTTPClient`) simulate status codes, body shape, and `URLError` — no live network in unit tests.
4. **No test doubles of production types** — removed `RecordingLiveActivityController` tests that asserted on a parallel implementation instead of `LiveActivityController`.

## Determinism

- **Clocks** — inject `now` / fixed dates where timing matters (`DataFreshness`, provider `fetchedAt`).
- **No `sleep` in assertions** — except short polling helpers waiting for async stream delivery; prefer injected streams. A fixed pair of `Task.yield()` is not a drain: under main-actor contention a follow-up action is dropped as "still loading" and the next spy wait hangs (`StatusDetailsTestSupport.drain`).
- **Isolated `UserDefaults`** — `TestDefaults.withTemporaryDefaults` and suite-scoped `EntitlementCache` / `RegionStore`.
- **Locale** — `TestLocale.english` wraps tests that assert on localized copy so they pass on non-English simulator hosts.
- **`SubscriptionManager` preferences** — injected `UserDefaults`, not `UserDefaults.standard`.

## Running tests

```bash
just test
```

Or Xcode scheme **RegionalCheck** on simulator **iPhone 17**.

Technical DoD: `just verify` (format, lint, build, test). Defect-first review runs on the diff before release commits.

## Continuous integration

Each CI system has one job, so tests never run twice:

| System | Trigger | Responsibility |
|--------|---------|----------------|
| GitHub Actions (`.github/workflows/tests.yml`) | Push to `main`, pull requests | Unit and snapshot tests as parallel jobs, merged llvm-cov coverage, SonarQube Cloud scan |
| Xcode Cloud (workflow "AppStore connect + TestFlight") | Push to `testflight` | Archive, App Store Connect signing, TestFlight internal testing; no Test action |
| GitHub Actions (`.github/workflows/release.yml`) | Push of a `vMAJOR.MINOR.PATCH` tag | Checks the tag, then fast-forwards `release` |
| Xcode Cloud (workflow "Release") | Push to `release` | Archive of the tagged version for App Store submission and TestFlight |

The `testflight` branch is moved only by the `promote-testflight` job, after unit tests, snapshot tests, and the Sonar scan succeed for a push to `main`, and only by fast-forward. Never push to it by hand: it is the record of commits verified for TestFlight.

Releases follow the versioning rules in `AGENTS.md`: push an annotated tag `vMAJOR.MINOR.PATCH` on a `main` commit whose `MARKETING_VERSION` matches. `scripts/promote-release.sh` rejects lightweight tags, version mismatches, and commits outside `main`, waits (up to 45 minutes) until the commit reaches `testflight`, then fast-forwards `release`. A tag can be pushed right after its commit; rerun the Release workflow manually with the tag if the checks took longer. `release` is never moved by hand either.

Why the split: Xcode Cloud manages signing and distribution without certificates in repository secrets, while GitHub Actions gives free macOS minutes for this public repository, parallel jobs, and the coverage files Sonar needs. Rejected: tests in both (duplicate runs, double failure signals) and everything in one system (Xcode Cloud cannot export coverage to Sonar comfortably; GitHub Actions would need signing secrets).

Xcode Cloud uses the latest Xcode release and GitHub Actions pins `DEVELOPER_DIR`; bump the pin when the supported Xcode moves.
