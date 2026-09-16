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

## What we deliberately skip

- Snapshot / pixel tests
- CarPlay template rendering in simulator automation
- Real StoreKit or ActivityKit in unit tests (injected fakes instead)
- End-to-end multi-surface flows (manual TestFlight / device)

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
- **No `sleep` in assertions** — except short polling helpers waiting for async stream delivery; prefer injected streams.
- **Isolated `UserDefaults`** — `TestDefaults.withTemporaryDefaults` and suite-scoped `EntitlementCache` / `RegionStore`.
- **Locale** — `TestLocale.english` wraps tests that assert on localized copy so they pass on non-English simulator hosts.
- **`SubscriptionManager` preferences** — injected `UserDefaults`, not `UserDefaults.standard`.

## Running tests

```bash
just test
```

Or Xcode scheme **RegionalCheck** on simulator **iPhone 17**.

Technical DoD: `just verify` (format, lint, build, test). Defect-first review runs on the diff before release commits.
