# Release process

How commits become TestFlight builds and, from those, App Store submissions. The decision and rejected alternatives are in [ADR 0010](../decisions/0010-gated-testflight-and-tag-releases.md), [ADR 0012](../decisions/0012-tag-gated-testflight-builds.md) (tags, not merges, request TestFlight builds) and [ADR 0013](../decisions/0013-one-build-pipeline-or-two.md) (one pipeline: a release tag marks a submitted commit instead of requesting a build). Versioning rules are in [`AGENTS.md`](../../AGENTS.md#versioning).

## Invariants

1. Xcode Cloud never builds `main`. It builds only `testflight`.
2. Only CI moves `testflight`, and only by fast-forward. Never push, reset, force-push, or delete it by hand. `release` is frozen at `v3.0.0`, the record of the pipeline ADR 0013 removed; nothing moves it again.
3. A commit reaches `testflight` only through an annotated `tf-MAJOR.MINOR.PATCH-BUILD` tag that is on `main`, matches `MARKETING_VERSION` in every target and configuration, and has its own successful "Tests and coverage" run for a push to `main`. Merging to `main` publishes nothing: the owner decides which verified commit testers get. Snapshot pixel mismatches do not block that run (the step is `continue-on-error`); test failures, build failures, and a failed Sonar scan do.
4. An annotated `vMAJOR.MINOR.PATCH` tag marks the commit whose build the owner submitted to App Review. It requests nothing: the submitted build is the TestFlight build of that commit. "Release marker" checks the tag after the fact — on `main`, matching `MARKETING_VERSION`, with its own successful "Tests and coverage" run, and carrying a `tf-MAJOR.MINOR.PATCH-BUILD` tag on the same commit.
5. Tests run only in GitHub Actions. Xcode Cloud workflows have no Test action.
6. A release tag may be moved only while no build of that version was submitted to App Review or released, only by the owner, and only to a later commit on `main` that passes the same checks. After submission the tag is never moved or reused; fix a bad release with a new patch version. The pre-ADR-0013 `v3.0.0` marks a candidate build that was never submitted. Owner ruling 2026-09-18: delete it rather than move it ("старые убираем, гит должен быть чистым и с полезными данными"), and give the redesign's submitted commit its own `v3.0.0`. The deletion is pending and owner-only; until it happens the tag still points at `55621e5`.
7. Every push to `main` gets its own complete "Tests and coverage" run. The workflow's concurrency group is keyed by commit SHA for pushes (`cancel-in-progress: false`), so a later push never cancels an earlier commit's run and any commit the owner may want to tag has one. Pull request pushes keep a ref-keyed group that cancels the pull request's older run. A commit in the middle of a multi-commit push gets no run of its own and therefore cannot be tagged for `testflight`. Why: before RD-CI (2026-09-17), back-to-back pushes cancelled each other and a release-prep commit could be left without a run. Rejected: holding pushes by hand behind a release-prep run (depends on the integrator's memory).

## Systems

| System | Definition | Trigger | Does |
|--------|------------|---------|------|
| GitHub Actions "Tests and coverage" | `.github/workflows/tests.yml` | Push to `main`, pull requests | Unit tests and snapshot tests in parallel, merged coverage, SonarQube Cloud scan. Promotes nothing |
| GitHub Actions "TestFlight" | `.github/workflows/testflight.yml`, `scripts/promote-testflight.sh` | Push of a `tf-*` tag, or manual run with a `tag` input | Validates the tag, waits for the tagged commit's own "Tests and coverage" run to succeed, fast-forwards `testflight` |
| GitHub Actions "Release marker" | `.github/workflows/release.yml`, `scripts/check-release-tag.sh` | Push of a `v*.*.*` tag, or manual run with a `tag` input | Checks that the tag marks a verified commit that had a TestFlight build. Moves nothing, starts nothing |
| Xcode Cloud "Internal TestFlight (verified main)" | App Store Connect | Branch changes on `testflight` | Archive → App Store Connect → TestFlight internal testing. The App Store submission is chosen from these builds |

### Xcode Cloud configuration (source of truth: App Store Connect)

These settings live outside the repository. Keep this table in sync whenever the workflow changes. Read against App Store Connect on 2026-09-17, when the second workflow was removed.

| Setting | "Internal TestFlight (verified main)" |
|---------|---------------------------------|
| Description | Archives the commit of a verified tf-MAJOR.MINOR.PATCH-BUILD tag (testflight.yml fast-forwards the testflight branch) and uploads it to TestFlight internal testing, group Friends&Family. An App Store submission is one of these builds. Does not run tests. |
| Repository / project | `vil4max/regional-check`, `RegionalCheck.xcodeproj` |
| Xcode / macOS | Latest Release / Latest Release |
| Clean builds | Off |
| Start condition | Branch Changes: `testflight` (exact name), any file change |
| Auto-cancel builds | On |
| Restrict editing | On (Admins and App Managers) |
| Environment variables | None |
| Actions | Archive - iOS, scheme `RegionalCheck`, distribution preparation App Store Connect |
| Post-actions | TestFlight Internal Testing - iOS, artifact Archive - iOS, group Friends&Family |
| `ci_scripts/ci_post_clone.sh` | Skips SwiftPM plugin fingerprint validation (Prefire build tool plugin) |

One workflow archives every build ([ADR 0013](../decisions/0013-one-build-pipeline-or-two.md)): the removed "App Store candidate (release tag)" differed only in its description and start condition, so it produced the same artifact twice for one commit. Workflow names state which commits a workflow builds and why, not the upload mechanics. The Builds page groups builds by branch and lists only groups of workflows that still exist: `testflight`, plus `main` from the former `main` start condition (before 2026-09-16). The `release` group disappeared with its workflow on 2026-09-17; the builds it made are unaffected and stay in TestFlight, where 3.0.0 lists them as Ready to Submit.

Xcode Cloud assigns build numbers across workflows. Keep `CURRENT_PROJECT_VERSION` at `1` for a new marketing version.

## Internal TestFlight builds

Owner only, and only for a commit testers should get: every build spends Xcode Cloud compute and an App Store Connect build slot. A merge to `main` produces nothing.

1. **Check the commit before tagging it:**

   ```bash
   just tf-check              # or: just tf-check <commit-ish>
   ```

   It runs the workflow's checks locally — on `main`, one `MARKETING_VERSION`, its own successful "Tests and coverage" run, not already on `testflight` — and prints the tag command with the next free `BUILD`. A tag that the workflow rejects has to be deleted locally and remotely before retrying, so it is cheaper to find out here.
2. **Tag and push.** `BUILD` counts the TestFlight builds of the current `MARKETING_VERSION`, starting at `1`; `MAJOR.MINOR.PATCH` must be the `MARKETING_VERSION` of that very commit, which the workflow verifies.

   ```bash
   git tag -a tf-MAJOR.MINOR.PATCH-BUILD -m "<what testers should try in this round>"
   git push origin tf-MAJOR.MINOR.PATCH-BUILD
   ```

   Write the annotation as the round's **What to Test** and paste it into App Store Connect when the build appears: a round with no statement of what changed gets tested at random. The tag may be pushed before the run finishes; the TestFlight workflow waits up to 45 minutes for it.
3. **Confirm promotion.** The "TestFlight" workflow run ends with `testflight -> tf-MAJOR.MINOR.PATCH-BUILD`, and `git ls-remote origin testflight` shows the commit. A run that ends with `testflight did not move` requested no build.
4. **Confirm the build.** Xcode Cloud "Internal TestFlight (verified main)" archives it and distributes it to the Friends&Family group; App Store Connect → Xcode Cloud → RegionalCheck → Builds lists a build for `testflight`.

A `tf-` tag is a build request, not a release marker: TestFlight rounds of the same unreleased version just increment `BUILD`, and one of those builds is what eventually gets submitted.

## Releasing a version

The App Store submission is a TestFlight build the owner picks in App Store Connect, so a release is a TestFlight round that gets submitted.

1. **Prepare the release commit on `main`.** Set `MARKETING_VERSION` for every target in Debug and Release (see `AGENTS.md` versioning rules), add the `CHANGELOG.md` section, and add `docs/operations/releases/MAJOR.MINOR.md` with release notes and What's New copy.
2. **Verify locally.** `just verify`, then `just release --check` (clean tree, verification evidence matches the commit). Push to `main` so that the release commit is the head of the push: a commit in the middle of a multi-commit push gets no "Tests and coverage" run of its own and cannot be built.
3. **Build it for TestFlight.** Follow [Internal TestFlight builds](#internal-testflight-builds) above: `just tf-check`, then the annotated `tf-MAJOR.MINOR.PATCH-BUILD` tag. The build that appears is the submission candidate.
4. **Check the candidate on a device** through TestFlight before submitting it. A round that finds something is fixed forward on `main` and gets the next `BUILD`; the version does not change until it ships.
5. **Submit manually in App Store Connect.** Create the version, select that build, paste What's New from the release note, complete App Privacy (see [analytics.md](analytics.md)), and submit for review.
6. **Mark the submitted commit.** After the submission is accepted:

   ```bash
   git tag -a vMAJOR.MINOR.PATCH -m "Submitted MAJOR.MINOR.PATCH (build <Xcode Cloud build number>)"
   git push origin vMAJOR.MINOR.PATCH
   ```

   The tag starts no build. "Release marker" confirms the commit is on `main`, is built as that version, was verified, and carries the `tf-` tag whose build was submitted; a failure means the tag names the wrong commit, so move it before anything cites it.

## Failure handling

| Situation | Action |
|-----------|--------|
| "Tests and coverage" fails on `main` | Fix forward on `main`. Nothing was published: `testflight` stays where the last `tf-` tag put it. |
| TestFlight workflow: `is not tf-MAJOR.MINOR.PATCH-BUILD` or `must be an annotated tag` | Delete the tag locally and remotely (`git push origin :refs/tags/tf-X.Y.Z-N`), then create a correct annotated tag. |
| TestFlight workflow: `does not match MARKETING_VERSION` | The tag names a version the commit is not built as. Delete it and tag with the commit's own `MARKETING_VERSION`. |
| TestFlight workflow: `no successful Tests and coverage run ... (missing)` | The tagged commit was not the head of its push. Delete the tag and tag a commit that has its own run. |
| TestFlight workflow: `testflight did not move` | The tag names a commit `testflight` already passed, so Xcode Cloud starts nothing. Tag a later commit, or use Start Build on `testflight` in App Store Connect to rebuild that same commit. |
| Release marker: any failure | The tag was pushed, but it marks the wrong commit and started nothing. Delete it locally and remotely (`git push origin :refs/tags/vX.Y.Z`) and tag the commit whose build was submitted. `carries no tf-X.Y.Z-BUILD tag` means that commit was never built for TestFlight, so it cannot be the submitted one. |
| Xcode Cloud build fails for `testflight` | Read the build log in App Store Connect and fix forward. A rebuild of the same commit is allowed from App Store Connect (Start Build on `testflight`) and costs no new tag, but it does spend another upload. |
| App Store Connect mail: `ITMS-90382: Upload limit reached` | Apple caps uploads per app per day; it lifts by itself after about a day. Nothing to fix in the repository — but check how the builds were requested: after ADR 0013 only a `tf-` tag can ask for one, so a burst means tags were pushed in a burst. |
| A released build is bad | Never move a released tag. Release a new patch version. |
| Tagged version was never submitted and must ship from a later commit | Owner only, and only for a `v` tag from before ADR 0013 (`v3.0.0`), which requested a build rather than marking a submission. Confirm in App Store Connect that no build of the version was submitted or released, delete the tag locally and remotely (`git push origin :refs/tags/vX.Y.Z`), and place it again on the commit that is submitted. |

## Changing the flow

Update, in the same change: the workflows and scripts, the Xcode Cloud workflow in App Store Connect, the configuration table above, and ADR 0010, ADR 0012 and ADR 0013 (or a superseding ADR).
