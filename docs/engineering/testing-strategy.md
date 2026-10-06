# Testing strategy

Drive Check uses **Swift Testing** (`@Test`) in the `RegionalCheckTests` target. UI is not automated; behavior lives in testable types with protocol seams and fakes.

## TDD workflow

Default order for logic changes:

1. **Red** — write a test for behavior that does not exist yet (or still fails).
2. **Verify red** — run tests; failure must match the intended gap, not a typo.
3. **Green** — minimal implementation.
4. **Refactor** — cleanup with tests still green.

Each commit ships **atomically green** (test + code together); a red step is never left broken on `main`.

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
| ViewModel | One feature's state machine with injected fakes | `MapViewModelTests`, `RegionListViewModelTests` |
| Pure logic | Domain rules, parsing, policies | `RefreshPolicyTests`, `RegionTrackerTests` |

## Deterministic app graph

`AppContainer.fixture(region:network:isPro:hasCachedSnapshot:defaultsSuite:)` (DEBUG only) builds the same graph as the app with `FixtureNetwork` (in-memory Ubilling feed and map image, switchable offline, request counters), a fixed clock (`AppContainer.fixtureNow`), an isolated `UserDefaults` suite, and the deterministic status-details summarizer. Previews use it so snapshots never touch live network, wall clock, or shared persisted state. Scenario tests pass a unique `defaultsSuite` so parallel tests stay isolated.

The unit-test host launches inert (`HostProcess.isUnitTesting` renders an empty scene and never builds the live container), so coverage and side effects belong to the tests.

## Snapshot tests

- Previews listed in `.prefire.yml` `sources` become snapshot tests; baselines live in `RegionalCheckTests/__Snapshots__/`.
- A preview is snapshot-ready only if it renders through `AppContainer.fixture` or static inputs.
- `RegionalCheckTests/Support/PreviewTests.stencil` is Prefire's template plus a 0.3 s settle delay so fixture-backed async state (map image, status details, refresh) finishes before capture. Re-sync it when upgrading Prefire.
- The Snapshots plan reports pixel mismatches as a warning without failing the CI job, and a missing baseline is recorded silently. Nothing mechanical catches baseline drift except the rule below and a local `-testPlan Snapshots` run, so read the job's log or its `snapshot-test-results` artifact, never only its conclusion.
- **Baselines must not depend on the machine that recorded them.** `AppContainer.fixture()` must not build a real `LocationManager()`: a baseline recorded while it did contains whatever CoreLocation permission that simulator held (for example the `location.access.denied` block). A re-record is only valid at or after the commit that removed it (18db4ad).
- **Any baseline that shows a wall-clock time is only portable if the test plan pins the environment.** `StatusView` renders `checkedAt.formatted(date: .omitted, time: .shortened)`, which reads `TimeZone.current`, and the simulator inherits the host's zone. `TestPlans/Snapshots.xctestplan` therefore pins `TZ` (and language and region). Changing the pin changes every time-showing baseline, so it is followed by one coordinated re-record.
- A full `-testPlan Snapshots` run **silently writes every baseline missing repo-wide**, not only the ones a change is about. Delete what the change does not own before committing, and treat unexpected new PNGs in a diff as unrelated to the change.
- `MapCardView`'s preview is deterministic only in light mode: `onAppear` also calls `setVariant(variant(for: colorScheme))`, which starts a real load when the variant actually changes. A dark-mode snapshot of that preview needs the variant preset, not just the image.
- Previews that render a live progress indicator or an async image load race the stencil's settle delay, and re-recording cannot fix that. Make them static: a DEBUG `ProgressViewStyle` applied on the preview freezes the spinner, and a DEBUG `MapViewModel.preloaded(…)` factory renders the card with its image already set.
- A change to any view listed in `.prefire.yml` `sources` lands its re-recorded baselines in the same commit. A green `just verify` is not evidence for the CI Snapshots job, because the default test plan skips `PreviewTests`. Re-record on a simulator reserved for tests, and check each PNG against the design it is supposed to prove before committing: a re-record must be the intended design, not whatever rendered.
- **Target a simulator by name, never by UDID.** `just test` and `just verify` invoke `xcodebuild` by device *name*, and Xcode then runs the tests on an ephemeral copy (the logs say `Clone 1 of iPhone 17 - RegionalCheck`). A manual `xcodebuild -destination "platform=iOS Simulator,id=<UDID>"` pins that exact instance and clones nothing, so it boots, mutates and shuts down the shared device itself. Use `name=iPhone 17`, or a device created for the task.
- Baselines are pixel-exact for the iPhone 17 simulator on iOS 27 (`.prefire.yml` `required_os: 27`); re-record after intentional UI changes by deleting the affected PNGs and running the `Snapshots` test plan (`-testPlan Snapshots`). The scheme default plan `TestPlans/RegionalCheck.xctestplan` skips `PreviewTests`, so `just test` stays fast; `-only-testing` cannot re-add tests a plan skips.

## What we deliberately skip

- CarPlay scene lifecycle (`CarPlaySceneDelegate`) in simulator automation. The
  boundary is exact: `CPInterfaceController` has no public initializer, so the
  scene-lifecycle methods (`templateApplicationScene(_:didConnect:)` and the
  rest) cannot be driven from a test at all. `CPTemplate` subtypes
  (`CPListTemplate`, `CPInformationTemplate`, `CPTabBarTemplate`, …) are
  constructible standalone, which is what `CarPlayTemplateBuilderTests`
  and `CarPlayConnectionTests` build directly. When
  a trigger inside the delegate is worth proving, extract the part that builds
  templates — it needs no live controller — rather than trying to fake the
  controller.
- Real StoreKit or ActivityKit in unit tests (injected fakes instead)
- Multi-surface flows across widgets, Live Activity, and CarPlay (manual TestFlight / device)

## Pitfalls that make a baseline or a check misleading

- A pending system permission dialog re-surfaces on **every** relaunch and sits
  above the launch screen, so a launch-screen recording captures the dialog, not
  the launch mark. Dismiss it before recording. `xcrun simctl io <udid>
  recordVideo` reads the compositor's output, so it does capture what SpringBoard
  draws before the app process exists — start the recording before `simctl
  launch` to get that boundary in frame.
- "Pre-existing" is a claim about `origin/main`, so check it there. A baseline
  diff is pre-existing only if the checked-in reference already differed before
  the change touched anything. A system `Divider`'s hairline, for example, shifts
  sub-pixel between an ambient dark appearance and an explicitly forced one:
  imperceptible, real, and the change's to re-record.
- **A baseline's file name is a claim about what the image shows — open the
  PNG.** A full-screen "failed" baseline once contained a *loaded* map: the
  view's `onAppear` called `refresh()` whenever `imageData` was nil, the
  fixture network succeeds by default, so the real refresh beat the failed-state
  factory and the committed reference showed the success path under the failure
  name. The suite was green.
- **A preview must not let `onAppear` start work.** Inject the state the preview
  is named for and gate the trigger behind `!HostProcess.isUnitTesting`, the same
  seam the repeating animations use. `setVariant` beginning a real load,
  `appear()` fetching the map card's image and `refresh()` overwriting an
  injected failure state were all races of this kind.
- **Safe-area and overlay behaviour is verified on a running app, never on a
  baseline.** A preview has no home indicator and shorter content than a real
  list, so a bar's distance from the bottom edge and whether text reads through
  a fade are both invisible to the suite. Run the app, on a device with a
  home indicator and one without, with content long enough to reach the bar.
- A preview paints its own background. One that relies on the ambient canvas
  has a baseline encoding the host's default, which changes whenever anything
  upstream changes the color scheme: the diff is then 36–55 % of the
  pixels with the content itself byte-identical. Give every preview an explicit
  `RedesignColors.background` (or the surface it is meant to sit on), so its
  baseline asserts the app's own colors and nothing else.
- A repeating animation is non-deterministic by construction: a snapshot
  catches it mid-cycle. `symbolEffect(.pulse/.rotate, options: .repeating)`, an
  indeterminate `ProgressView`, a rotating ring — each gets gated behind
  `!HostProcess.isUnitTesting` (the convention `AlternateIconManager` and
  `WidgetReloader` already follow) or a static stand-in applied on the preview.
  Adding one to a `.prefire.yml` source without doing either adds a flaky
  baseline, whatever its first run says.

## A check that cannot fail is not a check

Several green signals have turned out to say nothing: a CI snapshot job that
continues on error and silently records a missing baseline, a snapshot plan with
no pinned timezone, a trace number that counted citations in unrelated
checkouts, and a test named for a requirement that asserted `#expect(Bool(true))`.
Each was a check whose failure mode is silence.

So: read a check by its evidence, not its verdict. A job's log rather than its
conclusion, a coverage number with its scope stated, a test by what it asserts,
an environment by what it pins. When a check cannot fail, say so where it is
configured — and when you make one honest, expect it to go red the first time,
which is the point.

## A green test name is a claim

A test named for a requirement asserts that requirement or it is deleted.
`#expect(Bool(true))` under such a name is a placeholder, not a test: it passes
on a build where the behaviour is completely broken, and every later reader
reads the name as coverage. `CarPlayConnectionTests.periodicRefresh_survivesDuplicateCarPlayConnectDisconnect`
was exactly that for REQ-REFRESH-002's ref-counted timer: it called `begin`
twice and `end` twice and asserted a tautology, because the client count was
private. The answer to unassertable private state is a narrow read-only seam,
not a green placeholder.

A test that exists to catch one specific failure names that failure in its
**commit body**, with the mutation that proves it — "dropped the
`periodicRefreshClients == 0` guard, and the assertion after the first `end()`
caught it" (fd6d0ff), "forced `desired` to `proIconName`" (b50124d). `git log`
on the file is where someone about to simplify a guard will actually look.

A REQ ID belongs in a test's **name**, nowhere else. Not in a `MARK:` over a
group of tests, and not in prose explaining a different test: a group comment
can drift to cover something else while the comment stands. An uncited test
**understates** coverage, so the cost is a wasted look, while a mis-citation
**overstates** it and points the next reader at tests that prove something else.

Cite a SHA only once it is on `origin/main`. Until then every rebase moves it,
and a pre-rebase SHA resolves in the author's checkout while giving everyone
else `bad object`.

## Coverage map (by test file)

| File | Focus |
|------|--------|
| `AlertRegionTests`, `AlertRegionResolverTests` | Canonical regions and geocoding normalization |
| `RegionTrackerTests`, `RegionSelectionFollowTests` | Hysteresis, the vestigial follow-location flag, region change notice |
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
4. **No test doubles of production types** — tests assert on `LiveActivityController`, not on a parallel recording implementation.

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

Technical Definition of Done: `just verify` (requirement trace, format, lint, build, test).

## Measuring REQ coverage

```bash
just trace                                  # approved requirements must be cited by a tracked test
just trace --results <bundle.xcresult>      # …and the citing tests must have run and passed
```

`just verify` runs the first form before the build and test gate. It runs first
on purpose: it needs no simulator, and a trace failure must stop `verify` early.

What each form establishes:

- Without `--results`, "covered" means a tracked test file cites the ID, never
  "a test asserts this". A citation gap and a missing spec are different work.
- With `--results`, a requirement is `passed` only if a test case that cites it
  ran and passed in that bundle; `failed` if any citing case failed; `not_run`
  if no executed case cites it. A test tagged only by a `// REQ-…` or `///`
  comment cannot be joined to a result and reports `not_run`: put the ID in the
  `@Test("REQ-…")` display name.
- `--results` is not part of `just verify`: taking "the newest bundle" from
  DerivedData could read another checkout's or a partial run's results, so the
  bundle is passed explicitly.
- Only `Status: Approved` requirements count as gaps; the rest are listed as
  `unapproved`.

The trace tool is an external checker, resolved from a configured checkout
(`scripts/spec-trace.sh`). Where none is configured the script exits with an
error that names the missing setting, rather than passing silently, per "A check
that cannot fail is not a check" above. The trace is limited to tracked test
globs, so citations in untracked or unlanded files do not count.

Wiring contract: `scripts/tests/spec-trace-contract.sh`.
Exception: when `CI=true` and no trace tools root is configured, the gate continues with `TRACE NOT CHECKED:` on stderr and in `GITHUB_STEP_SUMMARY` when set; local runs still fail without a root, and a configured root with missing tools fails even in CI.

## Continuous integration

Tests run only in GitHub Actions (`.github/workflows/tests.yml`): the verify gate, the Snapshots plan, merged llvm-cov coverage, and a SonarQube Cloud scan on every push to `main` and every pull request. Xcode Cloud only archives and distributes, from branches that CI moves after these checks pass. The full flow, branch rules, and release checklist are in [release-process.md](../operations/release-process.md) and [ADR 0013](../decisions/0013-one-build-pipeline-or-two.md).

Why tests live in GitHub Actions: free macOS minutes for this public repository, parallel jobs, and the coverage files Sonar needs. Xcode Cloud keeps signing and distribution without certificates in repository secrets.

GitHub Actions pins `DEVELOPER_DIR` while Xcode Cloud uses the latest Xcode release; bump the pin when the supported Xcode moves.
