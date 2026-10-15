# Audit of 2026-10-10: verified findings

A read-only audit on 2026-10-10 produced 121 unverified findings for this repository (3 high, 68
medium, 50 low). On 2026-10-15 each one was checked against the code at `eaa9260`. This file
records the verdict and where each finding is handled. Verdicts: **C** confirmed, **P** partly
true (only the true part is acted on), **R** rejected, **D** duplicate of a backlog item or
another finding. "Group" names the work group in [progress.md](progress.md); a backlog ID means
the finding is handled as part of that item.

Groups: G1 privacy, G2 small correctness, G3 rate-limit window, G4 region tracking, G5 dead
code, G6 test isolation, G7 docs and repository hygiene, G8 status presentation and
accessibility, G9 feed and geocoding, G10 structural seams.

## App, data and AI (rc-core)

| ID | V | Finding (short) | Group / reason |
|----|---|-----------------|----------------|
| rc-core-01 | C | Two location forwarders cancel each other's geocode | G4, REGION-GEOCODE-OVERLAP |
| rc-core-02 | C | CarPlay render snapshot misses location-blocked and outside-Ukraine | G2 |
| rc-core-03 | C | Ukrainian model summaries always rejected (diacritic folding) | G2 |
| rc-core-04 | C | Summary validator matches counts by substring | G2 |
| rc-core-05 | C | `CarPlayStatusContent` and `statusDetails` are test-only | G5 |
| rc-core-06 | C | Test-only CarPlay headline and age helpers | G5 |
| rc-core-07 | C | Unused theme tokens and colorsets | G5 |
| rc-core-08 | C | Agent-loop residue after ADR 0009 | G5 |
| rc-core-09 | P | Freshness rules duplicated app/Kit; Low Power divergence is deliberate | G10 |
| rc-core-10 | C | CarPlay builder depends on concrete stores | ARCH-LOWS |
| rc-core-11 | C | Baselined sizes; file-wide lint disable without reason | G5 (disable), LINT-BASELINE |
| rc-core-12 | C | Unused `ageSeconds` forces a manual `==` | G5 |
| rc-core-13 | C | Untested fallback, normalizer and validator; weak hysteresis test | G2, G4 |
| rc-core-14 | C | Nearby-alerts line duplicated | G8 |
| rc-core-15 | C | Small dead members in location and region code | G5 |
| rc-core-16 | C | Live services reached through default parameters | G6 |
| rc-core-17 | C | Comments carry history and ticket IDs | G7 |
| rc-core-18 | C | Several types per file; shared protocol placement | ARCH-LOWS |
| rc-core-19 | C | Concatenated localized fragments; missing plural forms | G8 |
| rc-core-20 | C | Region tests poll with real sleeps | G4 |
| rc-core-21 | R | Live screenshot phases are deliberate: the offline fixture draws a placeholder map (`release/screenshots/README.md`) | — |
| rc-core-22 | C | Provider doc names expensive networks for 300 s | G7 |

## Views (rc-views)

| ID | V | Finding (short) | Group / reason |
|----|---|-----------------|----------------|
| rc-views-01 | C | Failed map load re-fetched on every reappearance | G2 |
| rc-views-02 | C | Stale glyph differs between Status and cold start | G8 |
| rc-views-03 | P | Status accent built in three places, not four | G8, ARCH-LOWS |
| rc-views-04 | C | REQ-LAUNCH tests exercise code the overlay never calls | G8 |
| rc-views-05 | D | `StatusController` god store | ARCH-LOWS, LINT-BASELINE |
| rc-views-06 | P | Hidden default environment provider; "most tests" overstated | G6 |
| rc-views-07 | C | Unread debug lines in `PaywallViewModel` | G5 |
| rc-views-08 | D | Baselined Views sizes | LINT-BASELINE |
| rc-views-09 | P | Region key logged publicly (coarse oblast key, also in `ExplanationTrace`) | G1 |
| rc-views-10 | C | Outside-Ukraine sheet clips under Dynamic Type | G8 |
| rc-views-11 | R | Placeholder entry with no claim | — |

## Platform: Kit, widgets, Live Activity, StoreKit (rc-platform)

| ID | V | Finding (short) | Group / reason |
|----|---|-----------------|----------------|
| rc-platform-01 | C | Geocoded city and area logged publicly (high) | G1 |
| rc-platform-02 | P | Scheduled widget poll ignores the 429 window; the manual intent may (REQ-REFRESH-005) | G3 |
| rc-platform-03 | C | `Retry-After` unbounded | G3, RATE-LIMIT-WINDOW |
| rc-platform-04 | C | Subscription defaults reach the real App Group in tests | G6 |
| rc-platform-05 | C | Phase wording and symbols differ across widget and Live Activity | G8 |
| rc-platform-06 | P | Duplicate timeline entry and control kind; package boundary part rejected (ADR 0006) | G5 |
| rc-platform-07 | C | `LiveActivityController` calls ActivityKit directly | G10, ARCH-LOWS |
| rc-platform-08 | C | Entitlement selection untested and reads `Date()` | G10 |
| rc-platform-09 | C | `SubscriptionManager` mixes purchase, persistence and icon sync | PRO-COSMETIC |
| rc-platform-10 | C | Privacy manifests lack the App Group reason 1C8F.1 | G1 |
| rc-platform-11 | C | Status words duplicated across catalogs; one dead key | G5, G8 |
| rc-platform-12 | D | Baselined Kit sizes | LINT-BASELINE |
| rc-platform-13 | C | Missing `Retry-After`, widget 429 and adjacency tests; real sleeps | G3 |
| rc-platform-14 | C | Dead widget tokens, unread Live Activity field | G5 |
| rc-platform-15 | C | History and stale comments | G7 |
| rc-platform-16 | C | Transaction listener retains `self`, starts late, never torn down | G2 |
| rc-platform-17 | C | Storefront logged publicly; setup hints in release logs | G1 |
| rc-platform-18 | C | Widget `Info.plist` pins an old version | G7 |
| rc-platform-19 | C | Source label matched by provider-name substrings | ARCH-LOWS |
| rc-platform-20 | P | Live Activity mapping is a static on the container (only one caller uses it directly) | G10 |
| rc-platform-21 | C | File and type naming | ARCH-LOWS |
| rc-platform-22 | C | Lock Screen view recomputes presentation; duplicated refresh button | G8 |
| rc-platform-23 | C | Control Center control conveys status by icon and tint only | G8 |
| rc-platform-24 | C | Unexplained `nonisolated(unsafe)`; racy test doubles | G6 |

## Architecture (rc-architecture)

| ID | V | Finding (short) | Group / reason |
|----|---|-----------------|----------------|
| rc-architecture-01 | D | Same as rc-platform-01 | G1 |
| rc-architecture-02 | C | `StatusController` god type (slice: fetch gate) | G10, ARCH-LOWS |
| rc-architecture-03 | C | Phase mapping duplicated across surfaces | G8 |
| rc-architecture-04 | C | Floor, intervals and staleness duplicated app/Kit | G10 |
| rc-architecture-05 | C | Extension snapshot writers bypass floor, window and control reload | G3 |
| rc-architecture-06 | C | Test-only CarPlay rules; vestigial revision chain | G5 |
| rc-architecture-07 | C | Live Activity content pushed from ten call sites | G10 |
| rc-architecture-08 | P | Concrete container is sanctioned by ADR 0008; Settings opener injection is the gap | ARCH-LOWS |
| rc-architecture-09 | R | Single Kit target with WidgetKit: ADR 0006 and ARCH-WIDGET-TOKENS chose this; no user-visible defect | — |
| rc-architecture-10 | C | 429 state split in four places; map raster ignores it | G3 |
| rc-architecture-11 | D | Cited file does not exist; restates the lint baseline | LINT-BASELINE |
| rc-architecture-12 | D | Same as rc-core-07 | G5 |
| rc-architecture-13 | C | ADR 0008 cited for a rule it lacks; protocol placement | ARCH-LOWS |
| rc-architecture-14 | D | Same as rc-core-08 | G5 |
| rc-architecture-15 | R | Hand-rolled observation loops are tested and correct; migrating to `Observations` is modernization, not a defect | — |
| rc-architecture-16 | P | Init-time migrations; the Live Activity preference on standard defaults is deliberate | G6 |
| rc-architecture-17 | C | Folders do not match roles | ARCH-LOWS |
| rc-architecture-18 | C | Production code branches on the test host | G10 |
| rc-architecture-19 | C | ADR 0008 prescribes `just verify` | G7 |

## Tests (rc-tests)

| ID | V | Finding (short) | Group / reason |
|----|---|-----------------|----------------|
| rc-tests-01 | D | Same as rc-platform-04 | G6 |
| rc-tests-02 | C | Legacy-key migration touches host standard defaults | G6 |
| rc-tests-03 | C | Hang helper spins after cancellation | G6 |
| rc-tests-04 | D | Same as rc-platform-07 | G10 |
| rc-tests-05 | C | Test locale mutates `AppleLanguages` | G6 |
| rc-tests-06 | P | Global state not restored in two suites (the preference test does restore) | G6 |
| rc-tests-07 | C | Tests that cannot fail for the behavior they name | G6, G10 |
| rc-tests-08 | P | Suites without `.timeLimit` (the gate has an execution allowance) | G6 |
| rc-tests-09 | C | Ten polling helpers, two unbounded | G6 |
| rc-tests-10 | C | Racy `@unchecked Sendable` doubles | G6 |
| rc-tests-11 | C | Refresh loop and power restart untested | G10 |
| rc-tests-12 | C | CarPlay connect and disconnect untested | G10 |
| rc-tests-13 | D | Same as rc-platform-08 | G10 |
| rc-tests-14 | C | CarPlay 429, in-flight join and `Retry-After` inputs untested | G3 |
| rc-tests-15 | C | Coverage layer map stale | G7 |
| rc-tests-16 | D | Baselined test sizes | LINT-BASELINE |
| rc-tests-17 | C | A real-looking personal name used as fixture data | G1 |
| rc-tests-18 | D | Same as rc-views-06 | G6 |
| rc-tests-19 | P | Three catalog parsers; `#filePath` reads are deliberate | G6 |
| rc-tests-20 | D | Test-host branches; handled by the seams in G10 | G10 |
| rc-tests-21 | C | Test comments carry process IDs and a stale type name | G7 |
| rc-tests-22 | C | Unreferenced `smoke-tests.sh` | G7 |
| rc-tests-23 | C | Snapshot tests in the unit bundle run Prefire in every build | G10 |
| rc-tests-24 | C | DriveCheckKit has no test target | G10 |
| rc-tests-25 | C | File-wide `force_unwrapping` suppressions | G6 |
| rc-tests-26 | C | Per-test defaults suites never removed | G6 |
| rc-tests-27 | C | Duplicated fixture decoders and 25-key list | G9, FEED-26-KEYS |
| rc-tests-28 | C | Location update path untested | G9, LOCATION-PAUSE |

## Repository readiness (rc-readiness)

| ID | V | Finding (short) | Group / reason |
|----|---|-----------------|----------------|
| rc-readiness-01 | C | Brief lint has nothing to check | G7 |
| rc-readiness-02 | P | Trace is the current definition of done (premise rejected); only private-record references in its messages are residue | G7 |
| rc-readiness-03 | C | Screenshot script uses a shared simulator and wrong file names | G7 |
| rc-readiness-04 | C | Two lint-baseline writers with different formats | G7 |
| rc-readiness-05 | R | `project-artifacts.py` and worktree pruning are the artifact policy this repository's AGENTS.md prescribes | — |
| rc-readiness-06 | C | Build-number policy contradicts the Xcode Cloud override | G7 |
| rc-readiness-07 | C | Stale widget version, duplicated Live Activities key, empty widget catalog | G7 |
| rc-readiness-08 | C | Docs point to `just` and removed workflows | G7 |
| rc-readiness-09 | C | CHANGELOG lags the releases | G7 |
| rc-readiness-10 | D | Same as rc-tests-15 | G7 |
| rc-readiness-11 | D | Same as rc-tests-22 | G7 |
| rc-readiness-12 | R | AGENTS.md also serves hosts without the plugin; its policy blocks are the owner's; command lines shrink with G7 | — |
| rc-readiness-13 | P | Dead migration code in the hook installer (the key it sets is still used) | G7 |
| rc-readiness-14 | R | The address is the published support contact on the privacy and terms pages, which App Store review requires; history rewrite is out of scope | — |
| rc-readiness-15 | P | Pre-commit hook does not check the SwiftLint version (`ios-verify` does) | G7 |
| rc-readiness-16 | P | Unlinked spike screenshots (no clone-size gain) | G7 |
| rc-readiness-17 | C | Stale ignore lines (local branches are outside the repository) | G7 |
