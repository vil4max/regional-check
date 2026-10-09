#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LINT="$REPO_ROOT/scripts/spec/brief_lint.py"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-brief-lint.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
brief() { printf '# Task\n\nAssignee: %s\nState: %s\nEvidence: %s\nDepends-on: %s\n' "$2" "$3" "$4" "$5" >"$FIXTURE/docs/tasks/$1.md"; }
# SDLC-D-013: write a round-profile brief, then fill in its Plan hash by asking the lint itself to
# compute it (the same code path a writer or --compute-plan-hash would use), so the fixture proves a
# correct hash is accepted without hard-coding a sha256 value in this test.
insert_plan_hash() {
  local file="$1"
  local hash
  hash="$(python3 "$LINT" --compute-plan-hash "$file")"
  python3 - "$file" "$hash" <<'PYEOF'
import sys
from pathlib import Path
path, computed = sys.argv[1], sys.argv[2]
p = Path(path)
text = p.read_text(encoding="utf-8")
text = text.replace("Profile: round\n", f"Profile: round\nPlan hash: {computed}\n", 1)
p.write_text(text, encoding="utf-8")
PYEOF
}
# SDLC-D-049 point 3: fill the approval record's quoted Plan hash the same way - @PLANHASH@ in
# full, @HEAD@/@TAIL@ as the abbreviated <head>…<tail> form app records use.
insert_approved_plan_hash() {
  local file="$1"
  local hash
  hash="$(python3 "$LINT" --compute-plan-hash "$file")"
  python3 - "$file" "$hash" <<'PYEOF'
import sys
from pathlib import Path
path, computed = sys.argv[1], sys.argv[2]
p = Path(path)
text = p.read_text(encoding="utf-8")
text = text.replace("@PLANHASH@", computed).replace("@HEAD@", computed[:8]).replace("@TAIL@", computed[-5:])
p.write_text(text, encoding="utf-8")
PYEOF
}

mkdir -p "$FIXTURE/docs/tasks/done"
brief base session open pending none
brief follow-up unassigned blocked pending base
brief done/shipped session done 'abc1234 ios-verify PASS' none
printf '# Template\n\nState: open | claimed | blocked | done\n' >"$FIXTURE/docs/tasks/template.md"
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\n\n## Writer steps\n\n- [x] Parse the feed: tests pass — 3f2a9c1\n- [ ] Render the list\n\n## Current checklist\n\n- [x] Owner approved scope\n' >"$FIXTURE/docs/tasks/writer-ok.md"
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\nSchema: 2\nProfile: fast\n\n### Slice 9 dispatch — widget polish (2026-09-24)\n\nObjective: polish the widget per the mockup.\n\nSources: REQ-WIDGET-001, mockup: widget-empty-state (SDLC-D-005)\n\nIntended deviations: disc uses 48pt not 64pt — SDLC-D-003 owner call, 2026-09-23\n\nBoundaries: only Sources/Widget/**; no push\n\nOutput: READY with branch, SHA, gate result\n\n## Writer steps\n\n- [ ] widget polish: ios-verify\n' >"$FIXTURE/docs/tasks/dispatch-ok.md"
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\n\n### Some dispatch heading with nothing else\n\n## Writer steps\n\n- [ ] step: check\n' >"$FIXTURE/docs/tasks/schema1-dispatch-ignored.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: unit test added, ios-verify PASS\nSchema: 2\nProfile: fast\n' >"$FIXTURE/docs/tasks/profile-fast-ok.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: unit test added, ios-verify PASS\nSchema: 2\nProfile: fast\n\n## Writer steps\n\n- [x] Parse the feed: tests pass — 3f2a9c1\n- [x] Render the list: tests pass — 4a1b8e2\n' >"$FIXTURE/docs/tasks/writer-steps-all-ticked-done.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: reproduced as a failing test first, fixed, ios-verify PASS, one review round, no findings\nSchema: 2\nProfile: fix\nuser-visible: none\n' >"$FIXTURE/docs/tasks/profile-fix-ok.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: coverage matrix closed with no GAP, review clean\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nmodel: sonnet\neffort: medium\nproduct question: does removing the empty state increase task completion?\nmetric: task completion rate\nthreshold: >= 95%%\nuser-visible: none\n\n<!-- spec_trace:matrix:begin -->\n\n## Coverage matrix\n\n| Requirement | Status | Detail |\n|---|---|---|\n| REQ-WIDGET-001 | OK | passed |\n\n<!-- spec_trace:matrix:end -->\n' >"$FIXTURE/docs/tasks/profile-round-ok.md"
insert_plan_hash "$FIXTURE/docs/tasks/profile-round-ok.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n### Round 1 review — widget (2026-09-24)\n\nReview SHA: 0000000000000000000000000000000000000000\n\n- [high][blocking][new] Sources/Checkout/CheckoutView.swift:88 — force-unwrap crashes when cart is empty\n- [low][non-blocking][new] Sources/Checkout/CheckoutView.swift:12 — missing doc comment\n\n### Round 2 review — widget (2026-09-24)\n\nReview SHA: 1111111111111111111111111111111111111111\n\n- [high][blocking][recurring] Sources/Checkout/CheckoutView.swift:88 — force-unwrap crashes when cart is empty\n- [medium][blocking][new] Sources/Checkout/CheckoutViewModel.swift:40 — duplicate completion still fires twice\n\n### Round 3 review — widget (2026-09-24)\n\nReview SHA: 2222222222222222222222222222222222222222\n\nNo findings.\n' >"$FIXTURE/docs/tasks/review-ok.md"
insert_plan_hash "$FIXTURE/docs/tasks/review-ok.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\nRepair extension approval: journal:2026-09-24#7\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n### Round 1 review — a (2026-09-24)\n\nReview SHA: 0000000000000000000000000000000000000000\n\n- [medium][blocking][new] Sources/A.swift:1 — bug a\n\n### Round 2 review — a (2026-09-24)\n\nReview SHA: 1111111111111111111111111111111111111111\n\n- [medium][blocking][new] Sources/B.swift:1 — bug b\n\n### Round 3 review — a (2026-09-24)\n\nReview SHA: 2222222222222222222222222222222222222222\n\n- [medium][blocking][new] Sources/C.swift:1 — bug c\n\n### Round 4 review — a (2026-09-24)\n\nReview SHA: 3333333333333333333333333333333333333333\n\n- [medium][blocking][new] Sources/D.swift:1 — bug d\n\n### Round 5 review — a (2026-09-24)\n\nReview SHA: 4444444444444444444444444444444444444444\n\n- [medium][blocking][new] Sources/E.swift:1 — bug e\n' >"$FIXTURE/docs/tasks/review-budget-approved.md"
insert_plan_hash "$FIXTURE/docs/tasks/review-budget-approved.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: fast\nOutage: 2026-09-24T02:10Z-02:47Z\nScope audit: no files outside Sources/Checkout touched; no push; no main\n' >"$FIXTURE/docs/tasks/outage-ok.md"
# Repair round 1, medium 1: a schema-1 brief (no Schema: field at all) that quotes the schema-2
# template inside a fence, before its first "## " heading, must stay schema 1 - the fenced
# "Schema: 2"/"Profile: ..." lines are an illustrative example, not this brief's own header.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\n\n```markdown\nSchema: 2\nProfile: fast | fix | round\n```\n\n## Notes\n\nSome notes here.\n' >"$FIXTURE/docs/tasks/fenced-schema-example.md"
# Repair round 1, medium 2: pairing/repair-counting must go by the round NUMBER in the heading,
# not physical text order - Round 2 placed before Round 1 in the document.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n### Round 2 review — widget (2026-09-24)\n\nReview SHA: 1111111111111111111111111111111111111111\n\n- [medium][blocking][recurring] Sources/Ordered.swift:1 — bug in ordering\n\n### Round 1 review — widget (2026-09-24)\n\nReview SHA: 0000000000000000000000000000000000000000\n\n- [medium][blocking][new] Sources/Ordered.swift:1 — bug in ordering\n' >"$FIXTURE/docs/tasks/review-out-of-order.md"
insert_plan_hash "$FIXTURE/docs/tasks/review-out-of-order.md"
# ...and per card (the nearest preceding "#### Card:" heading), not across cards - two cards each
# starting their own "Round 1" with a coincidentally identical finding must not cross-contaminate.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: card-a — first card\n\nmodel: sonnet\neffort: medium\nproduct question: does this help?\nmetric: rate\nthreshold: >= 90%%\nuser-visible: none\n\n### Round 1 review — shared (2026-09-24)\n\nReview SHA: 0000000000000000000000000000000000000000\n\n- [medium][blocking][new] Sources/Shared.swift:1 — shared bug text\n\n#### Card: card-b — second card\n\nmodel: sonnet\neffort: medium\nproduct question: does this help?\nmetric: rate\nthreshold: >= 90%%\nuser-visible: none\n\n### Round 1 review — shared (2026-09-24)\n\nReview SHA: 1111111111111111111111111111111111111111\n\n- [medium][blocking][new] Sources/Shared.swift:1 — shared bug text\n' >"$FIXTURE/docs/tasks/review-two-cards.md"
insert_plan_hash "$FIXTURE/docs/tasks/review-two-cards.md"
# Repair round 1, medium 2 (second pass): reviews kept together in a trailing "## Reviews"
# section, after every card, must still attribute to the card their heading names - not all land
# on whichever card happens to be last. Three cards, one repair round each (two "### Round N
# review" blocks per card): the pre-fix "nearest preceding card" heuristic put all six blocks on
# card-c (5 repair rounds, over the budget of 3); each card actually had only one repair.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: card-a — first card\n\nmodel: sonnet\nproduct question: does this help?\nmetric: rate\nthreshold: >= 90%%\nuser-visible: none\n\n#### Card: card-b — second card\n\nmodel: sonnet\nproduct question: does this help?\nmetric: rate\nthreshold: >= 90%%\nuser-visible: none\n\n#### Card: card-c — third card\n\nmodel: sonnet\nproduct question: does this help?\nmetric: rate\nthreshold: >= 90%%\nuser-visible: none\n\n## Reviews\n\n### Round 1 review — card-a (2026-09-24)\n\nReview SHA: 0000000000000000000000000000000000000000\n\n- [medium][blocking][new] Sources/A.swift:1 — bug a1\n\n### Round 2 review — card-a (2026-09-24)\n\nReview SHA: 1111111111111111111111111111111111111111\n\n- [medium][blocking][new] Sources/A.swift:1 — bug a2\n\n### Round 1 review — card-b (2026-09-24)\n\nReview SHA: 2222222222222222222222222222222222222222\n\n- [medium][blocking][new] Sources/B.swift:1 — bug b1\n\n### Round 2 review — card-b (2026-09-24)\n\nReview SHA: 3333333333333333333333333333333333333333\n\n- [medium][blocking][new] Sources/B.swift:1 — bug b2\n\n### Round 1 review — card-c (2026-09-24)\n\nReview SHA: 4444444444444444444444444444444444444444\n\n- [medium][blocking][new] Sources/C.swift:1 — bug c1\n\n### Round 2 review — card-c (2026-09-24)\n\nReview SHA: 5555555555555555555555555555555555555555\n\n- [medium][blocking][new] Sources/C.swift:1 — bug c2\n' >"$FIXTURE/docs/tasks/review-trailing-section.md"
insert_plan_hash "$FIXTURE/docs/tasks/review-trailing-section.md"
# Pilot-minimum package: card `effort` is optional - nothing yet applies a per-card effort to a
# dispatched subagent, so a card with `model` set and no `effort:` line at all must pass cleanly.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nmodel: sonnet\nproduct question: does removing the empty state increase task completion?\nmetric: task completion rate\nthreshold: >= 95%%\nuser-visible: none\n' >"$FIXTURE/docs/tasks/card-effort-omitted-ok.md"
insert_plan_hash "$FIXTURE/docs/tasks/card-effort-omitted-ok.md"
# Pilot-minimum package: a non-user-visible card may answer its analytics fields
# "n/a — <reason>" instead of inventing a real product question/metric/threshold.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: docs-cleanup — tidy the internal notes\n\nmodel: sonnet\nproduct question: n/a — docs-only change, nothing to measure\nmetric: n/a — docs-only change, nothing to measure\nthreshold: n/a — docs-only change, nothing to measure\nuser-visible: none\n' >"$FIXTURE/docs/tasks/card-analytics-na-ok.md"
insert_plan_hash "$FIXTURE/docs/tasks/card-analytics-na-ok.md"
# SDLC-D-014 point 1: full REQ ids in a card block must never be flagged as shorthand.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nmodel: sonnet\nRequirements: REQ-WIDGET-001, REQ-WIDGET-002\nproduct question: does removing the empty state increase task completion?\nmetric: task completion rate\nthreshold: >= 95%%\nuser-visible: none\n' >"$FIXTURE/docs/tasks/card-req-full-ok.md"
insert_plan_hash "$FIXTURE/docs/tasks/card-req-full-ok.md"
# P2-R1-1: a card whose slug is a hyphen-prefix of another card's slug must not absorb that
# other card's reviews. "onboarding" is a `\b`-bounded substring of "onboarding-copy" (a hyphen
# is a non-word character, so the regex word boundary falls right at it) - card-a's 2 review
# rounds and card-b's 3 must group and budget separately (repairs 1 and 2, both under the budget
# of 3), never combine into one card's 4-repair overage.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: onboarding — a\n\nmodel: sonnet\nproduct question: does this help?\nmetric: rate\nthreshold: >= 90%%\nuser-visible: none\n\n#### Card: onboarding-copy — b\n\nmodel: sonnet\nproduct question: does this help?\nmetric: rate\nthreshold: >= 90%%\nuser-visible: none\n\n### Round 1 review — onboarding-copy (2026-09-24)\n\nReview SHA: 0000000000000000000000000000000000000000\n\n- [medium][blocking][new] Sources/Copy.swift:1 — bug copy1\n\n### Round 2 review — onboarding-copy (2026-09-24)\n\nReview SHA: 1111111111111111111111111111111111111111\n\n- [medium][blocking][new] Sources/Copy.swift:1 — bug copy2\n\n### Round 3 review — onboarding-copy (2026-09-24)\n\nReview SHA: 2222222222222222222222222222222222222222\n\n- [medium][blocking][new] Sources/Copy.swift:1 — bug copy3\n\n### Round 1 review — onboarding (2026-09-24)\n\nReview SHA: 3333333333333333333333333333333333333333\n\n- [medium][blocking][new] Sources/Onboarding.swift:1 — bug onb1\n\n### Round 2 review — onboarding (2026-09-24)\n\nReview SHA: 4444444444444444444444444444444444444444\n\n- [medium][blocking][new] Sources/Onboarding.swift:1 — bug onb2\n' >"$FIXTURE/docs/tasks/card-slug-hyphen-prefix-ok.md"
insert_plan_hash "$FIXTURE/docs/tasks/card-slug-hyphen-prefix-ok.md"
# P2-SCHEMA: the writer-invented Schema: header is dropped (pilot deviation approved in
# tasks/ios-sdlc-review.md "Pilot-minimum package", 2026-09-24) - Profile: is the only opt-in,
# so a Schema: line, including free text with no digit at all, must be read as an unrecognized
# line, never validated or rejected.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: banana\n' >"$FIXTURE/docs/tasks/schema-freetext-ignored.md"
# SDLC-D-049 point 3: the approval record quotes the Plan hash the owner approved. A re-approval
# appends a new hash, and the last one in the record binds; a hash after the record ends (the
# next status-block field) is not part of it.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nProfile: round\n\n## Current status and authorization\n\nAuthorized scope: plan approved through ExitPlanMode (owner, 2026-09-25): package\nREQ-WIDGET-001, one card, Plan hash 1111111111111111111111111111111111111111111111111111111111111111;\nre-approved after a scope change (owner, 2026-09-25), Plan hash: @PLANHASH@;\npublication: push of main.\nBlocking decisions: none; an old draft had Plan hash 2222222222222222222222222222222222222222222222222222222222222222.\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n' >"$FIXTURE/docs/tasks/round-approved-hash-ok.md"
insert_approved_plan_hash "$FIXTURE/docs/tasks/round-approved-hash-ok.md"
insert_plan_hash "$FIXTURE/docs/tasks/round-approved-hash-ok.md"
# The abbreviated <head>…<tail> form, wrapped onto the next line (Pitstop RD-012's record shape).
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nProfile: round\n\n## Current status and authorization\n\nAuthorized scope: package approval through ExitPlanMode (owner, 2026-09-25), Plan hash\n@HEAD@…@TAIL@.; answer, verbatim: "Approve".\nBlocking decisions: none.\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n' >"$FIXTURE/docs/tasks/round-approved-hash-abbrev-ok.md"
insert_approved_plan_hash "$FIXTURE/docs/tasks/round-approved-hash-abbrev-ok.md"
insert_plan_hash "$FIXTURE/docs/tasks/round-approved-hash-abbrev-ok.md"
python3 "$LINT" --root "$FIXTURE" --strict >/dev/null || fail 'valid briefs, a done/ subdirectory, template.md, SHA-ticked writer steps, a well-formed Schema 2 dispatch, a Schema 1 (ungated) dispatch heading, the three profiles with matching evidence, a correct Plan hash, an approval record quoting the current Plan hash in full (last of two) or abbreviated, a card with no effort: line, a non-user-visible card with n/a analytics fields, a card citing full REQ ids, a fenced schema-2 example in a schema-1 brief, out-of-order Round headings, two cards each with their own Round 1, three cards with one repair round apiece grouped by name in a trailing Reviews section, a hyphen-prefix card slug pair with their own separate repair counts, and a free-text Schema: line must pass'

brief prose session 'in progress' pending none
brief detail session 'done — merged yesterday' 'abc1234' none
brief unproven session done pending none
brief dangling session open pending missing-brief
printf '# Task\n\nNo fields here.\n' >"$FIXTURE/docs/tasks/bare.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nParallelism: as many as needed\n' >"$FIXTURE/docs/tasks/vague-parallel.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nParallelism: up to 2\n' >"$FIXTURE/docs/tasks/parallel.md"
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\n\n## Writer steps\n\n- [x] Parse the feed, done\n- [x] Render the list: defaced layout fixed\n' >"$FIXTURE/docs/tasks/writer-unsha.md"
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\n\n## Writer steps\n\n- [x] Parse the feed — 3f2a9c1\n- [x] Render the list — 3f2a9c1\n' >"$FIXTURE/docs/tasks/writer-shared.md"
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\nSchema: 2\nProfile: fast\n\n## Writer steps\n\n- [x] Parse the feed: tests pass — 3f2a9c1\n- [x] Render the list: tests pass — 4a1b8e2\n' >"$FIXTURE/docs/tasks/writer-steps-all-ticked-not-done.md"
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\nSchema: 2\nProfile: fast\n\n### Slice 9 dispatch — bare (2026-09-24)\n\nSomething undispatched.\n' >"$FIXTURE/docs/tasks/dispatch-missing.md"
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\nSchema: 2\nProfile: fast\n\n### Slice 9 dispatch — vague (2026-09-24)\n\nObjective: pending\n\nSources: REQ-WIDGET-001\n\nIntended deviations: none\n\nBoundaries: only Sources/Widget/**\n\nOutput: READY\n' >"$FIXTURE/docs/tasks/dispatch-placeholder.md"
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\nSchema: 2\nProfile: fast\n\n### Slice 9 dispatch — uncited (2026-09-24)\n\nObjective: polish the widget.\n\nSources: general knowledge, nothing cited\n\nIntended deviations: none\n\nBoundaries: only Sources/Widget/**\n\nOutput: READY\n' >"$FIXTURE/docs/tasks/dispatch-sources-uncited.md"
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\nSchema: 2\nProfile: fast\n\n### Slice 9 repair dispatch — widget fix (2026-09-24)\n\nObjective: fix the widget defect.\n\nSources: REQ-WIDGET-001\n\nIntended deviations: none\n\nBoundaries: only Sources/Widget/**\n\nOutput: READY\n' >"$FIXTURE/docs/tasks/dispatch-repair-missing-finding.md"
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\nSchema: 2\nProfile: fast\n\n### Slice 9 dispatch — undocumented deviation (2026-09-24)\n\nObjective: polish the widget.\n\nSources: REQ-WIDGET-001\n\nIntended deviations: swap icon color\n\nBoundaries: only Sources/Widget/**\n\nOutput: READY\n' >"$FIXTURE/docs/tasks/dispatch-deviation-no-record.md"
# Pilot-minimum package: a brief opts into every check below by carrying a `Profile:` line, not by
# `Schema: 2` alone - a dispatch heading with Schema: 2 and no Profile: must stay wholly unchecked,
# the same way a Schema-1 brief with a dispatch heading (schema1-dispatch-ignored.md) already does.
printf '# Task\n\nAssignee: session\nState: claimed\nEvidence: pending\nSchema: 2\n\n### Slice 9 dispatch — bare (2026-09-24)\n\nSomething undispatched.\n' >"$FIXTURE/docs/tasks/profile-missing.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: \n' >"$FIXTURE/docs/tasks/profile-empty.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: chill\n' >"$FIXTURE/docs/tasks/profile-bad.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: shipped, looks good\nSchema: 2\nProfile: fast\n' >"$FIXTURE/docs/tasks/profile-fast-evidence-missing.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: shipped, looks good\nSchema: 2\nProfile: fix\n' >"$FIXTURE/docs/tasks/profile-fix-evidence-missing.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: shipped, looks good\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n<!-- spec_trace:matrix:begin -->\n\n## Coverage matrix\n\n| Requirement | Status | Detail |\n|---|---|---|\n| REQ-WIDGET-001 | OK | passed |\n\n<!-- spec_trace:matrix:end -->\n' >"$FIXTURE/docs/tasks/profile-round-evidence-missing.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\nPlan hash: 0000000000000000000000000000000000000000000000000000000000000000\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n' >"$FIXTURE/docs/tasks/round-plan-hash-wrong.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n### Round 1 review — widget (2026-09-24)\n\n- [low][non-blocking][new] Sources/Widget.swift:1 — no Review SHA field on this block\n' >"$FIXTURE/docs/tasks/round-review-sha-missing.md"
insert_plan_hash "$FIXTURE/docs/tasks/round-review-sha-missing.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nno model or effort here\nproduct question: does removing the empty state increase task completion?\nmetric: task completion rate\nthreshold: >= 95%%\nuser-visible: none\n' >"$FIXTURE/docs/tasks/card-missing-fields.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nmodel: sonnet\neffort: chill\nproduct question: does removing the empty state increase task completion?\nmetric: task completion rate\nthreshold: >= 95%%\nuser-visible: none\n' >"$FIXTURE/docs/tasks/card-bad-effort.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nmodel: sonnet\neffort: medium\nuser-visible: none\n' >"$FIXTURE/docs/tasks/card-analytics-missing.md"
insert_plan_hash "$FIXTURE/docs/tasks/card-analytics-missing.md"
# n/a needs a reason - a bare "n/a" answers nothing, even on a non-user-visible card.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: docs-cleanup — tidy the internal notes\n\nmodel: sonnet\nproduct question: n/a\nmetric: n/a\nthreshold: n/a\nuser-visible: none\n' >"$FIXTURE/docs/tasks/card-analytics-na-bare.md"
insert_plan_hash "$FIXTURE/docs/tasks/card-analytics-na-bare.md"
# n/a is only for a non-user-visible card - a user-visible card cannot wave off its own analytics.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nmodel: sonnet\nproduct question: n/a — did not bother measuring\nmetric: n/a — did not bother measuring\nthreshold: n/a — did not bother measuring\nuser-visible: the widget now shows helpful guidance instead of a blank card\n' >"$FIXTURE/docs/tasks/card-analytics-na-visible.md"
insert_plan_hash "$FIXTURE/docs/tasks/card-analytics-na-visible.md"
# Repair round 1, medium 1: forms other than the exact "n/a" or "n/a - <reason>" spelling must
# still be read as an n/a attempt - a trailing separator with no reason after it, an en dash
# separator, and a colon separator must all be caught the same way the em-dash form already is.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: badge-rollout — show new badge\n\nmodel: sonnet\nproduct question: n/a —\nmetric: n/a – internal\nthreshold: n/a: nobody sees it\nuser-visible: Users see a new badge\n' >"$FIXTURE/docs/tasks/card-analytics-na-other-forms.md"
insert_plan_hash "$FIXTURE/docs/tasks/card-analytics-na-other-forms.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nmodel: sonnet\neffort: medium\nproduct question: does removing the empty state increase task completion?\nmetric: task completion rate\nthreshold: >= 95%%\n' >"$FIXTURE/docs/tasks/user-visible-missing.md"
insert_plan_hash "$FIXTURE/docs/tasks/user-visible-missing.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: fix\n' >"$FIXTURE/docs/tasks/fix-user-visible-missing.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: coverage matrix closed with no GAP, review clean\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nmodel: sonnet\neffort: medium\nproduct question: does removing the empty state increase task completion?\nmetric: task completion rate\nthreshold: >= 95%%\nuser-visible: the widget now shows helpful guidance instead of a blank card\n\n<!-- spec_trace:matrix:begin -->\n\n## Coverage matrix\n\n| Requirement | Status | Detail |\n|---|---|---|\n| REQ-WIDGET-001 | OK | passed |\n\n<!-- spec_trace:matrix:end -->\n' >"$FIXTURE/docs/tasks/user-visible-no-changelog.md"
insert_plan_hash "$FIXTURE/docs/tasks/user-visible-no-changelog.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: reproduced as a failing test first, fixed, ios-verify PASS, one review round, no findings\nSchema: 2\nProfile: fix\nuser-visible: fixed the duplicate completion toast in checkout\n' >"$FIXTURE/docs/tasks/fix-user-visible-no-changelog.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n### Round 1 review — widget (2026-09-24)\n\nReview SHA: 0000000000000000000000000000000000000000\n\n- Sources/Checkout/CheckoutView.swift:88 crashes sometimes, needs tags\n- [high][blocking][new] Sources/Checkout/CheckoutView.swift:99 — TBD\n' >"$FIXTURE/docs/tasks/review-untagged.md"
insert_plan_hash "$FIXTURE/docs/tasks/review-untagged.md"
# Pilot-minimum package: cross-round new/recurring pairing is dropped (a mismatched tag is no
# longer a finding) - the mark itself is still required by FINDING's regex, checked above via
# review-untagged.md, but a mismatch between rounds is no longer linted.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n### Round 1 review — widget (2026-09-24)\n\nReview SHA: 0000000000000000000000000000000000000000\n\n- [high][blocking][new] Sources/Checkout/CheckoutView.swift:88 — force-unwrap crashes when cart is empty\n\n### Round 2 review — widget (2026-09-24)\n\nReview SHA: 1111111111111111111111111111111111111111\n\n- [medium][blocking][new] Sources/Checkout/CheckoutView.swift:88 — force-unwrap crashes when cart is empty\n- [low][non-blocking][recurring] Sources/Checkout/CheckoutView.swift:5 — never seen before\n' >"$FIXTURE/docs/tasks/review-mismatch.md"
insert_plan_hash "$FIXTURE/docs/tasks/review-mismatch.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n### Round 1 review — a (2026-09-24)\n\nReview SHA: 0000000000000000000000000000000000000000\n\n- [medium][blocking][new] Sources/A.swift:1 — bug a\n\n### Round 2 review — a (2026-09-24)\n\nReview SHA: 1111111111111111111111111111111111111111\n\n- [medium][blocking][new] Sources/B.swift:1 — bug b\n\n### Round 3 review — a (2026-09-24)\n\nReview SHA: 2222222222222222222222222222222222222222\n\n- [medium][blocking][new] Sources/C.swift:1 — bug c\n\n### Round 4 review — a (2026-09-24)\n\nReview SHA: 3333333333333333333333333333333333333333\n\n- [medium][blocking][new] Sources/D.swift:1 — bug d\n\n### Round 5 review — a (2026-09-24)\n\nReview SHA: 4444444444444444444444444444444444444444\n\n- [medium][blocking][new] Sources/E.swift:1 — bug e\n' >"$FIXTURE/docs/tasks/review-budget.md"
insert_plan_hash "$FIXTURE/docs/tasks/review-budget.md"
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: fast\nOutage: 2026-09-24T02:10Z-02:47Z\n' >"$FIXTURE/docs/tasks/outage-bad.md"
# SDLC-D-013 fix (pilot-minimum package): Plan hash protects nothing unless the brief actually has
# the sections it hashes - an empty '## Scope' (a heading with nothing before the next one) and a
# wholly absent '## Constraints' must both be findings, distinct from a wrong or missing hash.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n' >"$FIXTURE/docs/tasks/round-thin-plan.md"
insert_plan_hash "$FIXTURE/docs/tasks/round-thin-plan.md"
# SDLC-D-014's own Enforcement line: a round closes only without GAP - required once Profile: round
# reaches State: done. No matrix block at all, and a matrix block with a GAP row, are each findings.
printf '# Task\n\nAssignee: session\nState: done\nEvidence: coverage matrix closed with no GAP, review clean\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n' >"$FIXTURE/docs/tasks/round-matrix-missing.md"
insert_plan_hash "$FIXTURE/docs/tasks/round-matrix-missing.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: coverage matrix closed with no GAP, review clean\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n<!-- spec_trace:matrix:begin -->\n\n## Coverage matrix\n\n| Requirement | Status | Detail |\n|---|---|---|\n| REQ-WIDGET-001 | OK | passed |\n| REQ-WIDGET-002 | GAP | no test |\n\n<!-- spec_trace:matrix:end -->\n' >"$FIXTURE/docs/tasks/round-matrix-gap.md"
insert_plan_hash "$FIXTURE/docs/tasks/round-matrix-gap.md"
# SDLC-D-014 point 1: spec_trace.py's cmd_matrix collects cited ids only from card blocks, so a
# range or ellipsis shorthand there never reaches the round's coverage matrix.
# Repair round 1, medium 3: an en dash, a plain hyphen and the word "to" are range separators too,
# not only ellipsis/dots/comma.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nmodel: sonnet\nRequirements: REQ-BOARD-001…028, REQ-ROAD-004, 008…015, REQ-ENDASH-001–010, REQ-HYPHEN-001-010, REQ-WORDTO-001 to 010\nproduct question: does removing the empty state increase task completion?\nmetric: task completion rate\nthreshold: >= 95%%\nuser-visible: none\n' >"$FIXTURE/docs/tasks/card-req-shorthand.md"
insert_plan_hash "$FIXTURE/docs/tasks/card-req-shorthand.md"
# SDLC-D-049 point 3: the header Plan hash was refreshed after the plan changed, but the approval
# record still quotes the hash the owner approved - the change needs a new approval. The record
# quotes the plan's lines at column 0 (`Package:`, `Plan hash:`, `Publication:`); only a
# status-block field of the template ends it, so the quoted hash is still read.
printf '# Task\n\nAssignee: session\nState: open\nEvidence: pending\nProfile: round\n\n## Current status and authorization\n\nAuthorized scope: plan approved through ExitPlanMode (owner, 2026-09-25):\nPackage: REQ-WIDGET-001, one card.\nPlan hash: aaaa1111…bbbb2\nPublication: push of main.\nBlocking decisions: none.\n\n## Scope\n\nShip the widget and a settings screen.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n' >"$FIXTURE/docs/tasks/round-approved-hash-stale.md"
insert_plan_hash "$FIXTURE/docs/tasks/round-approved-hash-stale.md"
out="$(python3 "$LINT" --root "$FIXTURE" || true)"
for expected in \
  "prose.md: State must be one of" \
  "detail.md: State must be one of" \
  "unproven.md: State done requires Evidence" \
  "dangling.md: Depends-on names no brief: missing-brief" \
  "bare.md: missing State" \
  "bare.md: missing Assignee" \
  "vague-parallel.md: Parallelism must be" \
  "writer-unsha.md: Writer steps: ticked step without a commit SHA: Parse the feed" \
  "writer-unsha.md: Writer steps: ticked step without a commit SHA: Render the list: defaced" \
  "writer-shared.md: Writer steps: SHA 3f2a9c1 ticks more than one step: Render the list" \
  "writer-steps-all-ticked-not-done.md: Writer steps are all ticked but State is 'claimed', expected done (SDLC-D-042)" \
  "dispatch-missing.md: dispatch 'Slice 9 dispatch — bare (2026-09-24)': missing Objective" \
  "dispatch-missing.md: dispatch 'Slice 9 dispatch — bare (2026-09-24)': missing Sources" \
  "dispatch-missing.md: dispatch 'Slice 9 dispatch — bare (2026-09-24)': missing Intended deviations" \
  "dispatch-missing.md: dispatch 'Slice 9 dispatch — bare (2026-09-24)': missing Boundaries" \
  "dispatch-missing.md: dispatch 'Slice 9 dispatch — bare (2026-09-24)': missing Output" \
  "dispatch-placeholder.md: dispatch 'Slice 9 dispatch — vague (2026-09-24)': Objective is empty or a placeholder" \
  "dispatch-sources-uncited.md: dispatch 'Slice 9 dispatch — uncited (2026-09-24)': Sources cites neither a REQ/decision ID nor a mockup section" \
  "dispatch-repair-missing-finding.md: dispatch 'Slice 9 repair dispatch — widget fix (2026-09-24)': a repair dispatch's Sources must cite the review finding it repairs" \
  "dispatch-deviation-no-record.md: dispatch 'Slice 9 dispatch — undocumented deviation (2026-09-24)': Intended deviations lacks its SDLC-D-NNN (or legacy KIT-D-NNN) record" \
  "profile-bad.md: Profile must be one of fast|fix|round, found: 'chill'" \
  "profile-empty.md: Profile must be one of fast|fix|round, found: ''" \
  "profile-fast-evidence-missing.md: Profile fast: Evidence lacks test evidence" \
  "profile-fast-evidence-missing.md: Profile fast: Evidence lacks verify evidence" \
  "profile-fix-evidence-missing.md: Profile fix: Evidence lacks fail evidence" \
  "profile-fix-evidence-missing.md: Profile fix: Evidence lacks verify evidence" \
  "profile-fix-evidence-missing.md: Profile fix: Evidence lacks review evidence" \
  "profile-fix-evidence-missing.md: Profile fix requires user-visible (SDLC-D-026)" \
  "profile-round-evidence-missing.md: Profile round: Evidence lacks matrix evidence" \
  "profile-round-evidence-missing.md: Profile round: Evidence lacks review evidence" \
  "profile-round-evidence-missing.md: Profile round requires Plan hash" \
  "round-plan-hash-wrong.md: Plan hash mismatch: recorded '0000000000000000000000000000000000000000000000000000000000000000'" \
  "round-approved-hash-stale.md: Plan hash mismatch: the approval record names 'aaaa1111…bbbb2'" \
  "round-review-sha-missing.md: review 'Round 1 review — widget (2026-09-24)': missing Review SHA" \
  "card-missing-fields.md: card 'Card: widget-empty-state — polish': missing model" \
  "card-bad-effort.md: card 'Card: widget-empty-state — polish': effort must be one of low|medium|high|xhigh|max, found: 'chill'" \
  "card-analytics-missing.md: card 'Card: widget-empty-state — polish': missing product question (SDLC-D-025)" \
  "card-analytics-missing.md: card 'Card: widget-empty-state — polish': missing metric (SDLC-D-025)" \
  "card-analytics-missing.md: card 'Card: widget-empty-state — polish': missing threshold (SDLC-D-025)" \
  "card-analytics-na-bare.md: card 'Card: docs-cleanup — tidy the internal notes': product question 'n/a' needs a reason (SDLC-D-025)" \
  "card-analytics-na-bare.md: card 'Card: docs-cleanup — tidy the internal notes': metric 'n/a' needs a reason (SDLC-D-025)" \
  "card-analytics-na-bare.md: card 'Card: docs-cleanup — tidy the internal notes': threshold 'n/a' needs a reason (SDLC-D-025)" \
  "card-analytics-na-visible.md: card 'Card: widget-empty-state — polish': product question cannot be 'n/a' - the card is user-visible (SDLC-D-025)" \
  "card-analytics-na-visible.md: card 'Card: widget-empty-state — polish': metric cannot be 'n/a' - the card is user-visible (SDLC-D-025)" \
  "card-analytics-na-visible.md: card 'Card: widget-empty-state — polish': threshold cannot be 'n/a' - the card is user-visible (SDLC-D-025)" \
  "card-analytics-na-other-forms.md: card 'Card: badge-rollout — show new badge': product question 'n/a' needs a reason (SDLC-D-025)" \
  "card-analytics-na-other-forms.md: card 'Card: badge-rollout — show new badge': metric cannot be 'n/a' - the card is user-visible (SDLC-D-025)" \
  "card-analytics-na-other-forms.md: card 'Card: badge-rollout — show new badge': threshold cannot be 'n/a' - the card is user-visible (SDLC-D-025)" \
  "user-visible-missing.md: card 'Card: widget-empty-state — polish': missing user-visible (SDLC-D-026)" \
  "fix-user-visible-missing.md: Profile fix requires user-visible (SDLC-D-026)" \
  "user-visible-no-changelog.md: CHANGELOG.md is missing but a user-visible change just closed (SDLC-D-026)" \
  "fix-user-visible-no-changelog.md: CHANGELOG.md is missing but a user-visible change just closed (SDLC-D-026)" \
  "review-untagged.md: review 'Round 1 review — widget (2026-09-24)': finding missing required tags (level/blocking/new-or-recurring): Sources/Checkout/CheckoutView.swift:88 crashes sometimes, ne" \
  "review-untagged.md: review 'Round 1 review — widget (2026-09-24)': a high finding needs a concrete failure scenario: Sources/Checkout/CheckoutView.swift:99" \
  "review-budget.md: 4 repair rounds exceed the budget of 3: Repair extension approval is required" \
  "outage-bad.md: Outage recorded but missing a Scope audit line" \
  "round-thin-plan.md: Profile round requires a non-empty '## Scope' section" \
  "round-thin-plan.md: Profile round requires a non-empty '## Constraints' section" \
  "round-matrix-missing.md: Profile round State done requires the generated coverage matrix block (SDLC-D-014)" \
  "round-matrix-gap.md: Profile round State done: the coverage matrix has a GAP row (SDLC-D-014)" \
  "card-req-shorthand.md: card 'Card: widget-empty-state — polish': REQ id written as a range or shorthand, not in full: 'REQ-BOARD-001…028'" \
  "card-req-shorthand.md: card 'Card: widget-empty-state — polish': REQ id written as a range or shorthand, not in full: 'REQ-ROAD-004, 008…015'" \
  "card-req-shorthand.md: card 'Card: widget-empty-state — polish': REQ id written as a range or shorthand, not in full: 'REQ-ENDASH-001–010'" \
  "card-req-shorthand.md: card 'Card: widget-empty-state — polish': REQ id written as a range or shorthand, not in full: 'REQ-HYPHEN-001-010'" \
  "card-req-shorthand.md: card 'Card: widget-empty-state — polish': REQ id written as a range or shorthand, not in full: 'REQ-WORDTO-001 to 010'"; do
  grep -qF "$expected" <<<"$out" || fail "missing finding: $expected"
done
grep -qF 'report mode' <<<"$out" || fail 'report mode must say that it does not fail'
if grep -qF 'profile-missing.md' <<<"$out"; then
  fail 'a Schema: 2 brief with no Profile: line must opt into nothing - the gate is Profile:, not Schema:'
fi
if grep -F 'review-mismatch.md' <<<"$out" | grep -qF 'tagged'; then
  fail 'cross-round new/recurring pairing is dropped - a mismatched tag must no longer be a finding'
fi
grep -qF 'problems: 67' <<<"$out" || fail "expected exactly 67 problems: $(tail -1 <<<"$out")"
python3 "$LINT" --root "$FIXTURE" >/dev/null || fail 'report mode must exit 0'
if python3 "$LINT" --root "$FIXTURE" --strict >/dev/null; then fail '--strict must exit 1 on problems'; fi
python3 "$LINT" --root "$FIXTURE" --board | grep -qE '^blocked +follow-up \(unassigned\)' || fail '--board must group briefs by State'

# SDLC-D-026: CHANGELOG.md itself - a separate root so its content does not affect every other
# fixture above (most of which deliberately have no CHANGELOG.md at all, per SDLC-D-026.W3 not
# being landed yet). Pilot-minimum package: the CHANGELOG category-shape lint is dropped, so a
# stray uncategorised subsection is no longer a finding; a real [unreleased] bullet under any
# subsection still satisfies check_unreleased_line (presence of the heading alone is not enough,
# content is checked).
CHANGELOG_FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-brief-lint-changelog.XXXXXX")"
mkdir -p "$CHANGELOG_FIXTURE_DIR/docs/tasks"
printf '# Changelog\n\nAll notable changes to this project.\n\n## [unreleased]\n\n### Misc\n\n- Widget now shows helpful guidance instead of a blank card\n' >"$CHANGELOG_FIXTURE_DIR/CHANGELOG.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: coverage matrix closed with no GAP, review clean\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nmodel: sonnet\neffort: medium\nproduct question: does removing the empty state increase task completion?\nmetric: task completion rate\nthreshold: >= 95%%\nuser-visible: the widget now shows helpful guidance instead of a blank card\n\n<!-- spec_trace:matrix:begin -->\n\n## Coverage matrix\n\n| Requirement | Status | Detail |\n|---|---|---|\n| REQ-WIDGET-001 | OK | passed |\n\n<!-- spec_trace:matrix:end -->\n' >"$CHANGELOG_FIXTURE_DIR/docs/tasks/user-visible-ok.md"
insert_plan_hash "$CHANGELOG_FIXTURE_DIR/docs/tasks/user-visible-ok.md"
python3 "$LINT" --root "$CHANGELOG_FIXTURE_DIR" --strict >/dev/null \
  || fail 'a real [unreleased] bullet under an uncategorised subsection must satisfy check_unreleased_line and raise no shape finding'
rm -rf "$CHANGELOG_FIXTURE_DIR"

# Repair round 1, medium 3: the other Keep a Changelog form SDLC-D-026 itself cites, "[x.y] -
# unreleased" (Drive Check's own pre-existing file shape), case-insensitively.
CHANGELOG_VERSION_FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-brief-lint-changelog-version.XXXXXX")"
mkdir -p "$CHANGELOG_VERSION_FIXTURE_DIR/docs/tasks"
printf '# Changelog\n\n## [3.1] - Unreleased\n\n### Features\n\n- Widget now shows helpful guidance instead of a blank card\n' >"$CHANGELOG_VERSION_FIXTURE_DIR/CHANGELOG.md"
printf '# Task\n\nAssignee: session\nState: done\nEvidence: coverage matrix closed with no GAP, review clean\nSchema: 2\nProfile: round\n\n## Scope\n\nShip the widget.\n\n## Acceptance\n\nGiven a user opens the widget, then it renders.\n\n## Constraints\n\nOffline-friendly.\n\n#### Card: widget-empty-state — polish\n\nmodel: sonnet\neffort: medium\nproduct question: does removing the empty state increase task completion?\nmetric: task completion rate\nthreshold: >= 95%%\nuser-visible: the widget now shows helpful guidance instead of a blank card\n\n<!-- spec_trace:matrix:begin -->\n\n## Coverage matrix\n\n| Requirement | Status | Detail |\n|---|---|---|\n| REQ-WIDGET-001 | OK | passed |\n\n<!-- spec_trace:matrix:end -->\n' >"$CHANGELOG_VERSION_FIXTURE_DIR/docs/tasks/user-visible-ok.md"
insert_plan_hash "$CHANGELOG_VERSION_FIXTURE_DIR/docs/tasks/user-visible-ok.md"
python3 "$LINT" --root "$CHANGELOG_VERSION_FIXTURE_DIR" --strict >/dev/null \
  || fail 'a "[x.y] - unreleased" CHANGELOG.md heading (case-insensitive) must be accepted, not just literal "[unreleased]"'
rm -rf "$CHANGELOG_VERSION_FIXTURE_DIR"

# SDLC-D-049 point 3 with SDLC-D-014 rule 2 (AR2 repair 1, finding AR2-R1-M1): a round whose
# deferral rows have different approval sources - the approved plan for a row inside the plan's
# deferral class, the owner for a row outside it - records them as
# the retired method/process/task-lifecycle.md ("Deferred") showed.
# spec_trace.py accepts exactly one 'Deferred approval:' line, so the documented record must be
# one line, or both rows stay GAP and the round cannot close. Lives here because
# spec-trace-contract.sh is outside the AR2 card's owned files.
TRACE="$REPO_ROOT/scripts/spec/spec_trace.py"
DEFERRED_ROUTES_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-brief-lint-deferred-routes.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$DEFERRED_ROUTES_DIR"' EXIT
mkdir -p "$DEFERRED_ROUTES_DIR/docs/requirements" "$DEFERRED_ROUTES_DIR/docs/tasks"
printf '# Area\n\n## REQ-AREA-001 — needs a second device\n\nStatus: approved\n\nCore: P1\n\n## REQ-AREA-002 — blocked by a tool\n\nStatus: approved\n\nCore: P1\n' >"$DEFERRED_ROUTES_DIR/docs/requirements/area.md"
documented_record='Deferred approval: plan "<Plan hash>" (<rows>); owner "<answer>" (<rows>)'
printf '# Task — round\n\n#### Card: round\n\nRequirements: REQ-AREA-001, REQ-AREA-002\n\n## Deferred\n\n| Requirement | Status | Reason | Backlog | Expiry |\n|---|---|---|---|---|\n| REQ-AREA-001 | Deferred | device-only | docs/planning/backlog.md#a1 | 2099-01-01 |\n| REQ-AREA-002 | Deferred | tool-blocked | docs/planning/backlog.md#a2 | 2099-01-01 |\n\n%s\n' "$documented_record" >"$DEFERRED_ROUTES_DIR/docs/tasks/round.md"
routes_out="$(python3 "$TRACE" matrix --root "$DEFERRED_ROUTES_DIR" --brief "$DEFERRED_ROUTES_DIR/docs/tasks/round.md" 2>&1)" \
  || fail "the Deferred approval record task-lifecycle.md documents for two approvers must pass spec_trace.py matrix: $routes_out"
for req in REQ-AREA-001 REQ-AREA-002; do
  grep -qF "| $req | Deferred |" <<<"$routes_out" || fail "$req must read Deferred under the documented record: $routes_out"
done

echo 'brief lint contracts: passed'
