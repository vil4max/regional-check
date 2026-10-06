# ADR 0013 — One build pipeline, gated by CI and requested by a tag

Status: Accepted (2026-09-17). Replaces the earlier two-pipeline design (a `testflight` branch and
a `release` branch, each moved by its own tag namespace and each started by its own Xcode Cloud
workflow). Day-to-day steps are in [release-process.md](../operations/release-process.md).

## Context

Xcode Cloud used to archive and upload every push to `main` to TestFlight, and ran its own Test
action, while GitHub Actions ran the same tests plus coverage and Sonar. Two problems followed:

- Tests ran twice on two systems with two failure signals, and Xcode Cloud started as soon as
  `main` moved, before GitHub Actions finished, so TestFlight could receive a build whose checks
  later failed.
- Every merge produced an archive, an upload and a TestFlight build, documentation commits
  included. On 2026-09-17 App Store Connect rejected a delivery of version 3.0.0 with
  `ITMS-90382: Upload limit reached` after about a hundred uploads of one unreleased version,
  nearly all of them commits nobody had asked testers to try. The cap is daily and lifts by
  itself, but it showed that the trigger, not the cap, was wrong.

A first remedy added a second tag namespace and a second CI-moved branch for App Store candidates.
Its Xcode Cloud workflow was identical, field by field, to the TestFlight one (same Archive action,
same post-action to the same tester group), so a candidate and a TestFlight build were the same
artifact built twice. Submission to App Review is a manual step in App Store Connect that picks one
of the existing builds; nothing in it reads a branch.

The branches are not a branching model. The repository is trunk-based: one `main`, short-lived task
branches, direct pushes. `testflight` is a build pointer, closer to `gh-pages` than to a development
branch: it exists because Xcode Cloud has to start only after GitHub Actions has verified the commit,
without an App Store Connect API key in repository secrets, and a branch push is a trigger that
achieves that.

## Options

| | A — Keep two pipelines | B — One pipeline, `v` becomes a marker | C — No branches, Xcode Cloud starts on tags | D — GitHub Actions calls the App Store Connect API |
|---|---|---|---|---|
| Requests a build | `tf-` tag → `testflight`; `v` tag → `release` | `tf-` tag only | `tf-` and `v` tags, read by Xcode Cloud directly | A GitHub Actions job, after the checks |
| `vMAJOR.MINOR.PATCH` means | Build an App Store candidate | This commit's build was submitted to App Review; triggers nothing | Build an App Store candidate | Same as A |
| Verification gate | Mechanical | Mechanical | **Lost**: Xcode Cloud starts on the tag push and nothing checks the commit's run | Mechanical |
| New cost | None | A `v` tag that reports rather than gates | None | An App Store Connect API key in secrets, and API code |

## Decision

Option B. A commit becomes buildable only through an annotated `tf-MAJOR.MINOR.PATCH-BUILD` tag
whose commit has its own successful "Tests" run for a push to `main`. `vMAJOR.MINOR.PATCH` marks the
commit whose build was submitted to App Review and triggers nothing.

| Branch or ref | Moved by | Condition | Consumed by |
|---------------|----------|-----------|-------------|
| `main` | Developers | Normal pushes | GitHub Actions "Tests": tests, coverage, Sonar; it promotes nothing |
| Tag `tf-MAJOR.MINOR.PATCH-BUILD` | Maintainer | Annotated, on `main`, matches `MARKETING_VERSION` | GitHub Actions "TestFlight" |
| `testflight` | The "TestFlight" workflow | Tag checks pass and the tagged commit's own "Tests" run succeeded; fast-forward only | Xcode Cloud "Internal TestFlight (verified main)" |
| Tag `vMAJOR.MINOR.PATCH` | Maintainer, after submitting the build in App Store Connect | Annotated, on `main`, matches `MARKETING_VERSION`, verified, and carries the `tf-` tag of that version | GitHub Actions "TestFlight": it reports and moves nothing |

Supporting rules:

- **`BUILD` counts the TestFlight builds of a marketing version**, so consecutive rounds of
  unreleased work need no version bump, and the version in the tag always matches the version in the
  build.
- **Containment in `testflight` is not proof of verification**: a failing commit followed by a
  passing one is also contained. The gate reads the tagged commit's own "Tests" run through the
  GitHub API, so the tagged commit must be the head of its push to `main`.
- **A non-triggering `v` tag stays honest** through the same tag checks plus one more: the tagged
  commit must carry a `tf-` tag of the same version, that is, a TestFlight build of that exact
  commit exists. The check reports after the fact and can start nothing, so a wrong marker is fixed
  by moving the tag.
- **A release tag may be moved only while no build of that version was submitted** to App Review or
  released, and only to a later commit on `main`. After submission it is never moved or reused; a
  bad release is fixed with a new patch version.
- **The branch keeps the name `testflight`**: it names the destination, and renaming it would mean a
  hand-made move of a branch only CI may move, a second Xcode Cloud edit and a split in the Builds
  page history, for a cosmetic gain.

## Rejected alternatives

- **Keep Xcode Cloud on `main`.** Untested builds reach TestFlight while checks still run.
- **Promote every green `main` commit and throttle elsewhere** (schedule, path filter, a skip marker
  in commit messages). Every rule still guesses which commits testers want, and a wrong guess costs a
  build; only the person tagging knows.
- **Trigger Xcode Cloud from GitHub Actions through the App Store Connect API.** Needs an API key in
  repository secrets and custom code; a branch push achieves the same gate without secrets.
- **Protect `main` and merge only through pull requests with required checks.** Blocks the
  direct-push workflow and still checks the pull request head rather than the merged commit.
- **Move everything to GitHub Actions** (signing certificates, profiles and an App Store Connect key
  in secrets) **or everything to Xcode Cloud** (no convenient llvm-cov export for Sonar, no parallel
  jobs, tighter compute limits).
- **A lightweight tag, or a free-form tag name.** The annotation carries intent, date and message,
  and tying the name to `MARKETING_VERSION` makes the App Store Connect build list and the tag list
  line up.
- **A hand-moved `testflight-ready` branch, or manual `workflow_dispatch` only.** Hand-moved build
  branches get force-pushed and reset, and without a tag nothing records which commit went to
  testers.

## Consequences

- One tag namespace requests builds. `vMAJOR.MINOR.PATCH` records that a version was submitted; it
  is not a request to build one.
- A release candidate cannot cost a second build of a commit already built for TestFlight, and a
  merge to `main` no longer produces a build.
- The submitted build is a TestFlight build by construction, so a release candidate always had a
  TestFlight round.
- `testflight` is a record of verified commits and is never pushed by hand or force-pushed. A stale
  `testflight` branch no longer means CI is broken.
- One Xcode Cloud workflow remains, and its description in App Store Connect states which commits it
  builds and why. Builds already uploaded stay in TestFlight independently of the workflow that
  produced them.
- The `release` branch and its Xcode Cloud workflow are gone; nothing outside the repository watched
  them.
