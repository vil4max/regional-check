# Release process

How commits become TestFlight builds and App Store candidates. The decision and rejected alternatives are in [ADR 0010](../decisions/0010-gated-testflight-and-tag-releases.md). Versioning rules are in [`AGENTS.md`](../../AGENTS.md#versioning).

## Invariants

1. Xcode Cloud never builds `main`. It builds only `testflight` and `release`.
2. Only CI moves `testflight` and `release`, and only by fast-forward. Never push, reset, force-push, or delete them by hand.
3. A commit reaches `testflight` only after unit tests, snapshot tests, and the SonarQube Cloud scan succeed in the "Tests and coverage" workflow for a push to `main`. Snapshot pixel mismatches do not block (the step is `continue-on-error`); test failures, build failures, and a failed Sonar scan do.
4. A commit reaches `release` only through an annotated `vMAJOR.MINOR.PATCH` tag that is on `main`, matches `MARKETING_VERSION` in every target and configuration, has its own successful "Tests and coverage" run for a push to `main`, and is contained in `testflight`.
5. Tests run only in GitHub Actions. Xcode Cloud workflows have no Test action.
6. A published tag is never moved or reused. Fix a bad release with a new patch version.

## Systems

| System | Definition | Trigger | Does |
|--------|------------|---------|------|
| GitHub Actions "Tests and coverage" | `.github/workflows/tests.yml` | Push to `main`, pull requests | Unit tests and snapshot tests in parallel, merged coverage, SonarQube Cloud scan, then `promote-testflight` (pushes to `main` only) |
| GitHub Actions "Release" | `.github/workflows/release.yml`, `scripts/promote-release.sh` | Push of a `v*.*.*` tag, or manual run with a `tag` input | Validates the tag, waits for the tagged commit's own "Tests and coverage" run to succeed, confirms it reached `testflight`, fast-forwards `release` |
| Xcode Cloud "AppStore connect + TestFlight" | App Store Connect | Branch changes on `testflight` | Archive → App Store Connect → TestFlight internal testing |
| Xcode Cloud "Release" | App Store Connect | Branch changes on `release` | Archive → App Store Connect → TestFlight internal testing; the build is the App Store candidate |

### Xcode Cloud configuration (source of truth: App Store Connect)

These settings live outside the repository. Keep this table in sync whenever a workflow changes.

| Setting | "AppStore connect + TestFlight" | "Release" |
|---------|---------------------------------|-----------|
| Repository / project | `vil4max/regional-check`, `RegionalCheck.xcodeproj` | Same |
| Xcode / macOS | Latest Release / Latest Release | Same |
| Clean builds | Off | Off |
| Start condition | Branch Changes: `testflight` (exact name), any file change | Branch Changes: `release` (exact name), any file change |
| Auto-cancel builds | On | On |
| Restrict editing | On (Admins and App Managers) | On |
| Actions | Archive - iOS, scheme `RegionalCheck`, distribution preparation App Store Connect | Same |
| Post-actions | TestFlight Internal Testing - iOS, group Friends&Family | Same |
| `ci_scripts/ci_post_clone.sh` | Skips SwiftPM plugin fingerprint validation (Prefire build tool plugin) | Same |

Xcode Cloud assigns build numbers across both workflows. Keep `CURRENT_PROJECT_VERSION` at `1` for a new marketing version.

## Internal TestFlight builds

No manual steps. For every push to `main`:

1. "Tests and coverage" runs. If any required job fails, nothing is promoted.
2. `promote-testflight` fast-forwards `testflight` to the pushed commit.
3. Xcode Cloud "AppStore connect + TestFlight" archives it and distributes it to the Friends&Family group.

Check: `git ls-remote origin testflight` shows the commit, and App Store Connect → Xcode Cloud → RegionalCheck → Builds lists a build for `testflight`.

## Releasing a version

1. **Prepare the release commit on `main`.** Set `MARKETING_VERSION` for every target in Debug and Release (see `AGENTS.md` versioning rules), add the `CHANGELOG.md` section, and add `docs/operations/releases/MAJOR.MINOR.md` with release notes and What's New copy.
2. **Verify locally.** `just verify`, then `just release --check` (clean tree, verification evidence matches the commit). Push to `main` so that the release commit is the head of the push: a commit in the middle of a multi-commit push gets no "Tests and coverage" run of its own and cannot be released.
3. **Wait for that commit's own "Tests and coverage" run to succeed** and for `testflight` to reach it:

   ```bash
   gh run list --workflow tests.yml --commit "$(git rev-parse HEAD)"
   git ls-remote origin testflight
   ```

   The Release workflow enforces this, but checking first avoids a failed release run.
4. **Tag and push:**

   ```bash
   git tag -a vMAJOR.MINOR.PATCH -m "Release MAJOR.MINOR.PATCH"
   git push origin vMAJOR.MINOR.PATCH
   ```

   The tag may be pushed before step 3 finishes; the Release workflow waits up to 45 minutes for the run.
5. **Confirm promotion.** The "Release" workflow run ends with `release -> vMAJOR.MINOR.PATCH`, and `git ls-remote origin release` shows the tagged commit.
6. **Confirm the build.** Xcode Cloud "Release" produces a build for `release`, and it appears in TestFlight.
7. **Submit manually in App Store Connect.** Create the version, select the Release build, paste What's New from the release note, complete App Privacy (see [analytics.md](analytics.md)), and submit for review.

## Failure handling

| Situation | Action |
|-----------|--------|
| "Tests and coverage" fails on `main` | Fix forward on `main`. `testflight` stays on the last verified commit. |
| Release workflow: `is not vMAJOR.MINOR.PATCH` or `must be an annotated tag` | Delete the unpublished tag locally and remotely (`git push origin :refs/tags/vX.Y.Z`), then create a correct annotated tag. Allowed only before step 5 succeeds. |
| Release workflow: `does not match MARKETING_VERSION` or `is not on main` | Same as above: fix the release commit, then retag. |
| Release workflow: `Tests and coverage failed for <sha>` | The tagged commit is red. Fix forward on `main`, bump `PATCH`, and release the fixed commit. Do not retag the red commit. |
| Release workflow: `was cancelled by a newer push` | A later push to `main` cancelled the tagged commit's run. Rerun that run (`gh run rerun <run-id>`), wait for it to succeed, then rerun Actions → Release → Run workflow with the tag. |
| Release workflow: `no successful Tests and coverage run ... (missing)` | The tagged commit was not the head of its push. Delete the unpublished tag, push a new release-prep commit on its own, and tag that. |
| Release workflow: `no successful Tests and coverage run ... (pending)` after 45 minutes | Wait for the run to finish, then rerun Actions → Release → Run workflow with the tag. |
| Release workflow: `passed Tests and coverage but is not on testflight` | Check the `promote-testflight` job of that run and rerun it if it failed. |
| Xcode Cloud build fails for `testflight` or `release` | Read the build log in App Store Connect and fix forward. A rebuild of the same commit is allowed from App Store Connect (Start Build on that branch). |
| A released build is bad | Never move `release` back. Release a new patch version. |

## Changing the flow

Update, in the same change: the workflows and scripts, both Xcode Cloud workflows in App Store Connect, the configuration table above, and ADR 0010 (or a superseding ADR).
