# ADR 0013 — One build pipeline or two

Status: Proposed (owner decision pending the investigation in
[tasks/collapse-build-pipelines.md](../tasks/collapse-build-pipelines.md))

Follows [ADR 0010](0010-gated-testflight-and-tag-releases.md) (gate every Xcode
Cloud build on a branch only CI moves) and
[ADR 0012](0012-tag-gated-testflight-builds.md) (a tag, not a merge, requests a
TestFlight build).

## Context

After ADR 0012 the repository carries two of everything: two tag namespaces
(`tf-MAJOR.MINOR.PATCH-BUILD`, `vMAJOR.MINOR.PATCH`), two branches only CI moves
(`testflight`, `release`), two GitHub Actions workflows with two promotion
scripts, and two Xcode Cloud workflows.

The two Xcode Cloud workflows are, per the configuration table in
[release-process.md](../operations/release-process.md), identical in everything
that produces an artifact:

| | "Internal TestFlight (verified main)" | "App Store candidate (release tag)" |
|---|---|---|
| Actions | Archive - iOS, scheme `RegionalCheck`, distribution preparation App Store Connect | Same |
| Post-actions | TestFlight Internal Testing - iOS, group Friends&Family | Same |
| Differs in | Description, and the branch it starts on | — |

So a "TestFlight build" and an "App Store candidate" are the same artifact,
built the same way, landing in the same place. Submission to App Review is a
manual step in App Store Connect (release-process.md, "Releasing a version",
step 7) where the owner picks a build. Nothing about that step reads the
`release` branch.

A second observation, raised by the owner on 2026-09-17: the branches look like
a broken branching model. They are not one. This repository is trunk-based — one
`main`, short-lived task branches in worktrees, direct pushes — and `testflight`
and `release` are build pointers, closer to `gh-pages` or a deploy ref: nobody
commits to them, nobody branches from them, only CI moves them. They exist
because ADR 0010 needed GitHub Actions to run *before* Xcode Cloud without an
App Store Connect API key in repository secrets, and a branch push was the
trigger that achieved it. The confusion is that a wire is named like a branch
and sits in the same list as `main`.

## Options

| | A — Keep two, rename | B — One pipeline, `v` becomes a marker | C — No branches, Xcode Cloud starts on tags | D — GitHub Actions calls the App Store Connect API |
|---|---|---|---|---|
| Requests a build | `tf-` tag → `testflight`; `v` tag → `release` | `tf-` tag only | `tf-` and `v` tags, read by Xcode Cloud directly | A GitHub Actions job, after the checks |
| `vMAJOR.MINOR.PATCH` means | Build an App Store candidate | This commit's build was submitted to App Review; triggers nothing | Build an App Store candidate | Same as A |
| Goes away | Nothing | `release.yml`, `promote-release.sh`, branch `release`, one Xcode Cloud workflow | Both branches, both workflows, both scripts | Both branches, both promotion scripts |
| Verification gate | Mechanical | Mechanical | **Lost** — Xcode Cloud starts on the tag push, nothing checks the commit's run | Mechanical |
| New cost | Rename only | A `v` tag nobody enforces | — | An App Store Connect API key in secrets, and API code |

Xcode Cloud does support option C: a "Tag Changes" start condition filters on
"tags beginning with", which `tf-` and `v` already satisfy (no regular
expressions, prefix only).

## Recommendation

**B, taking A's rename for the one branch that remains.**

It removes half the machinery without touching the one thing that machinery
buys: a commit cannot be built unless GitHub Actions verified that exact commit.
It also makes a rule mechanical that would otherwise be a checklist line — the
submitted build is necessarily one that went through a TestFlight round, because
it *is* the TestFlight build.

C is the larger simplification and the wrong trade: it gives back the gate ADR
0010 was written to install, leaving only the owner's discipline and the
advisory `just tf-check`. D remains rejected for ADR 0010's reason, which has
not changed.

## Open questions for the investigation

1. Confirm against App Store Connect, not this table, that the two Xcode Cloud
   workflows really are identical in Actions and Post-actions. The repository
   copy is a mirror and may have drifted.
2. If `vMAJOR.MINOR.PATCH` triggers nothing, what keeps it honest? Options: a
   checklist line; or a small check on a `v*` push that the tagged commit also
   carries a `tf-` tag of the same version, which is the link `promote-release.sh`
   enforces today.
3. What happens to the build history grouped under the `release` branch on the
   App Store Connect Builds page when that workflow is deleted, and does
   anything (support, App Review correspondence) depend on reading it?
4. What should the remaining branch be called so it does not read as a
   development branch.
5. Does anything outside this repository watch `release` — a badge, a
   subscription, a bookmark?

## Consequences if B is accepted

- One tag namespace requests builds; `vMAJOR.MINOR.PATCH` returns to what it
  meant before ADR 0010: a record that a version shipped, placed after
  submission, not a request to build one.
- ADR 0012's follow-up "must a release candidate have had a TestFlight round?"
  is answered by construction rather than by policy.
- The release runbook loses a step (tag, wait, confirm promotion, confirm build)
  and gains one (mark the submitted commit).
- Xcode Cloud spends strictly less: a release candidate can no longer cost a
  second build of a commit that was already built for TestFlight.
