#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TRACE="$REPO_ROOT/scripts/spec/spec_trace.py"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
field() { python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)[sys.argv[1]]))' "$1"; }

# Round 1 repair addendum: spec_trace.py is vendored into app repositories and CI
# images that may still run an older Python (Xcode's system /usr/bin/python3 predates
# PEP 701's relaxed f-string grammar, e.g. same-quote nesting inside an f-string
# expression, which pre-3.12 rejects as "f-string: unmatched '['" or similar). Byte-
# compile it with that interpreter when this machine has one; skip with a note when it
# does not, rather than making the contract depend on a binary that may not exist here.
if [[ -x /usr/bin/python3 ]]; then
  py39err="$(mktemp "${TMPDIR:-/tmp}/agents-kit-spec-trace-py39.XXXXXX")"
  if ! PYTHONPYCACHEPREFIX="$FIXTURE/pycache" /usr/bin/python3 -c "import py_compile, sys; py_compile.compile(sys.argv[1], doraise=True)" "$TRACE" 2>"$py39err"; then
    fail "spec_trace.py must byte-compile under /usr/bin/python3 (pre-3.12 f-string grammar): $(cat "$py39err")"
  fi
  rm -f "$py39err"
else
  echo "note: /usr/bin/python3 not found on this machine, skipping the Python 3.9 byte-compile check" >&2
fi

mkdir -p "$FIXTURE/docs/requirements" "$FIXTURE/AppTests" "$FIXTURE/.claude/worktrees/task/AppTests"
cat >"$FIXTURE/docs/requirements/area.md" <<'MD'
# Area requirements

## REQ-AREA-001 — passes

Status: approved

Core: P1

## REQ-AREA-002 — fails

Status: approved

Core: P1

## REQ-AREA-003 — tagged by comment only, never executed

Status: approved

Core: P1

## REQ-AREA-004 — proposed, no spec

Status: proposed

Core: P1

## REQ-AREA-005 — approved, spec exists only in a nested worktree

Status: approved

Core: P1

## REQ-AREA-006 — retired

Status: retired
MD
cat >"$FIXTURE/AppTests/AreaTests.swift" <<'SWIFT'
struct AreaTests {
    @Test("REQ-AREA-001: passes") func passes() {}
    @Test("REQ-AREA-002: fails", .tags(.slow))
    @MainActor
    func failsWhenBroken() {}
    // REQ-AREA-003
    func test_untaggedInResults() {}
}
SWIFT
printf '@Test("REQ-AREA-005: nested") func nested() {}\n' >"$FIXTURE/.claude/worktrees/task/AppTests/NestedTests.swift"
# Result names deliberately omit the IDs: the join must work through the function name too.
cat >"$FIXTURE/results.json" <<'JSON'
{"testNodes":[{"nodeType":"Test Plan","name":"App","children":[{"nodeType":"Test Suite","name":"AreaTests","children":[
 {"nodeType":"Test Case","name":"REQ-AREA-001: passes","nodeIdentifier":"AreaTests/passes()","result":"Passed"},
 {"nodeType":"Test Case","name":"failsWhenBroken()","nodeIdentifier":"AreaTests/failsWhenBroken()","result":"Failed"}
]}]}]}
JSON

plain="$(python3 "$TRACE" --root "$FIXTURE" --json)"
[[ "$(field uncovered <<<"$plain")" == "REQ-AREA-004,REQ-AREA-005" ]] || fail "nested worktree specs must not count as coverage: $(field uncovered <<<"$plain")"
grep -q 'REQ-AREA-006' <<<"$plain" && fail 'retired requirement reported'

approved="$(python3 "$TRACE" --root "$FIXTURE" --json --approved-only)"
[[ "$(field uncovered <<<"$approved")" == "REQ-AREA-005" ]] || fail '--approved-only must drop the proposed requirement from gaps'
[[ "$(field unapproved <<<"$approved")" == "REQ-AREA-004" ]] || fail '--approved-only must list the proposed requirement as unapproved'

joined="$(python3 "$TRACE" --root "$FIXTURE" --json --approved-only --results "$FIXTURE/results.json")"
[[ "$(field passed <<<"$joined")" == "REQ-AREA-001" ]] || fail "passed: $(field passed <<<"$joined")"
[[ "$(field failed <<<"$joined")" == "REQ-AREA-002" ]] || fail "failed must join through the Swift Testing function name: $(field failed <<<"$joined")"
[[ "$(field not_run <<<"$joined")" == "REQ-AREA-003" ]] || fail "a spec that never executed must be not_run: $(field not_run <<<"$joined")"

printf '' >"$FIXTURE/partial.json"
if python3 "$TRACE" --root "$FIXTURE" --results "$FIXTURE/partial.json" >/dev/null 2>"$FIXTURE/err"; then
  fail 'unreadable results must fail, not report not_run'
fi
grep -q 'not valid JSON' "$FIXTURE/err" || fail 'unreadable results need a clear message'

python3 "$TRACE" --root "$FIXTURE" >/dev/null || fail 'report mode must exit 0 despite gaps'
if python3 "$TRACE" --root "$FIXTURE" --strict >/dev/null; then fail '--strict must exit 1 on gaps'; fi

# A fully approved, covered, passing tree is the only strict success.
rm -rf "$FIXTURE/.claude"
python3 - "$FIXTURE" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
doc = root / "docs/requirements/area.md"
text = doc.read_text()
doc.write_text(text[: text.index("## REQ-AREA-002")])
(root / "AppTests/AreaTests.swift").write_text('@Test("REQ-AREA-001: passes") func passes() {}\n')
PY
python3 "$TRACE" --root "$FIXTURE" --strict --approved-only --results "$FIXTURE/results.json" >/dev/null \
  || fail '--strict must exit 0 when every approved requirement ran and passed'

# Requirements written as bold labels in prose, lists and tables. Core: still takes a
# document-level default, but SDLC-D-042 ends that for Status: (approval is per
# requirement only, read for the SDLC-D-003 lock): a bold-label requirement has no
# per-requirement Status: line to write, so it stays unapproved despite a document-level
# "Status: approved" marker, which is ignored with a warning instead of silently
# approving the whole file.
INLINE="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-inline.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE"' EXIT
mkdir -p "$INLINE/docs/requirements" "$INLINE/AppTests"
cat >"$INLINE/docs/requirements/product.md" <<'MD'
# Product

Status: approved

Core: P1

| Entity | Rule |
|---|---|
| **Cart** | **REQ-CART-010** One per family |

1. **REQ-CART-020** Items can be checked. See also **REQ-CART-010**.
MD
printf '@Test("REQ-CART-010: one cart") func oneCart() {}\n' >"$INLINE/AppTests/CartTests.swift"
inline="$(python3 "$TRACE" --root "$INLINE" --json --approved-only 2>"$INLINE/err")"
[[ -z "$(field covered <<<"$inline")" ]] || fail "a bold-label requirement has no per-requirement Status:, so --approved-only must not count it: $(field covered <<<"$inline")"
[[ "$(field unapproved <<<"$inline")" == "REQ-CART-010,REQ-CART-020" ]] \
  || fail "both bold-label requirements must stay unapproved despite the document-level marker: $(field unapproved <<<"$inline")"
grep -q 'file-level Status: marker ignored' "$INLINE/err" || fail 'a document-level Status: marker must warn, not silently approve (SDLC-D-042)'

plainInline="$(python3 "$TRACE" --root "$INLINE" --json)"
[[ "$(field covered <<<"$plainInline")" == "REQ-CART-010" ]] || fail "bold-label requirement in a table must still be recognized outside --approved-only: $(field covered <<<"$plainInline")"
[[ "$(field uncovered <<<"$plainInline")" == "REQ-CART-020" ]] || fail 'bold-label requirement in a list must be recognized and a later mention must not redefine one'
[[ -z "$(field missing_core_link <<<"$plainInline")" ]] || fail 'a document-level Core: line must still apply to its requirements'

# An approved-only trace over zero approved requirements must not look green (this
# fixture already has none, now that a document-level Status: no longer cascades).
python3 "$TRACE" --root "$INLINE" --approved-only >/dev/null 2>"$INLINE/err" || fail 'report mode must still exit 0 on an empty approved set'
grep -q 'no approved requirements' "$INLINE/err" || fail 'an empty approved set must be reported'
if python3 "$TRACE" --root "$INLINE" --approved-only --strict >/dev/null 2>&1; then
  fail '--strict must fail on an empty approved set'
fi

# Prose mode: normative sentences without a REQ ID, in Markdown sections and HTML mockups.
PROSE="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-prose.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE"' EXIT
mkdir -p "$PROSE/docs/requirements" "$PROSE/docs/design"
cat >"$PROSE/docs/requirements/board.md" <<'MD'
# Board

**Status:** P0 product contract

## Tile contract

A tile must expose state before tap. It has a title.
Pit never guesses the car (REQ-BOARD-004).
It is not only a fallback. Nothing becomes icon-only.
Which cycles must reset?

```text
must: this is sample data
```

| Tile | Rule |
|---|---|
| Road | **REQ-BOARD-010** Shown only with data |
| Notes | Unclassified notes always stay |

1. **REQ-BOARD-020** Items must be checked. The list never hides one.

> Pit only asks one thing.
> Pit cannot pretend.

## Scope

Do not add a login.

### REQ-BOARD-030 — Given/When/Then is the rule itself

Given the board
When it renders
Then it must show the car
MD
cat >"$PROSE/docs/design/mockup.html" <<'HTML'
<html><head><title>Only a title</title><style>/* never red */</style></head>
<body><script>var must = 1;</script>
<p>Always offline.</p>
<section id="board"><h2>Board must</h2>
<p>The chip is <b>never</b>
red.</p><svg><text>only a drawing</text></svg>
<ul><li>Only confirmed work resets (REQ-BOARD-003).</li><li>At most two actions.<br>Plain text.</li></ul>
<table><tr><td>Due</td><td>REQ-BOARD-005: amber only</td></tr><tr><td>Danger</td><td>errors only</td></tr></table>
</section>
<p>Shall stay after the section.</p>
</body></html>
HTML
prose_texts() { python3 -c 'import json,sys; print("\n".join(f"{f["line"]}|{f["keyword"]}|{f["text"]}" for f in json.load(sys.stdin)["prose_without_req"]))'; }
md="$(python3 "$TRACE" --root "$PROSE" --json --prose docs/requirements/board.md | prose_texts)"
expected_md='7|must|A tile must expose state before tap.
19|always|Notes | Unclassified notes always stay
23|only|Pit only asks one thing.
24|cannot|Pit cannot pretend.
28|do not|Do not add a login.'
[[ "$md" == "$expected_md" ]] || fail "markdown prose findings differ:
$md"
scoped="$(python3 "$TRACE" --root "$PROSE" --json --prose 'docs/requirements/board.md#scope' | prose_texts)"
[[ "$scoped" == '28|do not|Do not add a login.' ]] || fail "a heading anchor must limit the report to its section: $scoped"
[[ "$(python3 "$TRACE" --root "$PROSE" --json --prose 'docs/requirements/board.md#Tile contract' | prose_texts | wc -l | tr -d ' ')" == 4 ]] \
  || fail 'a section may also be named by its heading text'

html="$(python3 "$TRACE" --root "$PROSE" --json --prose docs/design/mockup.html | prose_texts)"
expected_html='3|always|Always offline.
5|never|The chip is never red.
7|at most|At most two actions.
8|only|| Danger | errors only
10|shall|Shall stay after the section.'
[[ "$html" == "$expected_html" ]] || fail "HTML prose findings differ (script, style, svg, head and headings are not prose):
$html"
section="$(python3 "$TRACE" --root "$PROSE" --json --prose 'docs/design/mockup.html#board' | prose_texts | cut -d'|' -f1 | tr '\n' ' ')"
[[ "$section" == '5 7 8 ' ]] || fail "an element id must limit the mockup report to that element: $section"

# d1-spec-trace-1 (assessment.md §5, CONFIRMED): HTML allows an omitted </head>, and a
# <body> start tag must implicitly close an open <head> the same way a browser's
# parser would, so the body's own prose is not swallowed under an ever-growing
# skip_depth. script/svg still skip wherever they occur.
cat >"$PROSE/docs/design/nohead.html" <<'HTML'
<html><head><title>No closing head tag</title>
<body><script>var must = 2;</script>
<p>The scanner must report this body sentence.</p>
<svg><text>must not appear either</text></svg>
</body></html>
HTML
nohead="$(python3 "$TRACE" --root "$PROSE" --json --prose docs/design/nohead.html | prose_texts)"
[[ "$nohead" == '3|must|The scanner must report this body sentence.' ]] \
  || fail "an unclosed <head> must not swallow the body's prose, and script/svg must stay skipped: $nohead"

python3 "$TRACE" --root "$PROSE" --prose docs/requirements/board.md >"$PROSE/out" || fail 'prose mode must exit 0 without --strict'
grep -q '^prose without a REQ ID: 5 sentences in 1 sources' "$PROSE/out" || fail "prose summary line missing: $(head -1 "$PROSE/out")"
grep -q '^docs/requirements/board.md:28 \[Scope\] do not: Do not add a login.$' "$PROSE/out" || fail 'text report must give file:line, section and keyword'
if python3 "$TRACE" --root "$PROSE" --prose docs/requirements/board.md --strict >/dev/null; then fail 'prose --strict must exit 1 on findings'; fi
python3 "$TRACE" --root "$PROSE" --prose 'docs/requirements/board.md#req-board-030--givenwhenthen-is-the-rule-itself' --strict >/dev/null \
  || fail 'a requirement section is traced prose and must pass --strict'
set +e
python3 "$TRACE" --root "$PROSE" --prose 'docs/requirements/board.md#no-such-heading' >/dev/null 2>"$PROSE/err"
status=$?
set -e
[[ "$status" == 2 ]] && grep -q "no section 'no-such-heading'" "$PROSE/err" || fail "a mistyped anchor must fail with exit 2, not look fully traced (exit $status)"

# REQ-NEW: a writer's proposed requirement is neither defined, covered, unknown nor a gap, and it
# traces the prose it labels; files still citing it are listed for the integrator's numbering.
NEWREQ="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-new.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ"' EXIT
mkdir -p "$NEWREQ/docs/requirements" "$NEWREQ/AppTests"
cat >"$NEWREQ/docs/requirements/capture.md" <<'MD'
# Capture

Core: P1

## REQ-CAP-001 — saves the note

Status: approved

Given a note When saved Then it persists

## REQ-NEW — one prominent action

Status: proposed

The capture sheet must show one prominent action.

## Other rules

1. **REQ-NEW** The sheet never shows two primary buttons.
2. **REQ-NEW-001** A writer who numbered it anyway must not collide.
3. **REQ-NEW-001** A second writer with the same number.

| Rule | ID |
|---|---|
| Only one action is prominent | REQ-NEW |
MD
cat >"$NEWREQ/AppTests/CaptureTests.swift" <<'SWIFT'
@Test("REQ-CAP-001: saves") func saves() {}
@Test("REQ-NEW: one prominent action") func oneProminentAction() {}
func test_REQ_NEW_001_numberedByAWriter() {}
SWIFT
newjson="$(python3 "$TRACE" --root "$NEWREQ" --json --approved-only)" || fail 'REQ-NEW must not be a duplicate or parse error'
[[ "$(field covered <<<"$newjson")" == "REQ-CAP-001" ]] || fail "REQ-NEW must not become a requirement: $(field covered <<<"$newjson")"
[[ -z "$(field uncovered <<<"$newjson")" && -z "$(field unapproved <<<"$newjson")" ]] || fail 'REQ-NEW must not be a gap or an unapproved requirement'
[[ "$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)["unknown_in_specs"]))' <<<"$newjson")" == 0 ]] || fail 'a test citing REQ-NEW is not an unknown ID'
[[ "$(field proposed_new <<<"$newjson")" == "AppTests/CaptureTests.swift,docs/requirements/capture.md" ]] \
  || fail "files citing REQ-NEW must be listed for numbering: $(field proposed_new <<<"$newjson")"
python3 "$TRACE" --root "$NEWREQ" --approved-only --strict >/dev/null || fail 'REQ-NEW alone must not fail --strict mid-round'
newprose="$(python3 "$TRACE" --root "$NEWREQ" --json --prose docs/requirements/capture.md | prose_texts)"
[[ -z "$newprose" ]] || fail "prose labelled REQ-NEW is recorded, not untraced: $newprose"

# The SDLC-D-003.W2 lock: `lock --write` fingerprints each approved requirement's
# normalised EARS/Given-When-Then text with a revision that rises only on a real
# change; `lock --check` reports a changed approved requirement's text (SDLC-D-003.W2
# pilot: report only, no --range or Owner-Approval trailer correlation — the owner
# re-approves a changed approved requirement in chat, recorded in the brief, before
# the next lock --write).
LOCK="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-lock.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK"' EXIT
mkdir -p "$LOCK/docs/requirements"
cat >"$LOCK/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — save persists

Status: approved

Core: P1

When the user taps save, the app shall persist the note.

Given a note\
When saved\
Then it persists

## REQ-AREA-002 — not yet approved

Status: proposed

Core: P1

When the user cancels, the app shall discard the draft.
MD
python3 "$TRACE" lock --write --root "$LOCK" >"$LOCK/write1.out" || fail 'lock --write must exit 0 on a fresh catalog'
grep -q 'new: REQ-AREA-001' "$LOCK/write1.out" || fail "lock --write must record the approved requirement as new: $(cat "$LOCK/write1.out")"
grep -q 'REQ-AREA-002' "$LOCK/write1.out" && fail 'lock --write must never lock an unapproved requirement'
revision1="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["requirements"]["REQ-AREA-001"]["revision"])' "$LOCK/docs/requirements/.spec-lock.json")"
[[ "$revision1" == "1" ]] || fail "a first lock write must start at revision 1: $revision1"
normtext="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["requirements"]["REQ-AREA-001"]["normative_text"])' "$LOCK/docs/requirements/.spec-lock.json")"
[[ "$normtext" == "When the user taps save the app shall persist the note Given a note When saved Then it persists" ]] \
  || fail "the fingerprint text must have whitespace and punctuation normalised, case kept: $normtext"

python3 "$TRACE" lock --check --root "$LOCK" >"$LOCK/check1.out" || fail 'lock --check must exit 0 on an unchanged catalog'
grep -q 'clean' "$LOCK/check1.out" || fail "an unchanged catalog must report clean: $(cat "$LOCK/check1.out")"

python3 - "$LOCK" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]) / "docs/requirements/area.md"
path.write_text(path.read_text().replace("persist the note.", "persist the note right away."))
PY

python3 "$TRACE" lock --check --root "$LOCK" >"$LOCK/check2.out" || fail 'lock --check must exit 0, report only'
grep -q 'lock mismatch: REQ-AREA-001' "$LOCK/check2.out" || fail "a changed wording must be reported: $(cat "$LOCK/check2.out")"
grep -q '1 approved requirement(s) changed (report only)' "$LOCK/check2.out" \
  || fail "the summary must say report only: $(cat "$LOCK/check2.out")"

python3 "$TRACE" lock --write --root "$LOCK" >"$LOCK/write2.out" || fail 'lock --write must exit 0 after a real change'
grep -q 'revised: REQ-AREA-001' "$LOCK/write2.out" || fail "a changed requirement must be reported revised: $(cat "$LOCK/write2.out")"
revision2="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["requirements"]["REQ-AREA-001"]["revision"])' "$LOCK/docs/requirements/.spec-lock.json")"
[[ "$revision2" == "2" ]] || fail "a changed requirement's normative text must get a new revision: $revision2"

# SDLC-D-014.W1 matrix mode: a row per requirement the brief cites, generated into its
# "## Coverage matrix" section between markers (a re-run replaces, not duplicates); OK
# needs a passing --results outcome, GAP otherwise; a brief's "## Deferred" table (this
# writer's own placeholder shape pending brief_lint.py's schema) turns a GAP into
# Deferred with a reason and expiry, or into N/A; an expired Deferred becomes GAP; exit
# is non-zero on any GAP, unconditionally (no --strict for this subcommand).
MATRIX="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-matrix.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX"' EXIT
mkdir -p "$MATRIX/docs/requirements" "$MATRIX/docs/tasks" "$MATRIX/AppTests"
cat >"$MATRIX/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — passes

Status: approved

Core: P1

## REQ-AREA-002 — no test cites it

Status: approved

Core: P1

## REQ-AREA-003 — device-only, deferred

Status: approved

Core: P1
MD
printf '@Test("REQ-AREA-001: passes") func passes() {}\n' >"$MATRIX/AppTests/AreaTests.swift"
cat >"$MATRIX/results.json" <<'JSON'
{"testNodes":[{"nodeType":"Test Case","name":"REQ-AREA-001: passes","nodeIdentifier":"AreaTests/passes()","result":"Passed"}]}
JSON
cat >"$MATRIX/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001, REQ-AREA-002, REQ-AREA-003

## Deferred

| Requirement | Status | Reason | Backlog | Expiry |
|---|---|---|---|---|
| REQ-AREA-003 | Deferred | device-only | docs/planning/backlog.md#a3 | 2099-01-01 |

Deferred approval: "yes" (AskUserQuestion, option "Approve the Deferred table as shown")

## Coverage matrix
MD

if python3 "$TRACE" matrix --root "$MATRIX" --brief "$MATRIX/docs/tasks/round.md" --results "$MATRIX/results.json" >"$MATRIX/matrix1.out"; then
  fail "matrix must exit non-zero while REQ-AREA-002 is a GAP: $(cat "$MATRIX/matrix1.out")"
fi
grep -q '| REQ-AREA-001 | OK | passed |' "$MATRIX/matrix1.out" || fail "a passing result must show OK: $(cat "$MATRIX/matrix1.out")"
grep -q '| REQ-AREA-002 | GAP | no test cites this requirement |' "$MATRIX/matrix1.out" || fail "an uncited requirement must show GAP with a reason: $(cat "$MATRIX/matrix1.out")"
grep -q '| REQ-AREA-003 | Deferred | device-only, expires 2099-01-01 |' "$MATRIX/matrix1.out" || fail "an unexpired Deferred row must stay Deferred: $(cat "$MATRIX/matrix1.out")"
grep -q '^matrix: 3 requirement(s), 1 GAP$' "$MATRIX/matrix1.out" || fail "the summary line must count exactly one GAP: $(cat "$MATRIX/matrix1.out")"
grep -q '^Deferred share: 1 of 3$' "$MATRIX/matrix1.out" || fail "the Deferred share line must count the one Deferred row: $(cat "$MATRIX/matrix1.out")"
briefwritten="$(cat "$MATRIX/docs/tasks/round.md")"
grep -q '<!-- spec_trace:matrix:begin -->' <<<"$briefwritten" || fail 'the brief must gain the generated block markers'
grep -q '| REQ-AREA-002 | GAP |' <<<"$briefwritten" || fail 'the brief file itself must be updated with the table, not only stdout'

# An expired Deferred becomes GAP, and a second run replaces the block instead of duplicating it.
python3 - "$MATRIX" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]) / "docs/tasks/round.md"
path.write_text(path.read_text().replace("2099-01-01", "2020-01-01"))
PY
if python3 "$TRACE" matrix --root "$MATRIX" --brief "$MATRIX/docs/tasks/round.md" --results "$MATRIX/results.json" >"$MATRIX/matrix2.out"; then
  fail "an expired Deferred must become a blocking GAP: $(cat "$MATRIX/matrix2.out")"
fi
grep -q '| REQ-AREA-003 | GAP | Deferred expired 2020-01-01 |' "$MATRIX/matrix2.out" || fail "expiry must be named in the detail: $(cat "$MATRIX/matrix2.out")"
markers="$(grep -c 'spec_trace:matrix:begin' "$MATRIX/docs/tasks/round.md")"
[[ "$markers" == "1" ]] || fail "a second run must replace the generated block, not duplicate it: $markers marker(s)"

# Without --results nothing can be OK; an unknown requirement in the catalog is a GAP too.
python3 - "$MATRIX" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]) / "docs/tasks/round.md"
text = path.read_text().split("<!-- spec_trace:matrix:begin -->")[0]
path.write_text(text.replace("REQ-AREA-001, REQ-AREA-002, REQ-AREA-003", "REQ-AREA-001, REQ-AREA-999"))
PY
if python3 "$TRACE" matrix --root "$MATRIX" --brief "$MATRIX/docs/tasks/round.md" >"$MATRIX/matrix3.out"; then
  fail 'matrix without --results must still exit non-zero (nothing can be OK)'
fi
grep -q '| REQ-AREA-001 | GAP | no --results given |' "$MATRIX/matrix3.out" || fail "without --results every cited requirement must be GAP: $(cat "$MATRIX/matrix3.out")"
grep -q '| REQ-AREA-999 | GAP | not defined in the requirements catalog |' "$MATRIX/matrix3.out" || fail "a requirement absent from the catalog must be a GAP, not silently skipped: $(cat "$MATRIX/matrix3.out")"

# SDLC-D-020.W1: an id a test cites but the catalog does not define fails the matrix
# unconditionally (kept; SUSPECT and per-test fingerprints, SDLC-D-020 points 2/3, are
# parked); a REQ-NEW citation is reported, not blocking.
SUSPECT="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-suspect.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT"' EXIT
mkdir -p "$SUSPECT/docs/requirements" "$SUSPECT/docs/tasks" "$SUSPECT/AppTests"
cat >"$SUSPECT/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — save persists

Status: approved

Core: P1

When the user taps save, the app shall persist the note.
MD
printf '@Test("REQ-AREA-001: passes") func passes() {}\n' >"$SUSPECT/AppTests/AreaTests.swift"
cat >"$SUSPECT/results.json" <<'JSON'
{"testNodes":[{"nodeType":"Test Case","name":"REQ-AREA-001: passes","nodeIdentifier":"AreaTests/passes()","result":"Passed"}]}
JSON
cat >"$SUSPECT/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001
MD
matrix_clean="$(python3 "$TRACE" matrix --root "$SUSPECT" --brief "$SUSPECT/docs/tasks/round.md" --results "$SUSPECT/results.json")" \
  || fail "matrix must exit 0 with a passing test: $matrix_clean"
grep -q '| REQ-AREA-001 | OK | passed |' <<<"$matrix_clean" || fail "a passing citation must read OK: $matrix_clean"

# An id a test cites but the catalog does not define fails unconditionally.
printf '@Test("REQ-AREA-999: ghost") func ghost() {}\n' >"$SUSPECT/AppTests/GhostTests.swift"
if python3 "$TRACE" matrix --root "$SUSPECT" --brief "$SUSPECT/docs/tasks/round.md" --results "$SUSPECT/results.json" >"$SUSPECT/unknown.out"; then
  fail "an unknown id cited by a test must fail the matrix: $(cat "$SUSPECT/unknown.out")"
fi
grep -q 'unknown_in_specs: REQ-AREA-999 (AppTests/GhostTests.swift)' "$SUSPECT/unknown.out" \
  || fail "the unknown id must be named with its citing file: $(cat "$SUSPECT/unknown.out")"
rm "$SUSPECT/AppTests/GhostTests.swift"

# A REQ-NEW citation is reported at round close, never blocking on its own.
printf '@Test("REQ-NEW: a gap the writer found") func newGap() {}\n' >"$SUSPECT/AppTests/ProposedTests.swift"
newout="$(python3 "$TRACE" matrix --root "$SUSPECT" --brief "$SUSPECT/docs/tasks/round.md" --results "$SUSPECT/results.json")" \
  || fail "a lone REQ-NEW citation must not fail the matrix: $newout"
grep -q 'proposed_new (REQ-NEW still cited, must be numbered before round close): AppTests/ProposedTests.swift' <<<"$newout" \
  || fail "REQ-NEW must be reported for round close: $newout"

# SDLC-D-027.W2 (device-check result table closure) is parked: a device-only Deferred
# now falls back unconditionally to the ordinary expiry-based Deferred handling.
DEVICE="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-device.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE"' EXIT
mkdir -p "$DEVICE/docs/requirements" "$DEVICE/docs/tasks"
cat >"$DEVICE/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — widget tint, device-only

Status: approved

Core: P1
MD
cat >"$DEVICE/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001

## Deferred

| Requirement | Status | Reason | Backlog | Expiry |
|---|---|---|---|---|
| REQ-AREA-001 | Deferred | device-only | docs/planning/backlog.md#a1 | 2099-01-01 |

Deferred approval: "yes" (AskUserQuestion, option "Approve the Deferred table as shown")
MD
nodevice="$(python3 "$TRACE" matrix --root "$DEVICE" --brief "$DEVICE/docs/tasks/round.md")" \
  || fail "an unexpired Deferred must not block: $nodevice"
grep -q '| REQ-AREA-001 | Deferred | device-only, expires 2099-01-01 |' <<<"$nodevice" \
  || fail "the brief's own expiry rule must apply, with no device-check record mechanism left to consult: $nodevice"

python3 - "$DEVICE" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]) / "docs/tasks/round.md"
path.write_text(path.read_text().replace("2099-01-01", "2020-01-01"))
PY
if python3 "$TRACE" matrix --root "$DEVICE" --brief "$DEVICE/docs/tasks/round.md" >"$DEVICE/expired.out"; then
  fail "an expired device-only Deferred must still become a blocking GAP: $(cat "$DEVICE/expired.out")"
fi
grep -q '| REQ-AREA-001 | GAP | Deferred expired 2020-01-01 |' "$DEVICE/expired.out" \
  || fail "expiry must be named in the detail: $(cat "$DEVICE/expired.out")"

# Round 1 repair, finding 2: a Requirement cell citing several ids in ## Deferred must
# bind the row to every cited id, not an arbitrary single one picked from a Python set
# — `next(iter(cited))`'s pick depends on PYTHONHASHSEED, so it is exercised at two
# fixed seeds known to order a two-id set differently.
MULTIID="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-multiid.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID"' EXIT
mkdir -p "$MULTIID/docs/requirements" "$MULTIID/docs/tasks"
cat >"$MULTIID/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — first of a jointly deferred pair

Status: approved

Core: P1

## REQ-AREA-002 — second of a jointly deferred pair

Status: approved

Core: P1
MD
cat >"$MULTIID/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001, REQ-AREA-002

## Deferred

| Requirement | Status | Reason | Backlog | Expiry |
|---|---|---|---|---|
| REQ-AREA-001, REQ-AREA-002 | Deferred | tool-blocked | docs/planning/backlog.md#pair | 2099-01-01 |

Deferred approval: "yes" (AskUserQuestion, option "Approve the Deferred table as shown")
MD
for seed in 0 1; do
  out="$(PYTHONHASHSEED=$seed python3 "$TRACE" matrix --root "$MULTIID" --brief "$MULTIID/docs/tasks/round.md")" && status=0 || status=$?
  grep -q '| REQ-AREA-001 | Deferred | tool-blocked' <<<"$out" \
    || fail "PYTHONHASHSEED=$seed: a two-id Requirement cell must still defer the first id: $out"
  grep -q '| REQ-AREA-002 | Deferred | tool-blocked' <<<"$out" \
    || fail "PYTHONHASHSEED=$seed: a two-id Requirement cell must bind every cited id, not an arbitrary one: $out"
  [[ "$status" == 0 ]] || fail "PYTHONHASHSEED=$seed: a fully deferred pair must not block round close: $out"
done

# SDLC-D-014 Deferred row validation: an exact header is required (exit 2 otherwise,
# carrying over round-1 repair 74e29a7's brief_lint.py check now that brief_lint's own
# Deferred table helpers are parked); a row failing its reason, backlog link, ISO
# expiry, or the brief's single 'Deferred approval:' line counts as GAP, not Deferred.
DEFERREDVALID="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-deferredvalid.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID"' EXIT
mkdir -p "$DEFERREDVALID/docs/requirements" "$DEFERREDVALID/docs/tasks"
cat >"$DEFERREDVALID/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — deferred, badly

Status: approved

Core: P1
MD

# A header row that is not exactly the required column order/names must exit 2.
cat >"$DEFERREDVALID/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001

## Deferred

| Requirement | Reason | Status | Backlog | Expiry |
|---|---|---|---|---|
| REQ-AREA-001 | device-only | Deferred | docs/planning/backlog.md#a1 | 2099-01-01 |

Deferred approval: "yes" (AskUserQuestion, option "Approve the Deferred table as shown")
MD
set +e
python3 "$TRACE" matrix --root "$DEFERREDVALID" --brief "$DEFERREDVALID/docs/tasks/round.md" >"$DEFERREDVALID/header.out" 2>&1
status=$?
set -e
[[ "$status" == 2 ]] || fail "a reordered Deferred header must exit 2, not $status: $(cat "$DEFERREDVALID/header.out")"
grep -q 'header must be exactly' "$DEFERREDVALID/header.out" || fail "the failure must say why: $(cat "$DEFERREDVALID/header.out")"

# A correct header with an unrecognized reason, no backlog link, a non-ISO expiry, and
# no 'Deferred approval:' line must each be reported and the row must stay GAP.
cat >"$DEFERREDVALID/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001

## Deferred

| Requirement | Status | Reason | Backlog | Expiry |
|---|---|---|---|---|
| REQ-AREA-001 | Deferred | not-a-real-reason |  | not-a-date |
MD
if python3 "$TRACE" matrix --root "$DEFERREDVALID" --brief "$DEFERREDVALID/docs/tasks/round.md" >"$DEFERREDVALID/invalid.out"; then
  fail "an invalid Deferred row must still block as a GAP: $(cat "$DEFERREDVALID/invalid.out")"
fi
grep -q "reason not in \['device-only', 'out-of-scope', 'owner-decision', 'tool-blocked'\]" "$DEFERREDVALID/invalid.out" \
  || fail "an unrecognized reason must be named: $(cat "$DEFERREDVALID/invalid.out")"
grep -q 'no backlog link' "$DEFERREDVALID/invalid.out" || fail "a missing backlog link must be named: $(cat "$DEFERREDVALID/invalid.out")"
grep -q 'expiry is not an ISO date' "$DEFERREDVALID/invalid.out" || fail "a non-ISO expiry must be named: $(cat "$DEFERREDVALID/invalid.out")"
grep -q "0 'Deferred approval:' line(s)" "$DEFERREDVALID/invalid.out" || fail "a missing approval line must be named: $(cat "$DEFERREDVALID/invalid.out")"
grep -q '| REQ-AREA-001 | GAP | invalid Deferred row:' "$DEFERREDVALID/invalid.out" \
  || fail "the row itself must read GAP, not Deferred: $(cat "$DEFERREDVALID/invalid.out")"

# Otherwise-valid rows with two 'Deferred approval:' lines must also stay GAP: one
# batch approval, not an ambiguous count.
python3 - "$DEFERREDVALID" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]) / "docs/tasks/round.md"
text = path.read_text().replace(
    "| REQ-AREA-001 | Deferred | not-a-real-reason |  | not-a-date |",
    "| REQ-AREA-001 | Deferred | device-only | docs/planning/backlog.md#a1 | 2099-01-01 |\n\n"
    'Deferred approval: "yes" (AskUserQuestion, option "Approve")\n'
    'Deferred approval: "yes" (AskUserQuestion, option "Approve, again")',
)
path.write_text(text)
PY
if python3 "$TRACE" matrix --root "$DEFERREDVALID" --brief "$DEFERREDVALID/docs/tasks/round.md" >"$DEFERREDVALID/dupapproval.out"; then
  fail "two 'Deferred approval:' lines must still block as a GAP: $(cat "$DEFERREDVALID/dupapproval.out")"
fi
grep -q "2 'Deferred approval:' line(s)" "$DEFERREDVALID/dupapproval.out" \
  || fail "the duplicate approval count must be named: $(cat "$DEFERREDVALID/dupapproval.out")"

# SDLC-D-014 point 1: only ids cited inside a '#### Card:' block become matrix rows —
# not the status block, an authorization quote, or review text (round-2 finding:
# req_ids() of the whole brief picked those up too, giving an id a row though no
# card actually cited it).
CARDSCOPE="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-cardscope.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE"' EXIT
mkdir -p "$CARDSCOPE/docs/requirements" "$CARDSCOPE/docs/tasks"
cat >"$CARDSCOPE/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — cited inside a card

Status: approved

Core: P1

## REQ-AREA-002 — cited only outside any card

Status: approved

Core: P1
MD
cat >"$CARDSCOPE/docs/tasks/round.md" <<'MD'
# Task — round

Authorized scope: quotes REQ-AREA-002 in passing, not as a card citation.

#### Card: only-card

Requirements: REQ-AREA-001

### Round 1 review

REQ-AREA-002 mentioned again here, still not inside a card.
MD
cardscope_out="$(python3 "$TRACE" matrix --root "$CARDSCOPE" --brief "$CARDSCOPE/docs/tasks/round.md")" || true
grep -q '| REQ-AREA-001 |' <<<"$cardscope_out" || fail "an id cited inside a card must get a matrix row: $cardscope_out"
grep -q 'REQ-AREA-002' <<<"$cardscope_out" && fail "an id cited only outside any card must not get a matrix row: $cardscope_out"

# Round 1 repair, finding 3: `lock --write` must never drop a stored requirement just
# because it is currently unapproved (Status: reopened for editing) — the entry stays,
# inactive, so a later re-approval with changed text continues the revision count
# ("revised:", not "new:"), instead of silently forgetting it was ever locked.
DROP="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-drop.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP"' EXIT
mkdir -p "$DROP/docs/requirements"
cat >"$DROP/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — save persists

Status: approved

Core: P1

When the user taps save, the app shall persist the note.
MD
python3 "$TRACE" lock --write --root "$DROP" >"$DROP/write1.out" || fail 'lock --write must succeed on the initial approval'
grep -q 'new: REQ-AREA-001' "$DROP/write1.out" || fail "the first write must record the requirement as new: $(cat "$DROP/write1.out")"

python3 - "$DROP" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]) / "docs/requirements/area.md"
text = path.read_text()
text = text.replace("Status: approved", "Status: proposed")
text = text.replace("persist the note.", "persist the note right away.")
path.write_text(text)
PY

python3 "$TRACE" lock --write --root "$DROP" >"$DROP/write2.out" || fail 'lock --write must succeed while the requirement is unapproved'
still_stored="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print("REQ-AREA-001" in d["requirements"])' "$DROP/docs/requirements/.spec-lock.json")"
[[ "$still_stored" == "True" ]] \
  || fail 'lock --write must keep a previously-locked requirement in the lock while it is unapproved, not drop it'

python3 - "$DROP" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]) / "docs/requirements/area.md"
path.write_text(path.read_text().replace("Status: proposed", "Status: approved"))
PY

python3 "$TRACE" lock --write --root "$DROP" >"$DROP/write3.out" || fail 'lock --write must succeed after the re-approval'
grep -q 'revised: REQ-AREA-001' "$DROP/write3.out" \
  || fail "a re-approved, previously-locked requirement must be reported revised, not new, even after an unapproved gap: $(cat "$DROP/write3.out")"
revision_after="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["requirements"]["REQ-AREA-001"]["revision"])' "$DROP/docs/requirements/.spec-lock.json")"
[[ "$revision_after" == "2" ]] \
  || fail "the revision count must continue across the unapproved gap instead of resetting to 1: $revision_after"

# `lock --check` also reports a locked-active entry that is no longer approved (a
# demote-and-edit): the fingerprint comparison alone only looks at requirements still
# approved today, so a Status: approved -> proposed change would otherwise never
# surface at --check, even with the text then edited under the lock's protection.
DEMOTED="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-demoted.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED"' EXIT
mkdir -p "$DEMOTED/docs/requirements"
cat >"$DEMOTED/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — save persists

Status: approved

Core: P1

When the user taps save, the app shall persist the note.
MD
python3 "$TRACE" lock --write --root "$DEMOTED" >/dev/null || fail 'lock --write must succeed on the initial approval'
python3 "$TRACE" lock --check --root "$DEMOTED" >"$DEMOTED/check1.out" || fail 'lock --check must exit 0 while still approved'
grep -q 'clean' "$DEMOTED/check1.out" || fail "an unchanged, still-approved catalog must report clean: $(cat "$DEMOTED/check1.out")"

python3 - "$DEMOTED" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]) / "docs/requirements/area.md"
path.write_text(path.read_text().replace("Status: approved", "Status: proposed"))
PY
python3 "$TRACE" lock --check --root "$DEMOTED" >"$DEMOTED/check2.out" || fail 'lock --check must exit 0, report only, after a demotion'
grep -q 'lock demoted: REQ-AREA-001' "$DEMOTED/check2.out" \
  || fail "a locked-active requirement that is no longer approved must be reported: $(cat "$DEMOTED/check2.out")"
grep -q '1 locked requirement(s) demoted since the lock (report only)' "$DEMOTED/check2.out" \
  || fail "the demoted-count summary must say report only: $(cat "$DEMOTED/check2.out")"

# Round 1 repair, finding 6: `lock --check` with no lock file on disk must not read as
# trivially clean (nothing is ever `in stored` when `stored` is the empty default) when
# there is at least one approved requirement to protect; it must say so and exit 2. With
# zero approved requirements, there is nothing to lock, so it stays exit 0 with a note.
NOLOCK="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-nolock.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED" "$NOLOCK"' EXIT
mkdir -p "$NOLOCK/docs/requirements"
cat >"$NOLOCK/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — save persists

Status: approved

Core: P1

When the user taps save, the app shall persist the note.
MD
set +e
python3 "$TRACE" lock --check --root "$NOLOCK" >"$NOLOCK/check.out" 2>&1
status=$?
set -e
[[ "$status" == 2 ]] || fail "lock --check with no lock file and an approved requirement must exit 2, not $status: $(cat "$NOLOCK/check.out")"
# --root is resolved (symlinks and all) inside spec_trace.py, so match the message by
# suffix rather than $NOLOCK's own unresolved spelling (e.g. macOS /var vs /private/var).
grep -q 'no lock file: .*docs/requirements/\.spec-lock\.json (run lock --write)$' "$NOLOCK/check.out" \
  || fail "the missing-lock message must name the path and the fix: $(cat "$NOLOCK/check.out")"

python3 - "$NOLOCK" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]) / "docs/requirements/area.md"
path.write_text(path.read_text().replace("Status: approved", "Status: proposed"))
PY
python3 "$TRACE" lock --check --root "$NOLOCK" >"$NOLOCK/check2.out" 2>&1 \
  || fail "lock --check with no lock file and no approved requirements must still exit 0: $(cat "$NOLOCK/check2.out")"
grep -q 'no lock file' "$NOLOCK/check2.out" || fail "an empty approved set must still be noted, not silently exit 0: $(cat "$NOLOCK/check2.out")"

# Round 1 repair, finding 10: normative_text_for must not fall back to a bold-label
# search when a heading-defined requirement's own body is genuinely empty (an empty
# list is not None), and lock --write must refuse to lock an approved requirement with
# no normative text at all (SDLC-D-001/SDLC-D-003 require EARS text for approval).
EMPTYBODY="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-emptybody.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED" "$NOLOCK" "$EMPTYBODY"' EXIT
mkdir -p "$EMPTYBODY/docs/requirements"
cat >"$EMPTYBODY/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — empty body, decoy mention elsewhere

Status: approved

Core: P1

## Scope

See **REQ-AREA-001** mentioned here for context, not as a redefinition.
MD
python3 - "$TRACE" "$EMPTYBODY" <<'PY'
import importlib.util, sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("spec_trace_under_test", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

doc = Path(sys.argv[2]) / "docs/requirements/area.md"
text = module.normative_text_for("REQ-AREA-001", doc)
if text != "":
    print(f"FAIL normative_text_for: a heading-defined requirement with an empty body "
          f"must not fall back to a bold-label mention elsewhere, got {text!r}")
    sys.exit(1)
PY

if python3 "$TRACE" lock --write --root "$EMPTYBODY" >"$EMPTYBODY/write.out" 2>&1; then
  fail "lock --write must refuse an approved requirement with no normative text: $(cat "$EMPTYBODY/write.out")"
fi
grep -q 'REQ-AREA-001' "$EMPTYBODY/write.out" || fail "the empty-body failure must name the id: $(cat "$EMPTYBODY/write.out")"
[[ ! -f "$EMPTYBODY/docs/requirements/.spec-lock.json" ]] || fail 'lock --write must not write a lock file when it refuses'

# Round 1 repair, finding 11: SDLC-D-042 point 4 scopes the file-level Status:
# restriction to approval only. A file-level Status: retired (or any value besides
# approved) still cascades to its requirements like Core: does; Status: approved alone
# stays ignored (already covered by the $INLINE fixture above; re-checked here too).
RETIRE="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-retire.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED" "$NOLOCK" "$EMPTYBODY" "$RETIRE"' EXIT
mkdir -p "$RETIRE/docs/requirements"
cat >"$RETIRE/docs/requirements/area.md" <<'MD'
# Area

Status: retired

## REQ-AREA-001 — old behavior, whole file retired

Core: P1
MD
retired_out="$(python3 "$TRACE" --root "$RETIRE" --json)"
[[ "$(python3 -c 'import json,sys; print(json.load(sys.stdin)["requirements"])' <<<"$retired_out")" == "0" ]] \
  || fail "a file-level Status: retired must cascade and exclude its requirements from the report entirely: $retired_out"
[[ -z "$(field uncovered <<<"$retired_out")" ]] || fail "a retired-by-cascade requirement must not show as an uncovered gap: $(field uncovered <<<"$retired_out")"

cat >"$RETIRE/docs/requirements/other.md" <<'MD'
# Other

Status: approved

## REQ-AREA-002 — whole file marked approved, own line still missing

Core: P1
MD
approved_out="$(python3 "$TRACE" --root "$RETIRE" --json --approved-only)"
[[ "$(field unapproved <<<"$approved_out")" == "REQ-AREA-002" ]] \
  || fail "a file-level Status: approved must still leave its requirements unapproved: $(field unapproved <<<"$approved_out")"

# Round 1 repair, finding 14 (low): a lock file that is valid JSON but not an object
# (here, a JSON array) must fail with a clean message, not an unrelated AttributeError
# from .setdefault on a list.
NONOBJLOCK="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-nonobjlock.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED" "$NOLOCK" "$EMPTYBODY" "$RETIRE" "$NONOBJLOCK"' EXIT
mkdir -p "$NONOBJLOCK/docs/requirements"
printf '[]' >"$NONOBJLOCK/docs/requirements/.spec-lock.json"
if python3 "$TRACE" lock --check --root "$NONOBJLOCK" >"$NONOBJLOCK/out" 2>&1; then
  fail "lock --check on a non-object lock file must fail: $(cat "$NONOBJLOCK/out")"
fi
grep -q 'AttributeError\|Traceback' "$NONOBJLOCK/out" && fail "a non-object lock file must not crash with a raw traceback: $(cat "$NONOBJLOCK/out")"
grep -q 'lock file is not a JSON object' "$NONOBJLOCK/out" || fail "the failure must say what is wrong: $(cat "$NONOBJLOCK/out")"

# Round 1 repair, finding 14 (low): a brief with more than one matrix marker pair (or a
# mismatched begin/end count) must fail the splice with a clear message, not silently
# swallow or duplicate brief content by matching only the first pair.
DUPMARKER="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-dupmarker.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED" "$NOLOCK" "$EMPTYBODY" "$RETIRE" "$NONOBJLOCK" "$DUPMARKER"' EXIT
mkdir -p "$DUPMARKER/docs/requirements" "$DUPMARKER/docs/tasks"
cat >"$DUPMARKER/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — passes

Status: approved

Core: P1
MD
cat >"$DUPMARKER/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001

## Coverage matrix

<!-- spec_trace:matrix:begin -->
old block one
<!-- spec_trace:matrix:end -->

<!-- spec_trace:matrix:begin -->
old block two
<!-- spec_trace:matrix:end -->
MD
before_dup="$(cat "$DUPMARKER/docs/tasks/round.md")"
if python3 "$TRACE" matrix --root "$DUPMARKER" --brief "$DUPMARKER/docs/tasks/round.md" >"$DUPMARKER/out" 2>&1; then
  fail "matrix must refuse to splice a brief with two marker pairs: $(cat "$DUPMARKER/out")"
fi
grep -q 'found 2 begin marker(s) and 2 end marker(s)' "$DUPMARKER/out" || fail "the failure must name the actual marker counts: $(cat "$DUPMARKER/out")"
[[ "$(cat "$DUPMARKER/docs/tasks/round.md")" == "$before_dup" ]] || fail 'a refused splice must leave the brief untouched'

# Round 1 repair, finding 14 (low): a Deferred reason compares to DEFERRED_REASONS
# case-insensitively, like the device-only check already does.
LOWS="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-lows.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED" "$NOLOCK" "$EMPTYBODY" "$RETIRE" "$NONOBJLOCK" "$DUPMARKER" "$LOWS"' EXIT
mkdir -p "$LOWS/docs/requirements" "$LOWS/docs/tasks"
cat >"$LOWS/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — deferred with a mixed-case reason

Status: approved

Core: P1

The area shall stay deferred for this fixture.
MD
cat >"$LOWS/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001

## Deferred

| Requirement | Status | Reason | Backlog | Expiry |
|---|---|---|---|---|
| REQ-AREA-001 | Deferred | Tool-Blocked | docs/planning/backlog.md#a1 | 2099-01-01 |

Deferred approval: "yes" (AskUserQuestion, option "Approve the Deferred table as shown")
MD
lows_out="$(python3 "$TRACE" matrix --root "$LOWS" --brief "$LOWS/docs/tasks/round.md" 2>"$LOWS/matrix.err")" || true
grep -q 'Traceback' "$LOWS/matrix.err" && fail "matrix must not crash: $(cat "$LOWS/matrix.err")"
grep -q '| REQ-AREA-001 | Deferred | Tool-Blocked, expires 2099-01-01 |' <<<"$lows_out" \
  || fail "a mixed-case reason matching DEFERRED_REASONS case-insensitively must not be flagged as unrecognized: $lows_out"
grep -q 'reason not in' <<<"$lows_out" && fail "a recognized reason (case-insensitively) must not show the unrecognized-reason suffix: $lows_out"

# Round 1 repair, finding 14 (low): cmd_matrix must check req_dir.is_dir() like
# cmd_lock already does, instead of silently reading a missing/mistyped
# --requirements directory as zero requirements.
NOREQDIR="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-noreqdir.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED" "$NOLOCK" "$EMPTYBODY" "$RETIRE" "$NONOBJLOCK" "$DUPMARKER" "$LOWS" "$NOREQDIR"' EXIT
mkdir -p "$NOREQDIR/docs/tasks"
cat >"$NOREQDIR/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001
MD
if python3 "$TRACE" matrix --root "$NOREQDIR" --brief "$NOREQDIR/docs/tasks/round.md" >"$NOREQDIR/out" 2>&1; then
  fail "matrix must fail on a missing requirements directory, not read it as zero requirements: $(cat "$NOREQDIR/out")"
fi
grep -q 'no requirements directory' "$NOREQDIR/out" || fail "the failure must say why: $(cat "$NOREQDIR/out")"

# Round 1 repair, finding P1-R0-2: a fenced code block inside a card must not end
# the card early. cited_ids_in_cards() matched every line against MD_HEADING
# without skipping fences, so a `# comment` line inside a ```bash block (a level-1
# heading match) closed the '#### Card:' block (level 4) right there — an id cited
# after the fence, still inside the same card, was silently dropped from the
# matrix instead of appearing (as OK or GAP).
FENCEDCARD="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-fencedcard.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED" "$NOLOCK" "$EMPTYBODY" "$RETIRE" "$NONOBJLOCK" "$DUPMARKER" "$LOWS" "$NOREQDIR" "$FENCEDCARD"' EXIT
mkdir -p "$FENCEDCARD/docs/requirements" "$FENCEDCARD/docs/tasks"
cat >"$FENCEDCARD/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — cited before the fence

Status: approved

Core: P1

## REQ-AREA-002 — cited after the fence, same card

Status: approved

Core: P1
MD
cat >"$FENCEDCARD/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001

```bash
# run the tests
```

Requirements: REQ-AREA-002
MD
fencedcard_out="$(python3 "$TRACE" matrix --root "$FENCEDCARD" --brief "$FENCEDCARD/docs/tasks/round.md")" || true
grep -q '| REQ-AREA-001 |' <<<"$fencedcard_out" \
  || fail "an id cited before the fence must still get a matrix row: $fencedcard_out"
grep -q '| REQ-AREA-002 |' <<<"$fencedcard_out" \
  || fail "a '#' comment inside a fenced code block must not close the card early, dropping an id cited after it: $fencedcard_out"

# P1-R1-1: --root/--results given before the lock/matrix subcommand must not be
# silently re-defaulted away. A decoy `docs/requirements` in cwd proves which root
# actually got read, instead of just erroring.
ARGORDER="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-argorder.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED" "$NOLOCK" "$EMPTYBODY" "$RETIRE" "$NONOBJLOCK" "$DUPMARKER" "$LOWS" "$NOREQDIR" "$FENCEDCARD" "$ARGORDER"' EXIT
mkdir -p "$ARGORDER/docs/requirements" "$ARGORDER/docs/tasks" "$ARGORDER/AppTests" "$ARGORDER/elsewhere/docs/requirements"
cat >"$ARGORDER/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — the real requirement --root must resolve to

Status: approved

Core: P1

When the user taps save, the app shall persist the note.
MD
cat >"$ARGORDER/elsewhere/docs/requirements/decoy.md" <<'MD'
# Decoy

## REQ-DECOY-001 — must not be the catalog spec_trace.py locks or matrices

Status: approved

Core: P1

When the user opens the decoy screen, the app shall show nothing useful.
MD
cat >"$ARGORDER/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001
MD
printf '@Test("REQ-AREA-001: passes") func passes() {}\n' >"$ARGORDER/AppTests/AreaTests.swift"
cat >"$ARGORDER/results.json" <<'JSON'
{"testNodes":[{"nodeType":"Test Case","name":"REQ-AREA-001: passes","nodeIdentifier":"AreaTests/passes()","result":"Passed"}]}
JSON

# --root before `lock`: a bug resolves it against cwd instead, and cwd's own
# docs/requirements (the decoy) happens to be valid, so the pre-fix symptom is a
# silent exit-0 write to the wrong lock file, not an error.
(cd "$ARGORDER/elsewhere" && python3 "$TRACE" --root "$ARGORDER" lock --write) >"$ARGORDER/lock-before.out" \
  || fail "--root before the lock subcommand must still resolve against it, not cwd: $(cat "$ARGORDER/lock-before.out")"
[[ -f "$ARGORDER/docs/requirements/.spec-lock.json" ]] \
  || fail '--root before the lock subcommand must write the lock file under that root, not cwd'
grep -q 'REQ-AREA-001' "$ARGORDER/docs/requirements/.spec-lock.json" \
  || fail "the lock written under --root must fingerprint the --root catalog's own requirement: $(cat "$ARGORDER/docs/requirements/.spec-lock.json")"
[[ ! -f "$ARGORDER/elsewhere/docs/requirements/.spec-lock.json" ]] \
  || fail '--root before the lock subcommand must not touch the cwd (decoy) requirements directory'

# --root and --results before `matrix`: dropping --root reads the decoy catalog
# (REQ-AREA-001 "not defined"); dropping --results turns every cited id into a "no
# --results given" GAP. Both must survive being given before the subcommand.
matrix_before="$(cd "$ARGORDER/elsewhere" && python3 "$TRACE" --root "$ARGORDER" --results "$ARGORDER/results.json" matrix --brief "$ARGORDER/docs/tasks/round.md")" \
  || fail "matrix with --root/--results before the subcommand must exit 0 on a passing, defined requirement: $matrix_before"
grep -q '| REQ-AREA-001 | OK | passed |' <<<"$matrix_before" \
  || fail "--root/--results given before the matrix subcommand must not be dropped: $matrix_before"

# The existing placement (after the subcommand, as the rest of this file already uses
# throughout) must keep working unchanged.
matrix_after="$(cd "$ARGORDER/elsewhere" && python3 "$TRACE" matrix --root "$ARGORDER" --brief "$ARGORDER/docs/tasks/round.md" --results "$ARGORDER/results.json")" \
  || fail "matrix with --root/--results after the subcommand must exit 0 on a passing, defined requirement: $matrix_after"
grep -q '| REQ-AREA-001 | OK | passed |' <<<"$matrix_after" \
  || fail "--root/--results given after the matrix subcommand must still work: $matrix_after"

# P1-R1-2: normative_body_lines() matched every line against MD_HEADING without
# skipping fenced code (P1-R0-2's bug class, fixed then only in cited_ids_in_cards).
# A `#` comment opening a ```gherkin fence ended the requirement body right there,
# so the Given/When/Then inside the fence never reached the lock fingerprint and an
# edit to it went undetected by `lock --check`.
FENCEDLOCK="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-fencedlock.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED" "$NOLOCK" "$EMPTYBODY" "$RETIRE" "$NONOBJLOCK" "$DUPMARKER" "$LOWS" "$NOREQDIR" "$FENCEDCARD" "$ARGORDER" "$FENCEDLOCK"' EXIT
mkdir -p "$FENCEDLOCK/docs/requirements"
cat >"$FENCEDLOCK/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — pay flow

Status: approved

Core: P1

The payment screen shall accept the given amount.

```gherkin
# happy path
Given the cart total is 10
When I pay 10
Then the payment succeeds
```
MD
python3 "$TRACE" lock --write --root "$FENCEDLOCK" >"$FENCEDLOCK/write.out" \
  || fail "lock --write on a fenced Given/When/Then must exit 0: $(cat "$FENCEDLOCK/write.out")"
grep -q 'When I pay 10' "$FENCEDLOCK/docs/requirements/.spec-lock.json" \
  || fail "the fenced Given/When/Then must reach the fingerprint: $(cat "$FENCEDLOCK/docs/requirements/.spec-lock.json")"
python3 - "$FENCEDLOCK" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]) / "docs/requirements/area.md"
path.write_text(path.read_text().replace("When I pay 10", "When I pay 99"))
PY
python3 "$TRACE" lock --check --root "$FENCEDLOCK" >"$FENCEDLOCK/check.out" \
  || fail "lock --check on a changed fenced body must still exit 0: $(cat "$FENCEDLOCK/check.out")"
grep -q 'lock mismatch: REQ-AREA-001' "$FENCEDLOCK/check.out" \
  || fail "editing text inside a fence must be caught as a lock mismatch, not read as unchanged: $(cat "$FENCEDLOCK/check.out")"

# Sibling fix, same commit: parse_deferred_table() had the identical unguarded
# MD_HEADING scan. A '#' comment inside a fenced block placed between the
# '## Deferred' heading and its table flips in_section off (its title is not
# 'deferred'), so the real header and row after the fence are never read; the
# citation then falls through to its ordinary GAP instead of Deferred.
FENCEDDEFERRED="$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-spec-trace-fenceddeferred.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$INLINE" "$PROSE" "$NEWREQ" "$LOCK" "$MATRIX" "$SUSPECT" "$DEVICE" "$MULTIID" "$DEFERREDVALID" "$CARDSCOPE" "$DROP" "$DEMOTED" "$NOLOCK" "$EMPTYBODY" "$RETIRE" "$NONOBJLOCK" "$DUPMARKER" "$LOWS" "$NOREQDIR" "$FENCEDCARD" "$ARGORDER" "$FENCEDLOCK" "$FENCEDDEFERRED"' EXIT
mkdir -p "$FENCEDDEFERRED/docs/requirements" "$FENCEDDEFERRED/docs/tasks"
cat >"$FENCEDDEFERRED/docs/requirements/area.md" <<'MD'
# Area

## REQ-AREA-001 — offline queue

Status: approved

Core: P1

When offline, the app shall queue the note to send later.
MD
cat >"$FENCEDDEFERRED/docs/tasks/round.md" <<'MD'
# Task — round

#### Card: round

Requirements: REQ-AREA-001

## Deferred

```text
# reasons must come from the closed list
```

| Requirement | Status | Reason | Backlog | Expiry |
|---|---|---|---|---|
| REQ-AREA-001 | Deferred | device-only | docs/planning/backlog.md#a1 | 2099-01-01 |

Deferred approval: "yes" (AskUserQuestion, option "Approve the Deferred table as shown")
MD
fenceddeferred_out="$(python3 "$TRACE" matrix --root "$FENCEDDEFERRED" --brief "$FENCEDDEFERRED/docs/tasks/round.md")" || true
grep -q '| REQ-AREA-001 | Deferred | device-only, expires 2099-01-01 |' <<<"$fenceddeferred_out" \
  || fail "a '#' comment inside a fenced code block in ## Deferred must not drop the real table row: $fenceddeferred_out"

echo "spec trace contracts: passed"
