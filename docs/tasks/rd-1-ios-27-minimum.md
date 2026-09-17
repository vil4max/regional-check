# Agent Task — RD-1: Raise the minimum iOS to 27

Assignee: drivecheck-release
State: claimed
Requested by: owner (direct, 2026-09-17, redesign ruling 4.1 #1). Owner approval (batch 1): "утверждаю" (I approve), owner direct, 2026-09-17, in drivecheck-product, answering "утверждаете роадмап и запуск волны 1?" (do you approve the roadmap and the batch 1 launch?). Delegated by drivecheck-product (managing agent).
Evidence: —
Parent: `docs/tasks/redesign.md` (task RD-1)
Requirements: `docs/core.md` (no platform clause); `docs/engineering/testing-strategy.md` (snapshot baselines)
Changes a requirement: no. `docs/core.md` and `docs/requirements/` name no minimum iOS version.
Owned files: `RegionalCheck.xcodeproj/project.pbxproj` (deployment target only), `Packages/DriveCheckKit/Package.swift` (`platforms` only), `.github/workflows/tests.yml` (Xcode, runner image, destination), `ci_scripts/*`, `.prefire.yml` (`required_os` only; added 2026-09-17 because the snapshot stencil stops on any other simulator major version; owner: "разрешаю", I permit), `README.md` (platform line), `docs/engineering/testing-strategy.md` (baseline OS line), `RegionalCheckTests/__Snapshots__/` (re-recorded baselines only), this brief
Out of scope: `RegionalCheck/App/Theme.swift` (RD-2), any view or CarPlay change, `MARKETING_VERSION` (RD-14), `.github/workflows/release.yml`, `scripts/promote-release.sh`, Xcode Cloud workflow settings in App Store Connect (owner-only)
Failure conditions: any target or package still allows iOS 26; CI builds with an SDK older than iOS 27; snapshot baselines change for a reason other than the OS runtime; a view, string, or behavior changes; the marketing version changes; commands are claimed without evidence
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1).

## Objective

Every target (app, widgets extension, tests) and `DriveCheckKit` require
iOS 27.0. Local and CI verification build with the iOS 27 SDK and test on an
iOS 27 simulator. The app looks and behaves exactly as before.

## Current state (2026-09-17, `main` 3b15fb8)

- `IPHONEOS_DEPLOYMENT_TARGET = 26.0` in 8 build configurations.
- `Packages/DriveCheckKit/Package.swift`: `.iOS(.v26)`.
- `.github/workflows/tests.yml`: `runs-on: macos-26`,
  `DEVELOPER_DIR: /Applications/Xcode_26.6.app`, destination
  `iPhone 17, OS=26.5`.
- No `#available` / `@available` checks in app, widget, package, or test
  sources, so there is no dead availability code to remove.
- This machine has Xcode 27.0 (27A266a) and an iOS 27.0 simulator runtime.
- Snapshot baselines are recorded on the iPhone 17 simulator, iOS 26.

## Authorization and boundaries

You may edit the owned files, run `just doctor`, focused builds and tests,
the `Snapshots` test plan, and `just verify`. You must not add dependencies,
change product code, or change App Store Connect / Xcode Cloud settings.
If a step needs the owner (Xcode Cloud workflow Xcode version, a GitHub
runner that does not exist yet), stop that step and report it.

Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`,
"Build slots"). `just verify`, `just build`, `just test` wait for a slot; run raw
`xcodebuild` as `./scripts/build-slot.sh run xcodebuild …`; for Xcode MCP use
`just build-slot acquire <label>` and `just build-slot release <token>`. Expect
to wait; never stop another session's run; do not raise `BUILD_SLOTS`.

## Research first

1. Confirm the iOS 27 `SupportedPlatform` spelling for SwiftPM with the
   installed toolchain (`.iOS(.v27)`), from Apple documentation.
2. Find which GitHub-hosted macOS image ships Xcode 27 and the iOS 27
   simulator runtime (runner image readme). If none exists, report it as a
   blocker instead of pinning a guess.
3. Check `ci_scripts/` and `docs/operations/release-process.md` for the Xcode
   version Xcode Cloud uses; list what the owner must change in App Store
   Connect.
4. Search the repo for other iOS 26 references (docs, scripts, `Tooling/`
   overrides you do not own) and list them in the report.

## Required behavior

- All deployment targets are 27.0; `DriveCheckKit` declares iOS 27.
- CI unit and snapshot jobs use Xcode 27 and an iOS 27 simulator destination.
  Owner (2026-09-17, "как проще так и делай", do whatever is simpler): until
  GitHub ships a GA macOS image with release Xcode 27, use the public-preview
  `xcode-27` runner label with the newest Xcode 27 on that image, and write
  the exact Xcode build in the workflow comment and the report. Why not local
  only: `testflight` and `release` move only after a green "Tests and coverage"
  run on `main` (`docs/operations/release-process.md` rules 3–4), and Xcode 26
  cannot build an iOS 27 deployment target, so skipping CI would stop
  TestFlight and release. Shipping builds still come from Xcode Cloud with
  release Xcode 27. Switch to the GA image as soon as it exists.
- The deployment target change and the CI switch land in one `READY`, so no
  `main` commit has an iOS 27 target with an Xcode 26 CI.
- Snapshot baselines are re-recorded on iOS 27 only where the OS runtime
  changed pixels; list every re-recorded file and state that each diff is
  OS rendering, not a design change.
- `README.md` and `docs/engineering/testing-strategy.md` say iOS 27.

## Tests

No new test assertions. `just verify` passes; the `Snapshots` plan passes on
iOS 27 with the reviewed baselines.

## Acceptance criteria

- `grep -rn "26\.0\|\.v26\|Xcode_26\|OS=26"` over owned files returns nothing
  relevant.
- `just verify` passes in the task worktree.
- Snapshot re-records are listed and reviewed.
- Owner actions (Xcode Cloud Xcode version) are listed, not performed.
- One commit for the deployment target and package, one for CI, one for
  re-recorded baselines if any, one for docs.

## Completion

Commit atomically in your own worktree and branch
(`git worktree add .claude/worktrees/rd-1-ios-27 -b chore/rd-1-ios-27 main`),
run `just verify`, then send `READY` to `drivecheck-integrator` with branch, head
SHA, worktree path, this brief, the `just verify` result, and
`release-prep: no`. Copy the report below to `drivecheck-product`. Never merge,
push, or tag.

## Required final report

```markdown
# Agent Result

## Outcome
COMPLETED | BLOCKED_CORRECTLY | FAILED

## Summary
## Research findings
## Files changed
## Snapshot baselines re-recorded
## Commands executed
## Verification results
## Owner actions needed
## Risks
## Open questions
```
