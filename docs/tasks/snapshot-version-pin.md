# Task — Details snapshots must not depend on the build number

Assignee: Drive Check
State: done
Requested by: owner (direct, 2026-09-25)
Evidence: fail — `fixtureVersionLineIsFixedRatherThanReadFromTheBundle` failed on 5986de6 ("Version 3.1.0 (4)" against "(1)"); verify — `just verify` OK on 0730d10, Snapshots plan 23 tests 0 failures, and 0 failures again with `CURRENT_PROJECT_VERSION` temporarily 99; review — `/code-review medium`, one low accepted (see Reviews)
Depends-on: none
Parallelism: none
Profile: fix
user-visible: none

## Current status and authorization

Current outcome: both steps landed (5986de6, 0730d10).
Authorized scope: the owner asked on 2026-09-25 to open this task. The plan was approved the same day through AskUserQuestion "SNAP-VER … Что делаем?", answer verbatim: "Делать сейчас (Recommended)". It covers injecting the version and build into `DetailsViewModel` with a `Bundle.main` default, fixed "3.1.0 (1)" in the fixture and previews, a failing test first, one re-record of the four Details baselines, a check that the Snapshots plan still passes after a build bump, and two commits with no user-visible change.
Blocking decisions: none
Permitted deviations: none
Material assumptions: none
Next step: none.
Requirements: none yet. The fix is test infrastructure; a REQ is needed only if the Details version line changes behaviour.
Acceptance specs: the four Details baselines match after a `CURRENT_PROJECT_VERSION` or `MARKETING_VERSION` bump with no re-record
Owned files: `RegionalCheck/Views/DetailsViewModel.swift`, `RegionalCheck/Views/DetailsView.swift` (previews), `RegionalCheck/App/AppContainerFixture.swift`, the Details PNGs under `RegionalCheckTests/__Snapshots__/PreviewTests.generated/`, `RegionalCheckTests/DetailsViewModelTests.swift`
Out of scope: making CI snapshot failures blocking, which `scripts/ci-extra.sh` deliberately does not do (baselines are recorded on a developer Mac); the version line's wording
Failure conditions: a build or version bump still changes a Details baseline; the shipped app stops showing its real version and build

## Problem

`DetailsViewModel.versionBuildText` reads `CFBundleShortVersionString` and `CFBundleVersion`
from `Bundle.main` (`RegionalCheck/Views/DetailsViewModel.swift:65-71`), and the Details
previews render it. Every build-number bump therefore changes four Details baselines:
`Details`, `Details-Live-Activities-off`, `Details-location-denied` and `Details-subscribed`.
Nothing catches the stale images:

- `just verify` does not run the Snapshots test plan.
- CI runs it in `just ci` (`scripts/ci-extra.sh`), but reports a snapshot failure without
  failing the job. The `tests.yml` run 36095154360 on `b040162` was green although
  `Details-iPhone-16.1.png` did not match.

The same defect has already recurred three times: 429ae28 ("Version 3.0.0 (4)"), 65eafa2 (the
3.1.0 build 3 bump left "(2)"), and f43a3e3 (re-recorded for build 4).

## Direction (to confirm in the plan)

Inject the version and build into `DetailsViewModel`, with `Bundle.main` as the production
default. The fixture container and the previews pass fixed values, such as "3.1.0" and "1".
`versionBuildText(version:build:)` already exists for the formatting and has a test
(`DetailsViewModelTests.swift:50`). Re-record the four baselines once, then prove the pin holds:
bump `CURRENT_PROJECT_VERSION` locally and check that the Snapshots plan still passes.

## Writer steps

- [x] Failing spec: a test that the fixture Details view model reports the fixed version and build, not `Bundle.main`'s: the test fails — 5986de6
- [x] Inject the version and build with a `Bundle.main` default; fixture and previews pass fixed values; re-record the four baselines once: `just verify`, and the Snapshots plan still passes after a local build-number bump — 0730d10

## Evidence history

- 2026-09-25: both steps by a `slice-writer` (opus) in its own worktree, landed ff-only. `DetailsViewModel.appVersion` defaults to `Bundle.main`; `AppContainer.fixture()` pins "3.1.0" and "1". Only the four Details PNGs changed, each on the version line.

- 2026-09-25: opened after the 3.1.0 build 4 review found the four baselines stale since 65eafa2.

## Reviews

### Round 1 review — snapshot-version-pin (2026-09-25)

Review SHA: 0730d10
[low][non-blocking] RegionalCheck/App/AppContainerFixture.swift:82 — the DEBUG screenshot phases also use the fixture, so a Details App Store capture would show "3.1.0 (1)"; accepted, to check when the store set is next recaptured.
