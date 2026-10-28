# ADR 0017 — Pull requests auto-merge once the required check passes

Status: Accepted (owner, 2026-10-28). Supersedes the rejected alternative "Protect `main` and merge
only through pull requests with required checks" in [ADR 0013](0013-one-build-pipeline-or-two.md);
the rest of ADR 0013 stands.

## Context

Changes reach `main` through pull requests, and someone had to wait for CI to finish before
merging each one by hand. GitHub auto-merge removes the wait, but it waits only for required
status checks: with none on `main`, an auto-merge request lands at once, before CI has run.

## Decision

The owner decided on 2026-10-28:

- The repository allows auto-merge, and a merged pull request's branch is deleted.
- `main` requires the "lint, build and test" check of the "Tests" workflow, without requiring the
  branch to be up to date with `main` (`strict: false`). The other protection settings are
  unchanged: admins included, no force push, no deletion of `main`.
- A pull request is merged by squash, so each merge is one push to `main`.

## Consequences

- A pull request with auto-merge on lands by itself once its check passes; nobody waits by hand.
- A direct push to `main` without a passing check is rejected, so changes reach `main` only
  through pull requests. ADR 0013 rejected this for blocking the direct-push workflow; the owner
  accepted that cost.
- The check runs on the pull request head, not the merged commit. That stays safe for builds:
  each squash merge is its own push to `main` with its own "Tests" run, and a `tf-` tag still
  needs that run to have passed (release-process.md, invariant 3).
- These settings live on GitHub, not in the repository; this record and
  [release-process.md](../operations/release-process.md) describe them.
