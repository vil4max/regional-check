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
- The CI `Snapshot tests` job is advisory: its `Run tests` step is
  `continue-on-error: true`, and the runner silently records a baseline that is
  missing. On 1e9e59f it reported 10 of 17 preview tests failing and still
  concluded green. Nothing mechanical catches baseline drift: the branch rule
  below, the integrator's pre-landing check (`agent-workflow.md`), and a local
  `-testPlan Snapshots` run are the only guards. Read the job's log or its
  `snapshot-test-results` artifact, never its conclusion.
- Those 10 failures were not Mac-versus-runner pixel noise, which is what the
  workflow comment assumes. Three previews had no baseline at all. Five were
  recorded while `AppContainer.fixture()` still built a real `LocationManager()`
  (before 18db4ad), so they baked in whatever CoreLocation permission that
  machine's simulator held: a baseline taken on a Mac that had denied location
  contains the `location.access.denied` block, and a fresh runner at
  `.notDetermined` renders without it. Corroboration: of the fixture-backed
  previews, the ones whose render graph touches location failed and `Paywall`,
  which takes only `.subscription`, passed. **A re-record is only valid at or
  after 18db4ad**; earlier ones re-bake the machine-specific state.
- Any baseline that shows a wall-clock time is only portable if the test plan
  pins the environment. `StatusView` renders `checkedAt.formatted(date:
  .omitted, time: .shortened)`, which reads `TimeZone.current`; the simulator
  inherits the host's zone, this machine is UTC+3, `tests.yml` sets no `TZ`,
  and the runner is UTC. So `Status-*`, `Home-*`, `Main-tabs` and
  `Map-card-loaded` differ by three hours between the Mac that recorded them
  and CI, permanently, whatever commit they were recorded at. `TestPlans/
  Snapshots.xctestplan` therefore pins `TZ` (and language and region) — a
  baseline recorded against an unpinned plan is not evidence of anything on CI.
  Pinning changes the content of every time-showing baseline, so it is done
  once and followed by a single coordinated re-record, never by each branch on
  its own.
- A full `-testPlan Snapshots` run **silently writes every baseline missing
  repo-wide**, not only the ones the branch is about. A worktree that runs the
  plan will pick up another task's un-recorded previews, so delete what the
  branch does not own before committing, and treat unexpected new PNGs in a
  diff as someone else's work rather than part of the change.
- `MapCardView`'s preview is deterministic only in light mode: `onAppear` also
  calls `setVariant(variant(for: colorScheme))`, which starts a real load when
  the variant actually changes. In light mode the variant is already `.day` and
  the call returns early. A dark-mode snapshot of that preview would switch to
  `.night`, start a network load and re-introduce the race the preloaded model
  removed — so a dark-mode variant of this preview needs the variant preset,
  not just the image.
- `Bottom-bar-checking` and `Map-card-loaded` were never drift: one rendered a
  live progress indicator and the other an async image load, both racing the
  stencil's 0.3 s settle delay, so re-recording could not fix either. Both are
  static now (5362dd9): a DEBUG `ProgressViewStyle` applied on the preview
  freezes the spinner, and a DEBUG `MapViewModel.preloaded(…)` factory renders
  the card with its image already set. `Bottom-bar-checking` asserts the round
  button's layout, size and checking treatment — the opacity, the disabled
  state, the ring in place of the arrow — and deliberately not the system
  spinner's artwork, because the ring is a stand-in.
- The four time-showing baselines recorded before the pin — `Home-alert-Pro`,
  `Home-all-clear`, `Main-tabs`, `Status-alert-Pro-secondary` — still fail on
  CI, which is what the pin was meant to expose: they were recorded at UTC+3
  against a runner that renders UTC. They are re-recorded in one coordinated
  pass after the last redesign screen lands, not branch by branch.
- A branch that changes any view listed in `.prefire.yml` `sources` lands its
  re-recorded baselines in the same branch. A green `just verify` is not
  evidence for the CI `Snapshot tests` job, because the default test plan skips
  `PreviewTests`: RD-7 restyled `RegionsView`, verified green, and left
  `Regions-iPhone-16.1.png` showing the pre-redesign screen. Re-record on a
  simulator reserved for tests, and check each PNG against the design it is
  supposed to prove before committing — a re-record must be the intended
  design, not whatever rendered.
- Baselines are pixel-exact for the iPhone 17 simulator on iOS 27 (`.prefire.yml` `required_os: 27`); re-record after intentional UI changes by deleting the affected PNGs and running the `Snapshots` test plan (`-testPlan Snapshots`). The scheme default plan `TestPlans/RegionalCheck.xctestplan` skips `PreviewTests`, so `just test` and pre-push stay fast; `-only-testing` cannot re-add tests a plan skips.

## What we deliberately skip

- CarPlay scene lifecycle (`CarPlaySceneDelegate`) in simulator automation. The
  boundary is exact: `CPInterfaceController` has no public initializer, so the
  scene-lifecycle methods (`templateApplicationScene(_:didConnect:)` and the
  rest) cannot be driven from a test at all. `CPTemplate` subtypes
  (`CPListTemplate`, `CPInformationTemplate`, `CPTabBarTemplate`, …) are
  constructible standalone, which is what `CarPlayTemplateBuilderTests`,
  `CarPlayDetailsBuilderTests` and `CarPlayMapBuilderTests` build directly. When
  a trigger inside the delegate is worth proving, extract the part that builds
  templates — it needs no live controller — rather than trying to fake the
  controller.
- Real StoreKit or ActivityKit in unit tests (injected fakes instead)
- Multi-surface flows across widgets, Live Activity, and CarPlay (manual TestFlight / device)

- A repeating animation is non-deterministic by construction: a snapshot
  catches it mid-cycle. `symbolEffect(.pulse/.rotate, options: .repeating)`, an
  indeterminate `ProgressView`, a rotating ring — each gets gated behind
  `!HostProcess.isUnitTesting` (the convention `AlternateIconManager` and
  `WidgetReloader` already follow) or a static stand-in applied on the preview.
  A branch that adds one to a `.prefire.yml` source without doing either is
  adding a flaky baseline, whatever its first run says. Three sessions reached
  this independently — the hero symbol, the tick ring, and the round button's
  spinner — before it was written down.

## A green test name is a claim

A test named for a requirement asserts that requirement or it is deleted.
`#expect(Bool(true))` under such a name is a placeholder, not a test: it passes
on a build where the behaviour is completely broken, and every later reader —
including whoever scopes a release regression — reads the name as coverage.
`CarPlayConnectionTests.periodicRefresh_survivesDuplicateCarPlayConnectDisconnect`
was exactly that for REQ-REFRESH-002's ref-counted timer: it called `begin`
twice and `end` twice and asserted a tautology, because the client count was
private. The answer to unassertable private state is a narrow read-only seam,
not a green placeholder.

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

## Measuring REQ coverage

`spec_trace.py` (kit skill `spec-pyramid`) matches a REQ ID by the ID string in
a test's name, so "uncovered" means "no test names this ID", never "no test
asserts this". About a dozen of this repo's uncovered IDs have passing tests
that simply do not cite them; treat a citation gap and a missing spec as
different work.

Run it against the tracked tree only:

```bash
python3 <kit>/spec_trace.py --tests "RegionalCheckTests/**/*.swift" --tests "Packages/**/*.swift"
```

Without those arguments the script globs the whole repository directory, and
this repo keeps agent worktrees in `.claude/worktrees/`, which its `SKIP_PARTS`
does not exclude. It then counts REQ citations from other sessions' **unlanded**
branches: on 2026-09-18 that read 17 of 32 covered where `main` had 10. A
coverage number taken from the repo root during parallel work is a number about
work that is not there.

## Continuous integration

Tests run only in GitHub Actions (`.github/workflows/tests.yml`): unit tests and snapshot tests as parallel jobs, merged llvm-cov coverage, and a SonarQube Cloud scan on every push to `main` and every pull request. Xcode Cloud only archives and distributes, from branches that CI moves after these checks pass. The full flow, branch rules, and release checklist are in [release-process.md](../operations/release-process.md) and [ADR 0010](../decisions/0010-gated-testflight-and-tag-releases.md).

Why tests live in GitHub Actions: free macOS minutes for this public repository, parallel jobs, and the coverage files Sonar needs. Xcode Cloud keeps signing and distribution without certificates in repository secrets.

GitHub Actions pins `DEVELOPER_DIR` while Xcode Cloud uses the latest Xcode release; bump the pin when the supported Xcode moves.
