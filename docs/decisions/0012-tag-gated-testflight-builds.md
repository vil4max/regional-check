# ADR 0012 — TestFlight builds come from a tag, not from every merge

Status: Proposed

Supersedes the `testflight` row of [ADR 0010](0010-gated-testflight-and-tag-releases.md). The rest of ADR 0010 stands: Xcode Cloud still builds only `testflight` and `release`, still runs no tests, and CI still moves both branches by fast-forward only.

## Context

ADR 0010 moved `testflight` from every push to `main` that passed "Tests and coverage", and listed the cost as a consequence: "Every commit that passes checks on `main`, including documentation-only commits, produces an internal TestFlight build and spends Xcode Cloud time."

That cost arrived. Through the RD redesign waves the integrator lands task branches onto `main` several times a day, and each merge produced an archive, an upload, and a TestFlight build. On 2026-09-17 the owner reported the App Store Connect limits exhausted, with most of the builds nobody was asked to test.

The verification the branch represents is not the problem: testers need verified builds. The problem is that "verified" was also being read as "wanted by testers", and only the owner knows which commit that is. A documentation commit is as verified as a finished feature.

## Decision

`testflight` moves only for an annotated tag `tf-MAJOR.MINOR.PATCH-BUILD` (for example `tf-3.0.0-2`), pushed by the owner.

| Branch or ref | Moved by | Condition | Consumed by |
|---------------|----------|-----------|-------------|
| `main` | Developers and agent sessions | Normal pushes | GitHub Actions `tests.yml` — tests, coverage, Sonar; it promotes nothing |
| Tag `tf-MAJOR.MINOR.PATCH-BUILD` | Owner | Annotated, on `main`, matches `MARKETING_VERSION` | GitHub Actions `testflight.yml` |
| `testflight` | `scripts/promote-testflight.sh` via `testflight.yml` | Tag checks pass and the "Tests and coverage" run for a push of the tagged commit itself succeeded; fast-forward only | Xcode Cloud "Internal TestFlight (verified main)" |
| Tag `vMAJOR.MINOR.PATCH` | Owner | Annotated, on `main`, matches `MARKETING_VERSION` | GitHub Actions `release.yml` |
| `release` | `scripts/promote-release.sh` via `release.yml` | Same run check; fast-forward only | Xcode Cloud "App Store candidate (release tag)" |

Both promotions now ask one question — did the owner annotate a commit on `main` that GitHub Actions verified, carrying the version the tag claims? — so their checks live in `scripts/lib/promote.sh` and cannot drift apart.

Two supporting decisions:

- **The `BUILD` suffix counts builds of a marketing version**, so consecutive TestFlight rounds of unreleased work (`tf-3.0.0-1`, `tf-3.0.0-2`) do not need a version bump, and the version in the tag always matches the version in the build. `promote-testflight.sh` enforces the match, which catches a tag pushed against a stale or half-bumped `MARKETING_VERSION`.
- **A release tag no longer requires the commit to be on `testflight`.** ADR 0010 already recorded that containment proves nothing on its own; the commit's own "Tests and coverage" run is the gate, and `promote-release.sh` checks it directly. Requiring containment now would mean a `tf-` tag before every `v` tag and two Xcode Cloud builds of one commit.

## Rejected alternatives

- **Keep promoting every green `main` commit and throttle elsewhere** (schedule, path filter, `[skip tf]` in commit messages). Every rule still guesses which commits testers want; only the owner knows, and a wrong guess costs a build.
- **A moving `testflight-ready` branch the owner pushes by hand.** Invariant 2 of the release process exists because hand-moved build branches get force-pushed and reset; a tag is immutable, records who and when, and is the mechanism the release path already uses.
- **Manual `workflow_dispatch` only, with no tag.** Nothing in the repository then records which commit went to testers. The workflow keeps a `tag` input for reruns, but the tag stays the source of truth.
- **A lightweight tag.** Annotation carries the owner's intent, date, and message; the scripts reject lightweight tags for the same reason on both paths.
- **Free-form tag names (`tf-<anything>`).** The name would stop describing the build. Tying it to `MARKETING_VERSION` makes the App Store Connect build list and the tag list line up.
- **Drop the "own successful run" check for TestFlight, since the owner now picks the commit.** The owner picks what testers get; CI decides whether it is fit to build. Testers would otherwise receive a build whose checks failed.

## Consequences

- A merge to `main` no longer produces a build. Nobody sees a change in TestFlight until the owner tags it, and a stale `testflight` branch no longer means CI is broken.
- The tagged commit must be the head of its push to `main`, exactly as for a release tag, because a commit in the middle of a multi-commit push gets no "Tests and coverage" run of its own. Invariant 7 (per-commit runs on `main`) now serves both tags.
- Xcode Cloud settings are unchanged: both workflows still start on branch changes to `testflight` and `release`. Only the description of "Internal TestFlight (verified main)" in App Store Connect is now wrong and needs editing.
- The owner gains a step per TestFlight round, and both branches now move only by owner action.
