# ADR 0016 — Adopt the shared iOS pipeline and the JSON project format

Status: accepted — owner, 2026-09-22 ("делай все": do the whole queued job; the owner's
earlier decisions of 2026-09-21 make every iOS app share one pipeline, one style and one
simulator per agent session)

## Context

Drive Check had its own CI: a "Tests and coverage" workflow with separate unit and snapshot
jobs and a Sonar job, a "Release marker" workflow for `v` tags, and app copies of the
build-slot, tf-check and TestFlight promotion scripts. The owner's other apps had different
pipelines, so a fix found in one never reached the others. The shared Runtime
(ios-agent-toolchain) now carries one pipeline, one style and a per-session simulator,
checked by `just baseline` (Tooling/docs/ci.md).

## Decision

- `pipeline: shared` in `Tooling/runtime.yml`. Every harness update rewrites
  `.github/workflows/tests.yml`, `.github/workflows/testflight.yml`,
  `ci_scripts/ci_post_clone.sh` and the SwiftLint/SwiftFormat files from the Runtime
  templates. Hand edits there are overwritten.
- The app's own CI work is the `ci` recipe: the requirement trace, the Runtime `ci.sh`
  gate, then `scripts/ci-extra.sh`. That script runs the Snapshots plan, which reports
  pixel failures without failing the job (the rule the old workflow applied), and writes
  Sonar coverage for the unit and snapshot runs to `build/ci/sonar/coverage.xml`.
- "Release marker" (`release.yml`) is removed: the shared TestFlight workflow handles
  `v` tags. The app copies of `build-slot.sh`, `check-testflight-tag.sh`,
  `promote-testflight.sh`, `check-release-tag.sh`, `lib/promote.sh` and
  `merge-sonar-coverage.py` are removed; the Runtime's versions replace them. Build slots
  become machine-wide across apps, as they were documented but not implemented.
- The simulator is `simulator.device_type: iPhone 17` / `os: "27.0"`. Each agent session
  gets its own device from the Runtime; the smoke tests use it instead of the "best
  available iPhone", which could land on another app's device.
- The project is stored in Xcode 27.2's JSON format (`project.xcproj`). The Runtime's
  `project_versions.py` and `ci_post_clone.sh` read it, and Xcode 27.0 builds it.
- `ci_post_clone.sh` sets `CURRENT_PROJECT_VERSION` from Xcode Cloud's build number, so a
  TestFlight round no longer needs a build-number commit. The committed value only
  matters for a manual local archive.

## Consequences

- The workflow is named "Tests", not "Tests and coverage". The tag checks read that name.
- The style change reformatted 30 Swift files (trailing commas, brace placement) with no
  behaviour change.
- Sonar needs the repository variable `SONAR_ENABLED=true`, which the old workflow did not.

## Rejected

- Keeping the app's workflows beside the shared ones. `just baseline --strict` flags it,
  and three apps with three pipelines is the drift this ADR ends.
- Making snapshot failures fatal in CI. Baselines are recorded on a developer Mac, and a
  hosted runner's GPU differs.
