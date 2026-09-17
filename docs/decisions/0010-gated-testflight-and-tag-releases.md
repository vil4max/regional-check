# ADR 0010 — Gated TestFlight builds and tag-driven releases

Status: Accepted. The `testflight` trigger below is superseded by [ADR 0012](0012-tag-gated-testflight-builds.md) (Proposed): the branch now moves for an annotated `tf-MAJOR.MINOR.PATCH-BUILD` tag, not for every verified push to `main`, and a release tag no longer requires containment in `testflight`. Everything else here stands.

## Context

Until 2026-09-16 Xcode Cloud archived and uploaded every push to `main` to TestFlight, and ran its own Test action. GitHub Actions ran the same tests plus coverage and Sonar. Two problems followed:

- Tests ran twice on two systems with two failure signals.
- Xcode Cloud started as soon as `main` moved, before GitHub Actions finished, so TestFlight could receive a build whose checks later failed.

Releases had no mechanical link to verification either: `AGENTS.md` asked for an annotated tag after publishing, but nothing tied the App Store build to a checked commit or to `MARKETING_VERSION`.

Constraints: one owner plus agent sessions pushing directly to `main`; Xcode Cloud owns signing (no certificates in repository secrets); the repository is public, so GitHub Actions macOS minutes are free; Xcode Cloud has 25 compute hours a month.

## Decision

Split responsibilities by system and gate every Xcode Cloud build on a branch that only CI moves.

| Branch or ref | Moved by | Condition | Consumed by |
|---------------|----------|-----------|-------------|
| `main` | Developers and agent sessions | Normal pushes | GitHub Actions `tests.yml` |
| `testflight` | `promote-testflight` job in `tests.yml` | Unit tests, snapshot tests, and Sonar scan succeeded for a push to `main`; fast-forward only | Xcode Cloud workflow "Internal TestFlight (verified main)" |
| Tag `vMAJOR.MINOR.PATCH` | Owner | Annotated, on `main`, matches `MARKETING_VERSION` | GitHub Actions `release.yml` |
| `release` | `scripts/promote-release.sh` via `release.yml` | Tag checks pass, the "Tests and coverage" run for a push of the tagged commit itself succeeded, and the commit is contained in `testflight`; fast-forward only | Xcode Cloud workflow "App Store candidate (release tag)" |

Xcode Cloud has no Test action. The operational steps live in [release-process.md](../operations/release-process.md).

## Rejected alternatives

- **Keep Xcode Cloud on `main`.** Untested builds reach TestFlight while checks still run.
- **Trigger Xcode Cloud from GitHub Actions through the App Store Connect API (`ciBuildRuns`).** Needs an App Store Connect API key in repository secrets and custom API code; a branch push achieves the same gate without secrets. Verified 2026-09-16: Xcode Cloud starts from a push made with the workflow `GITHUB_TOKEN`.
- **Protect `main` and merge only through pull requests with required checks.** Blocks the direct-push workflow of the owner and agent sessions, and still checks the PR head rather than the merged commit.
- **Move everything to GitHub Actions.** Requires managing signing certificates, profiles, and an App Store Connect key in secrets.
- **Move everything to Xcode Cloud.** No convenient llvm-cov export for Sonar, no parallel jobs, and tighter compute limits.
- **Build App Store candidates from every `testflight` push.** Release moments stay implicit; tags make them explicit and tie them to `MARKETING_VERSION`.

## Consequences

- A tag no longer marks an already published release: it requests an App Store candidate build. `AGENTS.md` versioning rules reflect this.
- `testflight` and `release` are records of verified commits and must never be pushed by hand or force-pushed. A bad release is fixed forward with a new patch version.
- Every commit that passes checks on `main`, including documentation-only commits, produces an internal TestFlight build and spends Xcode Cloud time.
- Containment in `testflight` alone is not proof: a failing commit followed by a passing one is also contained. `promote-release.sh` therefore reads the tagged commit's own "Tests and coverage" run through the GitHub API (`actions: read`), and the release commit must be the head of its push so that such a run exists.
- A tag is immutable only once its version reaches App Review. Before that the owner may move it to a later commit on `main` (2026-09-17: `v3.0.0` was tagged and built but never submitted). Rejected: never moving tags at all, which burns a marketing version on every unsubmitted candidate; moving tags after submission, which would make the App Store build and the tag disagree.
- The first version of the script (2026-09-16) checked only containment; the gap was found in OneCart and closed in both repositories on 2026-09-17.
