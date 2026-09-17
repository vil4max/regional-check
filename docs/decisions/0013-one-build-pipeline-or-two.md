# ADR 0013 — One build pipeline, not two

Status: Accepted 2026-09-17 (owner, this session). Supersedes the `release` and
`vMAJOR.MINOR.PATCH` rows of [ADR 0010](0010-gated-testflight-and-tag-releases.md)
and [ADR 0012](0012-tag-gated-testflight-builds.md): one tag namespace requests
builds, and a release tag marks a submitted commit instead of requesting a build.
Everything else in both stands.

Follows ADR 0010 (gate every Xcode Cloud build on a branch only CI moves) and
ADR 0012 (a tag, not a merge, requests a TestFlight build).

## Context

After ADR 0012 the repository carried two of everything: two tag namespaces
(`tf-MAJOR.MINOR.PATCH-BUILD`, `vMAJOR.MINOR.PATCH`), two branches only CI moves
(`testflight`, `release`), two GitHub Actions workflows with two promotion
scripts, and two Xcode Cloud workflows.

The two Xcode Cloud workflows were, per the configuration table in
[release-process.md](../operations/release-process.md), identical in everything
that produces an artifact:

| | "Internal TestFlight (verified main)" | "App Store candidate (release tag)" |
|---|---|---|
| Actions | Archive - iOS, scheme `RegionalCheck`, distribution preparation App Store Connect | Same |
| Post-actions | TestFlight Internal Testing - iOS, group Friends&Family | Same |
| Differs in | Description, and the branch it starts on | — |

So a "TestFlight build" and an "App Store candidate" were the same artifact,
built the same way, landing in the same place. Submission to App Review is a
manual step in App Store Connect (release-process.md, "Releasing a version")
where the owner picks a build. Nothing about that step reads the `release`
branch.

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
| Goes away | Nothing | `promote-release.sh`, the promotion of `release`, one Xcode Cloud workflow; `release.yml` shrinks to a check | Both branches, both workflows, both scripts | Both branches, both promotion scripts |
| Verification gate | Mechanical | Mechanical | **Lost** — Xcode Cloud starts on the tag push, nothing checks the commit's run | Mechanical |
| New cost | Rename only | A `v` tag that reports rather than gates | — | An App Store Connect API key in secrets, and API code |

Xcode Cloud does support option C: a "Tag Changes" start condition filters on
"tags beginning with", which `tf-` and `v` already satisfy (no regular
expressions, prefix only).

## Decision

**B.** The `tf-MAJOR.MINOR.PATCH-BUILD` tag is the only thing that requests a
build; `vMAJOR.MINOR.PATCH` returns to marking the commit whose build was
submitted to App Review, and triggers nothing.

| Branch or ref | Moved by | Condition | Consumed by |
|---------------|----------|-----------|-------------|
| `main` | Developers and agent sessions | Normal pushes | GitHub Actions `tests.yml` — tests, coverage, Sonar; it promotes nothing |
| Tag `tf-MAJOR.MINOR.PATCH-BUILD` | Owner | Annotated, on `main`, matches `MARKETING_VERSION` | GitHub Actions `testflight.yml` |
| `testflight` | `scripts/promote-testflight.sh` via `testflight.yml` | Tag checks pass and the "Tests and coverage" run for a push of the tagged commit itself succeeded; fast-forward only | Xcode Cloud "Internal TestFlight (verified main)" |
| Tag `vMAJOR.MINOR.PATCH` | Owner, after submitting the build in App Store Connect | Annotated, on `main`, matches `MARKETING_VERSION`, verified, and carries the `tf-` tag of that version | GitHub Actions `release.yml` — it reports, moves nothing, and humans read the tag |

The branch keeps the name `testflight`: it names the destination, not a
development activity, and renaming it would mean a hand-made move of a branch
only CI may move, a second Xcode Cloud edit, and a split in the Builds page
history — cosmetic gain, real cost.

The verification gate is untouched: a commit still becomes buildable only
through an annotated `tf-` tag whose commit has its own successful "Tests and
coverage" run for a push of that exact commit to `main`.

## Owner decision, 2026-09-17

Asked which outcome to take, the owner chose "B, keep `testflight`". On the
scope of the removal: "лишние воркфло удалить", clarified as "я имел ввиду -
удалить ненужные в апсторконнект" — the second Xcode Cloud workflow goes. Asked
separately whether the `v` tag should keep a mechanical check now that it moves
nothing, the owner chose to keep it: a `v*` push runs the same tag checks plus
"this commit has a `tf-` tag of the same version", and promotes nothing.

## Open questions, answered

1. **Are the two Xcode Cloud workflows identical?** Yes. Read in App Store
   Connect on 2026-09-17, field by field: Xcode and macOS "Latest Release", no
   environment variables, Actions "Archive - iOS" with scheme `RegionalCheck`
   and distribution preparation "App Store Connect", Post-actions "TestFlight
   Internal Testing - iOS" on artifact "Archive - iOS" to group Friends&Family.
   Only the description and the start condition (`testflight` vs `release`)
   differ. Manage Workflows held exactly these two; the three groups on the
   Builds page are branches (`testflight`, `release`, `main`), not workflows.
   One drift found: the description of "Internal TestFlight (verified main)"
   still carried the ADR 0010 wording ("Archives every main commit that
   passed…"), which the configuration table already claimed was updated for
   ADR 0012 — the owner corrects it with this change.
2. **What keeps a non-triggering `v` tag honest?** The "Release marker"
   workflow: `scripts/check-release-tag.sh` runs the shared tag checks and adds
   `assert_testflight_round`, which fails unless the tagged commit carries a
   `tf-MAJOR.MINOR.PATCH-BUILD` tag — that is, unless a TestFlight build of that
   exact commit exists, which after this ADR is what a submitted build is. It
   reports after the fact and can start nothing; that is the whole point, since
   a wrong marker is fixed by moving the tag. Rejected: containment in
   `testflight`, which every earlier commit also satisfies.
3. **What happens to the build history grouped under `release`?** Nothing that
   is needed. Owner, 2026-09-17: nothing of 3.0.0 has been tested or submitted
   yet, so no App Review correspondence or support case reads that group. Xcode
   Cloud keeps build artifacts for 30 days regardless
   ([Apple](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow)),
   and builds already uploaded stay in TestFlight and App Store Connect
   independently of the workflow that produced them. App Store Connect's own
   confirmation dialog states the effect: "The associated builds will no longer
   be shown by default". Verified after the deletion on 2026-09-17: the
   `release` group is gone from the Xcode Cloud Builds page, while TestFlight
   still lists every 3.0.0 build, including the one that workflow archived, as
   Ready to Submit for Friends&Family. The `release` branch itself
   is left in place, frozen at `v3.0.0`, as the record of what that pipeline
   built; nothing moves it again.
4. **What should the remaining branch be called?** `testflight`, unchanged — see
   the decision above.
5. **Does anything outside the repository watch `release`?** No. The repository
   has no webhooks, no rulesets and no branch protection (checked 2026-09-17),
   the README carries no badges, and the owner confirmed there is no
   notification, integration or bookmark on the branch or the workflow.

## Consequences

- One tag namespace requests builds. `vMAJOR.MINOR.PATCH` is a record that a
  version was submitted, placed after submission, not a request to build one.
- ADR 0012's follow-up "must a release candidate have had a TestFlight round?"
  is answered by construction: the submitted build *is* a TestFlight build.
- The release runbook loses a step (tag, wait, confirm promotion, confirm build)
  and gains one (mark the submitted commit).
- Xcode Cloud spends strictly less: a release candidate can no longer cost a
  second build of a commit that was already built for TestFlight.
- A wrong `v` tag can no longer start a build; "Release marker" still reports
  it, and the fix is to move the tag.
- `v3.0.0` predates this ADR: it requested the candidate build of a commit that
  was never submitted. Because no build of 3.0.0 has been submitted or released,
  the owner may still move it onto the commit that is eventually submitted
  (ADR 0010, and invariant 6 in release-process.md). Owner-only, and out of this
  change.

## Migration

Landed together, per "Changing the flow" in release-process.md:

- Removed: `scripts/promote-release.sh` and the promotion of `release`.
- Rewritten: `.github/workflows/release.yml` as "Release marker", running
  `scripts/check-release-tag.sh`; `scripts/lib/promote.sh` gains
  `assert_testflight_round` and keeps `promote_branch` for its one caller,
  `promote-testflight.sh`.
- Rewritten: release-process.md (invariants, systems, Xcode Cloud table,
  "Releasing a version", failure handling), `AGENTS.md` versioning rules.
- In App Store Connect, done 2026-09-17 on the owner's instruction ("удалить
  ненужные в апсторконнект") and in front of them: the Xcode Cloud workflow "App
  Store candidate (release tag)" is deleted, and the stale description of
  "Internal TestFlight (verified main)" — still the ADR 0010 wording — is
  replaced with the text in the configuration table. Manage Workflows now lists
  one workflow.
- Left alone: the `release` branch and every existing `v` tag.
