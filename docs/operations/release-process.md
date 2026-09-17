# Release process

How commits become TestFlight builds and App Store candidates. The decision and rejected alternatives are in [ADR 0010](../decisions/0010-gated-testflight-and-tag-releases.md) and [ADR 0012](../decisions/0012-tag-gated-testflight-builds.md) (tags, not merges, request TestFlight builds). Versioning rules are in [`AGENTS.md`](../../AGENTS.md#versioning).

## Invariants

1. Xcode Cloud never builds `main`. It builds only `testflight` and `release`.
2. Only CI moves `testflight` and `release`, and only by fast-forward. Never push, reset, force-push, or delete them by hand.
3. A commit reaches `testflight` only through an annotated `tf-MAJOR.MINOR.PATCH-BUILD` tag that is on `main`, matches `MARKETING_VERSION` in every target and configuration, and has its own successful "Tests and coverage" run for a push to `main`. Merging to `main` publishes nothing: the owner decides which verified commit testers get. Snapshot pixel mismatches do not block that run (the step is `continue-on-error`); test failures, build failures, and a failed Sonar scan do.
4. A commit reaches `release` only through an annotated `vMAJOR.MINOR.PATCH` tag that is on `main`, matches `MARKETING_VERSION` in every target and configuration, and has its own successful "Tests and coverage" run for a push to `main`. A release tag does not need a `tf-` tag first.
5. Tests run only in GitHub Actions. Xcode Cloud workflows have no Test action.
7. Every push to `main` gets its own complete "Tests and coverage" run. The workflow's concurrency group is keyed by commit SHA for pushes (`cancel-in-progress: false`), so a later push never cancels an earlier commit's run and any commit the owner may want to tag has one. Pull request pushes keep a ref-keyed group that cancels the pull request's older run. A commit in the middle of a multi-commit push gets no run of its own and therefore cannot be tagged for `testflight` or `release`. Why: before RD-CI (2026-09-17), back-to-back pushes cancelled each other and a release-prep commit could be left without a run. Rejected: holding pushes by hand behind a release-prep run (depends on the integrator's memory).
6. A release tag may be moved only while no build of that version was submitted to App Review or released, only by the owner, and only to a later commit on `main` that passes the same checks (`release` still moves by fast-forward). After submission the tag is never moved or reused; fix a bad release with a new patch version.

## Systems

| System | Definition | Trigger | Does |
|--------|------------|---------|------|
| GitHub Actions "Tests and coverage" | `.github/workflows/tests.yml` | Push to `main`, pull requests | Unit tests and snapshot tests in parallel, merged coverage, SonarQube Cloud scan. Promotes nothing |
| GitHub Actions "TestFlight" | `.github/workflows/testflight.yml`, `scripts/promote-testflight.sh` | Push of a `tf-*` tag, or manual run with a `tag` input | Validates the tag, waits for the tagged commit's own "Tests and coverage" run to succeed, fast-forwards `testflight` |
| GitHub Actions "Release" | `.github/workflows/release.yml`, `scripts/promote-release.sh` | Push of a `v*.*.*` tag, or manual run with a `tag` input | Validates the tag, waits for the tagged commit's own "Tests and coverage" run to succeed, fast-forwards `release` |
| Xcode Cloud "Internal TestFlight (verified main)" | App Store Connect | Branch changes on `testflight` | Archive → App Store Connect → TestFlight internal testing |
| Xcode Cloud "App Store candidate (release tag)" | App Store Connect | Branch changes on `release` | Archive → App Store Connect → TestFlight internal testing; the build is the App Store candidate |

### Xcode Cloud configuration (source of truth: App Store Connect)

These settings live outside the repository. Keep this table in sync whenever a workflow changes.

| Setting | "Internal TestFlight (verified main)" | "App Store candidate (release tag)" |
|---------|---------------------------------|-----------|
| Description | Archives the commit of a verified tf-MAJOR.MINOR.PATCH-BUILD tag (testflight.yml fast-forwards the testflight branch) and uploads it to TestFlight internal testing, group Friends&Family. Does not run tests. | Archives the commit of a verified vMAJOR.MINOR.PATCH tag (release.yml fast-forwards the release branch) and uploads it to App Store Connect as the App Store submission candidate; also available in TestFlight internal testing. Does not run tests. |
| Repository / project | `vil4max/regional-check`, `RegionalCheck.xcodeproj` | Same |
| Xcode / macOS | Latest Release / Latest Release | Same |
| Clean builds | Off | Off |
| Start condition | Branch Changes: `testflight` (exact name), any file change | Branch Changes: `release` (exact name), any file change |
| Auto-cancel builds | On | On |
| Restrict editing | On (Admins and App Managers) | On |
| Actions | Archive - iOS, scheme `RegionalCheck`, distribution preparation App Store Connect | Same |
| Post-actions | TestFlight Internal Testing - iOS, group Friends&Family | Same |
| `ci_scripts/ci_post_clone.sh` | Skips SwiftPM plugin fingerprint validation (Prefire build tool plugin) | Same |

Workflow names state which commits a workflow builds and why, not the upload mechanics both share. The Builds page groups builds by branch, so the `main` group there only holds builds made before 2026-09-16 by the former `main` start condition.

Xcode Cloud assigns build numbers across both workflows. Keep `CURRENT_PROJECT_VERSION` at `1` for a new marketing version.

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

A `tf-` tag is a build request, not a release marker: it is never needed before a release tag, and TestFlight rounds of the same unreleased version just increment `BUILD`.

## Releasing a version

1. **Prepare the release commit on `main`.** Set `MARKETING_VERSION` for every target in Debug and Release (see `AGENTS.md` versioning rules), add the `CHANGELOG.md` section, and add `docs/operations/releases/MAJOR.MINOR.md` with release notes and What's New copy.
2. **Verify locally.** `just verify`, then `just release --check` (clean tree, verification evidence matches the commit). Push to `main` so that the release commit is the head of the push: a commit in the middle of a multi-commit push gets no "Tests and coverage" run of its own and cannot be released.
3. **Wait for that commit's own "Tests and coverage" run to succeed:**

   ```bash
   gh run list --workflow tests.yml --commit "$(git rev-parse HEAD)"
   ```

   The Release workflow enforces this, but checking first avoids a failed release run. The commit does not need a `tf-` tag; tag one only when the candidate should also go through a TestFlight round first.
4. **Tag and push:**

   ```bash
   git tag -a vMAJOR.MINOR.PATCH -m "Release MAJOR.MINOR.PATCH"
   git push origin vMAJOR.MINOR.PATCH
   ```

   The tag may be pushed before step 3 finishes; the Release workflow waits up to 45 minutes for the run.
5. **Confirm promotion.** The "Release" workflow run ends with `release -> vMAJOR.MINOR.PATCH`, and `git ls-remote origin release` shows the tagged commit.
6. **Confirm the build.** Xcode Cloud "App Store candidate (release tag)" produces a build for `release`, and it appears in TestFlight.
7. **Submit manually in App Store Connect.** Create the version, select the Release build, paste What's New from the release note, complete App Privacy (see [analytics.md](analytics.md)), and submit for review.

## Failure handling

| Situation | Action |
|-----------|--------|
| "Tests and coverage" fails on `main` | Fix forward on `main`. Nothing was published: `testflight` stays where the last `tf-` tag put it. |
| TestFlight workflow: `is not tf-MAJOR.MINOR.PATCH-BUILD` or `must be an annotated tag` | Delete the tag locally and remotely (`git push origin :refs/tags/tf-X.Y.Z-N`), then create a correct annotated tag. |
| TestFlight workflow: `does not match MARKETING_VERSION` | The tag names a version the commit is not built as. Delete it and tag with the commit's own `MARKETING_VERSION`. |
| TestFlight workflow: `no successful Tests and coverage run ... (missing)` | The tagged commit was not the head of its push. Delete the tag and tag a commit that has its own run. |
| TestFlight workflow: `testflight did not move` | The tag names a commit `testflight` already passed, so Xcode Cloud starts nothing. Tag a later commit, or use Start Build on `testflight` in App Store Connect to rebuild that same commit. |
| Release workflow: `is not vMAJOR.MINOR.PATCH` or `must be an annotated tag` | Delete the unpublished tag locally and remotely (`git push origin :refs/tags/vX.Y.Z`), then create a correct annotated tag. Allowed only before step 5 succeeds. |
| Release workflow: `does not match MARKETING_VERSION` or `is not on main` | Same as above: fix the release commit, then retag. |
| Release workflow: `Tests and coverage failed for <sha>` | The tagged commit is red. Fix forward on `main`, bump `PATCH`, and release the fixed commit. Do not retag the red commit. |
| Release workflow: `was cancelled by a newer push` | Should no longer happen for pushes to `main` (invariant 7). If it does, rerun that run (`gh run rerun <run-id>`), wait for it to succeed, then rerun Actions → Release → Run workflow with the tag, and report the workflow regression. |
| Release workflow: `no successful Tests and coverage run ... (missing)` | The tagged commit was not the head of its push. Delete the unpublished tag, push a new release-prep commit on its own, and tag that. |
| Release workflow: `no successful Tests and coverage run ... (pending)` after 45 minutes | Wait for the run to finish, then rerun Actions → Release → Run workflow with the tag. |
| Xcode Cloud build fails for `testflight` or `release` | Read the build log in App Store Connect and fix forward. A rebuild of the same commit is allowed from App Store Connect (Start Build on that branch) and costs no new tag, but it does spend another upload. |
| App Store Connect mail: `ITMS-90382: Upload limit reached` | Apple caps uploads per app per day; it lifts by itself after about a day. Nothing to fix in the repository — but check how the builds were requested: after ADR 0012 only a `tf-` or `v` tag can ask for one, so a burst means tags were pushed in a burst. |
| A released build is bad | Never move `release` back. Release a new patch version. |
| Tagged version was never submitted and must ship from a later commit | Owner only. Confirm in App Store Connect that no build of the version was submitted or released. Delete the tag locally and remotely (`git push origin :refs/tags/vX.Y.Z`), prepare the release commit on `main` with the same `MARKETING_VERSION`, then follow steps 2–5 with a new annotated tag of the same name. `release` fast-forwards to the new commit. |

## Changing the flow

Update, in the same change: the workflows and scripts, both Xcode Cloud workflows in App Store Connect, the configuration table above, and ADR 0010 and ADR 0012 (or a superseding ADR).
