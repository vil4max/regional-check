# Release process

How commits become TestFlight builds and App Store candidates. The decision and rejected alternatives are in [ADR 0010](../decisions/0010-gated-testflight-and-tag-releases.md). Versioning rules are in [`AGENTS.md`](../../AGENTS.md#versioning).

## Invariants

1. Xcode Cloud never builds `main`. It builds only `testflight` and `release`.
2. Only CI moves `testflight` and `release`, and only by fast-forward. Never push, reset, force-push, or delete them by hand.
3. A commit reaches `testflight` only after unit tests, snapshot tests, and the SonarQube Cloud scan succeed in the "Tests and coverage" workflow for a push to `main`. Snapshot pixel mismatches do not block (the step is `continue-on-error`); test failures, build failures, and a failed Sonar scan do.
4. A commit reaches `release` only through an annotated `vMAJOR.MINOR.PATCH` tag that is on `main`, matches `MARKETING_VERSION` in every target and configuration, and is contained in `testflight`.
5. Tests run only in GitHub Actions. Xcode Cloud workflows have no Test action.
6. A published tag is never moved or reused. Fix a bad release with a new patch version.

## Systems

| System | Definition | Trigger | Does |
|--------|------------|---------|------|
| GitHub Actions "Tests and coverage" | `.github/workflows/tests.yml` | Push to `main`, pull requests | Unit tests and snapshot tests in parallel, merged coverage, SonarQube Cloud scan, then `promote-testflight` (pushes to `main` only) |
| GitHub Actions "Release" | `.github/workflows/release.yml`, `scripts/promote-release.sh` | Push of a `v*.*.*` tag, or manual run with a `tag` input | Validates the tag, waits for `testflight`, fast-forwards `release` |
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
2. **Verify locally.** `just verify`, then `just release --check` (clean tree, verification evidence matches the commit). Push to `main`.
3. **Wait for that commit's own "Tests and coverage" run to succeed** and for `testflight` to reach it:

   ```bash
   gh run list --workflow tests.yml --commit "$(git rev-parse HEAD)"
   git ls-remote origin testflight
   ```

   Do not tag a commit whose own run failed, even if a later commit is green (see Known limitation).
4. **Tag and push:**

   ```bash
   git tag -a vMAJOR.MINOR.PATCH -m "Release MAJOR.MINOR.PATCH"
   git push origin vMAJOR.MINOR.PATCH
   ```

   The tag may be pushed before step 3 finishes; the Release workflow waits up to 45 minutes.
5. **Confirm promotion.** The "Release" workflow run ends with `release -> vMAJOR.MINOR.PATCH`, and `git ls-remote origin release` shows the tagged commit.
6. **Confirm the build.** Xcode Cloud "Release" produces a build for `release`, and it appears in TestFlight.
7. **Submit manually in App Store Connect.** Create the version, select the Release build, paste What's New from the release note, complete App Privacy (see [analytics.md](analytics.md)), and submit for review.

## Failure handling

| Situation | Action |
|-----------|--------|
| "Tests and coverage" fails on `main` | Fix forward on `main`. `testflight` stays on the last verified commit. |
| Release workflow: `is not vMAJOR.MINOR.PATCH` or `must be an annotated tag` | Delete the unpublished tag locally and remotely (`git push origin :refs/tags/vX.Y.Z`), then create a correct annotated tag. Allowed only before step 5 succeeds. |
| Release workflow: `does not match MARKETING_VERSION` or `is not on main` | Same as above: fix the release commit, then retag. |
| Release workflow: `has not reached testflight` after 45 minutes | Check the commit's "Tests and coverage" run. If it succeeded late, rerun Actions → Release → Run workflow with the tag. If it failed, fix forward and release a new patch version. |
| Xcode Cloud build fails for `testflight` or `release` | Read the build log in App Store Connect and fix forward. A rebuild of the same commit is allowed from App Store Connect (Start Build on that branch). |
| A released build is bad | Never move `release` back. Release a new patch version. |

## Known limitation

`scripts/promote-release.sh` accepts a tag when its commit is contained in `testflight`. It does not check the conclusion of the tagged commit's own "Tests and coverage" run, so a tag on a failing commit is accepted once a later commit is promoted. Until the script checks the run conclusion through the GitHub API, step 3 of the release checklist is mandatory.

## Changing the flow

Update, in the same change: the workflows and scripts, both Xcode Cloud workflows in App Store Connect, the configuration table above, and ADR 0010 (or a superseding ADR).
