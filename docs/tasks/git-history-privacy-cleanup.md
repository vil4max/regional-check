# Git history privacy cleanup

Assignee: regional-check-d5
State: done
Requested by: agent-engineering-kit-40 relaying owner request (2026-09-17)
Evidence: audit below (mirror of origin, 288 commits, 29 refs); live wording removed in b236703; `just verify` OK; landed 9466e84..ec119e3; owner accepted no rewrite (relayed by github-privacy-revision, 2026-09-17)
Owned files: `docs/tasks/git-history-privacy-cleanup.md`
Out of scope: rewriting history, force pushes, tag re-creation, installing tools, contacting GitHub Support
Failure conditions: a sensitive path or secret in any published ref is missed; the audit changes a ref; the plan omits the tag-gated release, `testflight`/`release`, Xcode Cloud, open PRs, or live worktrees

## Goal

List every path in the published history of this public repository that
matches the privacy gate (personal diaries, career or social notes, naming
brainstorms, competitive research, business strategy, learning plans, private
system names, machine paths, secrets), and either record that there is none or
prepare a rewrite plan for owner approval.

## Audit (2026-09-17)

Source: fresh `git clone --mirror` of `origin` (29 refs: `main`, `testflight`,
`release`, 10 tags `v1.0.0`…`v3.0.0`, 16 `refs/pull/*`), 288 commits, 519 paths
ever present. Local-only `refs/codex/*` and `refs/copilot/*` checkpoints are not
published and were excluded. Content was scanned in every commit for home
paths (`/Users/<name>`), career and social terms, diaries and learning plans,
competitive or business strategy, naming brainstorms, and secret shapes
(private keys, `ghp_`, `sk-`, `AKIA`, `sonar.login`, `password=`); commit
messages, authors, and trailers were checked too.

No secrets, no `/Users/<name>` paths, no diaries, social or LinkedIn notes,
learning plans, naming brainstorms, or competitive research were found.

| Path | First..last commit | Why it could be sensitive | Remove or keep |
|---|---|---|---|
| `docs/planning/storekit-subscription-plan.md` (earlier `docs/storekit-subscription-plan.md`) | 349267e..live | Career intent: "portfolio / interviewer", "a Senior iOS interviewer can install…" | Keep in history; live wording removed on the owner's request (2026-09-17), including "interview talking points" headings |
| `README.md` (older versions) | ..349267e | "portfolio piece" | Keep; current README no longer says it |
| `docs/agent-pilot-brief.md` | 2f73260..349267e | Machine path `~/Developer/Personal/apps/regional-check`; the same path is live in `docs/engineering/agent-workflow.md` | Keep |
| `scripts/bootstrap-personal-repo.sh` | 2f73260..71ca769 | Former private tool names and `$HOME/Developer/GitHub/…` layout | Keep |
| `docs/host-backends.md`, `runtime.local.yml.example` | 2f73260..71ca769 | Former editor/host setup | Keep |
| Commit metadata | all | Owner name and personal e-mail as author/committer (538 identities); a commit message names the local directory layout | Keep; a rewrite would change every commit |
| `docs/product-charter.md`, `docs/backlog.md`, `docs/migration-plan.md`, `README_Subscriptions.md` | afa0f82..349267e | Product principles, backlog, bundle ID, App Group ID — product facts, not personal material | Keep |

## Recommendation

Decision: no rewrite, accepted by the owner (2026-09-17, relayed by the
`github-privacy-revision` session).

Do not rewrite history. Nothing in the published refs meets the privacy gate
strongly enough to justify it. The career-intent wording was still live on
`main`; it was removed from the current files instead (owner, 2026-09-17).

If the owner still wants a rewrite, the plan is:

1. Freeze: integrator stops landing; no live worktrees with unlanded commits
   (`just prune-worktrees`), no open PRs.
2. Tool: `git filter-repo` (already installed at `/opt/homebrew/bin`), run in a
   fresh `--mirror` clone under the historical bank `work/` directory, after a
   `git bundle create --all` backup stored next to it.
3. Changes: every commit after the first touched path gets a new SHA, so
   `main`, `testflight`, `release`, and all 10 tags move, including the
   published `v3.0.0` release tag. The release process forbids moving a
   published tag; the owner must accept re-creating tags or publish history
   without them.
4. Push: force-push all branches and tags from the mirror (owner-only).
   `refs/pull/*` cannot be pushed; GitHub keeps old PR refs and cached commit
   views until GitHub Support purges them (owner contact).
5. After: Xcode Cloud builds `testflight`/`release` from new SHAs; the
   `promote-release.sh` check needs a green "Tests and coverage" run per new
   tagged SHA; every local clone and worktree must be re-cloned, not pulled;
   other sessions stop and re-clone before further work.
