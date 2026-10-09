#!/usr/bin/env python3
"""Check task briefs against the machine-readable part of the brief contract."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

# Keyword set of the retired method document agent-orchestration.md; detail belongs in Evidence or the status block.
STATES = ("open", "claimed", "blocked", "done")
FIELD = re.compile(
    r"^(Assignee|State|Evidence|Depends-on|Parallelism|Profile|Plan hash|"
    r"Repair extension approval|Outage|Scope audit|user-visible):[ \t]*(.*)$",
    re.MULTILINE,
)
# A fenced code block, stripped before header fields are read (see _header_block): a brief that
# quotes another brief's fields as a fenced example must not have that example read as its own.
FENCE = re.compile(r"^```.*?^```[ \t]*$", re.MULTILINE | re.DOTALL)
# The field is a permission with a number, so free text ("yes", "as needed") would authorize nothing checkable.
PARALLELISM = re.compile(r"^(none|up to [1-9]\d*)$")
PLACEHOLDER = re.compile(r"^(|pending|none|tbd|<.*>)$", re.IGNORECASE)
# A writer's step list, ticked one revertible change at a time: a subagent's edits survive only as
# commits (Claude Code /rewind does not restore them), so a ticked step names the commit that holds it.
WRITER_STEPS = re.compile(r"^## Writer steps[ \t]*\n(.*?)(?=^## |\Z)", re.MULTILINE | re.DOTALL)
TICKED = re.compile(r"^[ \t]*- \[[xX]\][ \t]*(.*)$", re.MULTILINE)
UNTICKED = re.compile(r"^[ \t]*- \[ \][ \t]*(.*)$", re.MULTILINE)
# A digit is required so an all-letter word such as "defaced" does not pass as a SHA.
SHA = re.compile(r"\b(?=[0-9a-f]*[0-9])[0-9a-f]{7,40}\b")

# A dispatch block is a heading naming itself a dispatch (a slice dispatch inside a brief, or a
# subagent task description recorded in one); SDLC-D-005 requires these five labelled lines in its body.
DISPATCH_HEADING = re.compile(r"^(#{2,4})[ \t]+.*\bdispatch\b.*$", re.MULTILINE | re.IGNORECASE)
DISPATCH_FIELDS = ("Objective", "Sources", "Intended deviations", "Boundaries", "Output")
# REQ-AREA-NNN (in-project, spec-pyramid SKILL.md) or PROJECT-REQ-AREA-NNN (cross-repository, SDLC-D-006).
REQ_OR_DECISION_ID = re.compile(r"\b(?:(?:[A-Z]{2,5}-)?REQ-[A-Z0-9]+-\d+|(?:KIT|SDLC)-[A-Z]+-\d+)\b")

# SDLC-D-015: the three work profiles, and the Evidence substrings (any one of each group, case-insensitive)
# that show a done brief actually ran that profile's required checks. Not a proof, only a lint-level smell
# test — like the rest of this script, it catches an omission, not a false claim.
PROFILES = ("fast", "fix", "round")
PROFILE_EVIDENCE_HINTS: dict[str, tuple[tuple[str, ...], ...]] = {
    "fast": (("test",), ("verify",)),
    "fix": (("fail",), ("verify",), ("review",)),
    "round": (("matrix",), ("review",)),
}

# SDLC-D-013: the plan hash covers the plan's normative sections (configurable headings, matched by
# exact heading text, case-insensitive, any level); "Plan hash:" recomputes and fails on mismatch.
DEFAULT_PLAN_HASH_HEADINGS = ("Scope", "Acceptance", "Constraints")
# SDLC-D-049 point 3: the plan approved through ExitPlanMode names the Plan hash and the approval
# record in `Authorized scope` quotes it. The header field alone can be refreshed after the plan
# changes, so the approved value is read from the record itself. The record runs to the next
# heading or the next status-block field of the brief template (layers.md), not to any `Label:`
# line: a record may quote the plan's own `Plan hash:` or `Publication:` lines at column 0. App
# records quote the hash in full or abbreviated as <head>…<tail> (Pitstop RD-012, 2026-09-24),
# sometimes wrapped onto the next line.
AUTHORIZED_SCOPE = re.compile(r"^Authorized scope:", re.MULTILINE)
STATUS_BLOCK_FIELDS = (
    "Current outcome",
    "Blocking decisions",
    "Permitted deviations",
    "Material assumptions",
    "Next step",
    "Requirements",
    "Acceptance specs",
    "Owned files",
    "Out of scope",
    "Failure conditions",
)
RECORD_END = re.compile(
    rf"^(?:#{{1,6}}[ \t]|(?:{'|'.join(re.escape(name) for name in STATUS_BLOCK_FIELDS)}):)",
    re.MULTILINE,
)
# As for SHA above, the head needs a digit, so prose such as "Plan hash defaced" is not a value.
APPROVED_PLAN_HASH = re.compile(
    r"\bPlan hash:?\s*`?(?P<head>(?=[0-9a-f]*[0-9])[0-9a-f]{7,64})"
    r"(?:[ \t]*(?:…|\.\.\.)[ \t]*(?P<tail>[0-9a-f]{4,63}))?(?![0-9a-f])",
    re.IGNORECASE,
)
# A round-N review block; both the plan-hash slice (Review SHA staleness) and the review-report
# format slice (SDLC-D-021/022, a later step) read the same heading so a round's review lives in one place.
ROUND_REVIEW_HEADING = re.compile(r"^(#{2,4})[ \t]+.*\bRound[ \t]+\d+[ \t]+review\b.*$", re.MULTILINE | re.IGNORECASE)
# The documented heading shape, "### Round <N> review — <slice> (YYYY-MM-DD)" (layers.md,
# "Round review"): the <slice> text between the em dash and the trailing date, read out so it
# can be compared to a card's slug by exact equality, never by substring - a `\b`-bounded
# substring search (repair round 1, medium 2's fix) still matched "onboarding" inside
# "onboarding-copy" because a hyphen is a non-word character, so `\bonboarding\b` finds a word
# boundary right at it.
ROUND_REVIEW_SLICE = re.compile(r"—[ \t]*(?P<slice>.+?)[ \t]*\([0-9]{4}-[0-9]{2}-[0-9]{2}\)[ \t]*$")

# SDLC-D-016: a round plan's cards. Checked whenever the heading appears (not gated on Profile: round)
# because the card's own required fields are a property of the block, not of what the brief declares.
CARD_HEADING = re.compile(r"^(#{2,4})[ \t]+Card:[ \t]*(.+)$", re.MULTILINE | re.IGNORECASE)
# The set `set_session_effort` accepts (Claude Code harness), so a card's effort routes to a real level.
EFFORT_LEVELS = ("low", "medium", "high", "xhigh", "max")
# SDLC-D-014 point 1: spec_trace.py's cmd_matrix collects cited requirement ids only from
# "#### Card:" blocks; a range or ellipsis shorthand there ('REQ-BOARD-001…028',
# 'REQ-ROAD-004, 008…015') never reaches the matrix, silently dropping requirements from the
# round's coverage. A REQ id immediately followed (after an optional ellipsis/dots/comma and
# whitespace) by a bare digit, rather than another full "REQ-" id, is that shorthand; the trailing
# repetition captures a chained continuation ("004, 008…015") in one match.
# Repair round 1, medium 3: an en dash, a plain hyphen or the word "to" are ordinary range
# separators too ('REQ-BOARD-001–028', 'REQ-ROAD-004-009', 'REQ-X-001 to 005') - recognising only
# ellipsis/dots/comma let these forms pass the full-id check and drop out of spec_trace's matrix
# the same way the originally-covered forms did.
_REQ_SHORTHAND_SEP = r"(?:…|\.\.|,|–|-|\bto\b)"
REQ_SHORTHAND = re.compile(
    rf"\bREQ-[A-Z0-9]+-\d+[ \t]*{_REQ_SHORTHAND_SEP}[ \t]*\d+"
    rf"(?:[ \t]*{_REQ_SHORTHAND_SEP}[ \t]*\d+)*"
)

# SDLC-D-025 point 1: "Analytics is part of done for round cards: a product question, a metric, a
# threshold and the instrumentation, like a test; fast and fix are exempt" - so unlike model/effort
# these are checked only for Profile: round, by the caller.
CARD_ANALYTICS_FIELDS = ("product question", "metric", "threshold")
# Pilot-minimum package: a card with no user-facing change may answer an analytics field
# "n/a — <reason>" instead of inventing a real question/metric/threshold for work nobody sees; the
# reason is required (a bare "n/a" answers nothing), and only a non-user-visible card may use it.
# Repair round 1, medium 1: any value starting with "n/a" (case-insensitive) is an n/a attempt -
# not only the exact "n/a" or "n/a - <reason>" spelling. An em dash, an en dash, a plain hyphen or
# a colon all separate the reason in practice, and a separator with nothing after it is still a
# bare n/a; recognising only one exact spelling let every other n/a form read as a real answer,
# bypassing both the reason requirement and the user-visible ban.
N_A_PREFIX = re.compile(r"^n/a\b", re.IGNORECASE)
N_A_SEPARATOR = re.compile(r"^[ \t]*[—–:-]+[ \t]*")

# SDLC-D-026: the changelog unit is a closed round card, or a closed fix brief, marked
# user-visible (point 1, and the fix-profile amendment); a closed change needs an "[unreleased]"
# line in CHANGELOG.md (point 2). Repair round 1, medium 3: the decision itself cites both Keep a
# Changelog forms - a bare "[unreleased]" and a real version placeholdered as unreleased, "[x.y] -
# unreleased" (Drive Check's own pre-existing file, SDLC-D-026's Problem section) - so both are
# accepted here.
CHANGELOG_UNRELEASED_HEADING = re.compile(
    r"^(#{1,6})[ \t]+(?:\[unreleased\]|\[[0-9]+(?:\.[0-9]+)*\][ \t]*-[ \t]*unreleased)[ \t]*$",
    re.MULTILINE | re.IGNORECASE,
)

# SDLC-D-021/SDLC-D-022: a review finding, a top-level list item under a Round-N-review heading:
# "- [level][blocking][new-or-recurring] file:line — scenario". "No findings." is the only other
# valid top-level item there. Tags are lowercase, matching the rest of this schema's field values.
TOP_LEVEL_ITEM = re.compile(r"^-[ \t]+(.+)$", re.MULTILINE)
FINDING = re.compile(
    r"^-[ \t]*\[(?P<level>high|medium|low)\]\[(?P<blocking>blocking|non-blocking)\]\[(?P<status>new|recurring)\]"
    r"[ \t]+(?P<loc>\S+:\d+)[ \t]*[—-][ \t]*(?P<desc>.+)$"
)
NO_FINDINGS = "No findings."
ROUND_NUMBER = re.compile(r"\bRound[ \t]+(\d+)[ \t]+review\b", re.IGNORECASE)
REPAIR_BUDGET = 3


def _header_block(text: str) -> str:
    """The brief's header block: text before the first `## ` heading (a level-2 heading, the
    first real section), with fenced code blocks stripped first - so a fence containing its own
    "## "-looking line (an illustrative example nested inside the header block) cannot be
    mistaken for the real first section, and so a fenced example's field-shaped lines
    ("Profile: ...") are never read as this brief's own header fields. Repair round 1, medium 1:
    header fields (State, Assignee, Profile, ...) must come only from here, never from a fenced
    example or later prose - a brief that quotes the Profile-gated template inside a fence must
    not be promoted into that profile by a quoted `Profile: round` placeholder."""
    stripped = FENCE.sub("", text)
    end_match = re.search(r"^##[ \t]", stripped, re.MULTILINE)
    return stripped[: end_match.start()] if end_match else stripped


def _heading_blocks(text: str, heading: re.Pattern[str]) -> list[str]:
    """Slice text at each `heading` match, ending before the next heading of the same or
    shallower level (a Markdown `#`-level scope), so a block never swallows its siblings."""
    blocks = []
    for match in heading.finditer(text):
        level = len(match.group(1))
        end = len(text)
        for nxt in re.finditer(r"^(#{1,6})[ \t]+", text[match.end() :], re.MULTILINE):
            if len(nxt.group(1)) <= level:
                end = match.end() + nxt.start()
                break
        blocks.append(text[match.start() : end])
    return blocks


def check_dispatch_records(text: str) -> list[str]:
    """SDLC-D-005: a dispatch cites its sources and states objective, deviations, boundaries
    and output, so a writer (and the lint) can check the dispatch against them before editing."""
    problems = []
    for block in _heading_blocks(text, DISPATCH_HEADING):
        heading = block.splitlines()[0].strip().lstrip("#").strip()
        label = heading[:70]
        values: dict[str, str | None] = {}
        for name in DISPATCH_FIELDS:
            found = re.search(rf"^{re.escape(name)}:[ \t]*(.*)$", block, re.MULTILINE)
            values[name] = found.group(1).strip() if found else None
        for name in DISPATCH_FIELDS:
            value = values[name]
            if value is None:
                problems.append(f"dispatch {label!r}: missing {name}")
            elif name == "Intended deviations":
                if PLACEHOLDER.match(value) and value.strip().lower() != "none":
                    problems.append(f"dispatch {label!r}: Intended deviations must be 'none' or name a deviation")
            elif PLACEHOLDER.match(value):
                problems.append(f"dispatch {label!r}: {name} is empty or a placeholder")
        sources = values.get("Sources")
        if sources and not PLACEHOLDER.match(sources):
            if not REQ_OR_DECISION_ID.search(sources) and "mockup" not in sources.lower():
                problems.append(f"dispatch {label!r}: Sources cites neither a REQ/decision ID nor a mockup section")
            if "repair" in heading.lower() and "finding" not in sources.lower():
                problems.append(f"dispatch {label!r}: a repair dispatch's Sources must cite the review finding it repairs")
        deviations = values.get("Intended deviations")
        if deviations and deviations.strip().lower() != "none" and not re.search(r"\b(?:KIT|SDLC)-D-\d+\b", deviations):
            problems.append(f"dispatch {label!r}: Intended deviations lacks its SDLC-D-NNN (or legacy KIT-D-NNN) record")
    return problems


def normalize_text(text: str) -> str:
    """SDLC-D-013/SDLC-D-003: collapse all whitespace runs to a single space, so reflowing a
    paragraph or re-indenting a list does not change a hash or a lock comparison."""
    return re.sub(r"\s+", " ", text).strip()


def _named_sections(text: str, heading_name: str) -> list[str]:
    """Bodies of every heading (any level) whose stripped text equals `heading_name`
    case-insensitively, each up to the next heading of ANY level (a normative section is prose, not
    a container - stopping only at a same-or-shallower heading would let a deeper heading with no
    shallower sibling after it, e.g. a review block nested after the last plan section, swallow the
    rest of the document into the hash). This is the same boundary spec_trace.py's line-by-line
    `in_section` reset applies to "## Deferred" and "## Suspect review", so a brief with more than
    one same-named section is read identically by both scripts."""
    blocks = []
    for match in re.finditer(r"^(#{1,6})[ \t]+(.+?)[ \t]*$", text, re.MULTILINE):
        if match.group(2).strip().lower() != heading_name.lower():
            continue
        end = len(text)
        next_heading = re.search(r"^#{1,6}[ \t]+", text[match.end() :], re.MULTILINE)
        if next_heading:
            end = match.end() + next_heading.start()
        blocks.append(text[match.end() : end])
    return blocks


def _section_body(text: str, heading_name: str) -> str | None:
    """Body of the first heading matching `heading_name` (see `_named_sections`); None if absent."""
    sections = _named_sections(text, heading_name)
    return sections[0] if sections else None


def compute_plan_hash(text: str, headings: list[str]) -> str:
    """SDLC-D-013: sha256 over the normalised, \\x1f-joined bodies of `headings`, in the given
    order (order is configuration, not document layout, so reordering sections in the plan does
    not itself change the hash). A heading absent from the plan contributes an empty section."""
    parts = [normalize_text(_section_body(text, name) or "") for name in headings]
    return hashlib.sha256("\x1f".join(parts).encode("utf-8")).hexdigest()


def check_plan_hash_sections(text: str, headings: list[str]) -> list[str]:
    """SDLC-D-013: the Plan hash protects nothing unless the brief actually has the sections it
    hashes - a brief missing one of `headings`, or with an empty body for it, contributes an empty
    string to the hash the same way a real, correctly-empty plan never would, so two very
    different (or absent) plans can hash identically. Required once `Profile: round`, alongside
    Plan hash itself."""
    problems = []
    for name in headings:
        body = _section_body(text, name)
        if body is None or not normalize_text(body):
            problems.append(f"Profile round requires a non-empty '## {name}' section")
    return problems


def approved_plan_hash(text: str) -> tuple[str, str | None] | None:
    """SDLC-D-049 point 3: the Plan hash the approval record quotes, as (head, tail); tail is None
    for a full or prefix-only value. The last one in the record wins, because a re-approved plan
    appends its new hash to the same record. None when the record names no Plan hash (briefs
    approved through the earlier package question), which leaves the header field as the only
    check."""
    stripped = FENCE.sub("", text)
    start = AUTHORIZED_SCOPE.search(stripped)
    if start is None:
        return None
    body_start = start.end()
    next_line = stripped.find("\n", body_start)
    end = len(stripped)
    if next_line != -1:
        record_end = RECORD_END.search(stripped, next_line + 1)
        if record_end is not None:
            end = record_end.start()
    matches = list(APPROVED_PLAN_HASH.finditer(stripped[body_start:end]))
    if not matches:
        return None
    last = matches[-1]
    tail = last.group("tail")
    return last.group("head").lower(), tail.lower() if tail else None


def check_approved_plan_hash(text: str, computed: str) -> list[str]:
    """SDLC-D-013 with SDLC-D-049 point 3: the approval binds to the content it approved, so the hash the
    approval record quotes must still match the plan's sections."""
    approved = approved_plan_hash(text)
    if approved is None:
        return []
    head, tail = approved
    if computed.startswith(head) and (tail is None or computed.endswith(tail)):
        return []
    shown = f"{head}…{tail}" if tail else head
    return [
        f"Plan hash mismatch: the approval record names {shown!r}, computed {computed!r} - "
        "a changed plan needs a new approval (SDLC-D-013, SDLC-D-049)"
    ]


def check_review_sha(text: str) -> list[str]:
    """SDLC-D-013: each review verdict records the commit SHA it reviewed. Pilot-minimum package
    (tasks/ios-sdlc-review.md, pilot deviations): the staleness diff (a later commit
    re-touching a file the reviewed range covered) is deferred - it marks earlier cards and
    pre-repair rounds as stale in any multi-card round - so only the field-presence check remains;
    `Review SHA` stays required."""
    problems = []
    for block in _heading_blocks(text, ROUND_REVIEW_HEADING):
        heading = block.splitlines()[0].strip().lstrip("#").strip()
        label = heading[:70]
        sha_match = re.search(r"^Review SHA:[ \t]*(\S*)", block, re.MULTILINE)
        sha = sha_match.group(1) if sha_match else ""
        if not sha_match or PLACEHOLDER.match(sha):
            problems.append(f"review {label!r}: missing Review SHA")
    return problems


def check_writer_steps_done(text: str, state: str | None) -> list[str]:
    """SDLC-D-042 point 3, first clause: once every Writer steps item is ticked, State must be
    done - a brief that finished all its steps but never flipped State is exactly the drift this
    closes. A section with no items at all (nothing ticked yet) is not "every step ticked", so it
    is not flagged."""
    problems = []
    for section in WRITER_STEPS.findall(text):
        if TICKED.search(section) and not UNTICKED.search(section) and state != "done":
            problems.append(f"Writer steps are all ticked but State is {state!r}, expected done (SDLC-D-042)")
    return problems


def check_cards(text: str) -> list[str]:
    """SDLC-D-016: every card in a round plan carries the model routed to its writer, so spend is
    routed deterministically at planning time instead of inherited from the parent session.
    Pilot-minimum package: `effort` is optional - a subagent dispatch takes a per-invocation
    `model` but no per-invocation effort (only a subagent definition's own frontmatter sets one,
    code.claude.com/docs/en/sub-agents.md, 'Choose a model'), so nothing yet applies a card's
    `effort` to its writer. When `effort` is given it must still be a real level."""
    problems = []
    for block in _heading_blocks(text, CARD_HEADING):
        heading = block.splitlines()[0].strip().lstrip("#").strip()
        label = heading[:70]
        model_match = re.search(r"^model:[ \t]*(.*)$", block, re.MULTILINE)
        if not model_match or PLACEHOLDER.match(model_match.group(1)):
            problems.append(f"card {label!r}: missing model")
        effort_match = re.search(r"^effort:[ \t]*(.*)$", block, re.MULTILINE)
        effort = effort_match.group(1).strip() if effort_match else ""
        if effort and effort not in EFFORT_LEVELS:
            problems.append(f"card {label!r}: effort must be one of {'|'.join(EFFORT_LEVELS)}, found: {effort!r}")
    return problems


def check_card_req_ids(text: str) -> list[str]:
    """SDLC-D-014 point 1: spec_trace.py's cmd_matrix collects cited requirement ids only from
    '#### Card:' blocks, so a range or ellipsis shorthand id there never reaches the round's
    coverage matrix - every REQ id in a card block must be written out in full."""
    problems = []
    for block in _heading_blocks(text, CARD_HEADING):
        heading = block.splitlines()[0].strip().lstrip("#").strip()
        label = heading[:70]
        for match in REQ_SHORTHAND.finditer(block):
            problems.append(
                f"card {label!r}: REQ id written as a range or shorthand, not in full: {match.group().strip()!r}"
            )
    return problems


def check_card_analytics(text: str) -> list[str]:
    """SDLC-D-025 point 1: a round card names a product question, a metric and a threshold, like a
    test - called by the caller only for Profile: round (fast and fix are exempt per the decision).
    Pilot-minimum package: a card marked `user-visible: none` (or another placeholder - no
    user-facing change) may answer `n/a — <reason>` instead; a user-visible card may not, since the
    instrumentation a real answer implies is exactly what a user-facing change needs."""
    problems = []
    for block in _heading_blocks(text, CARD_HEADING):
        heading = block.splitlines()[0].strip().lstrip("#").strip()
        label = heading[:70]
        visible_match = re.search(r"^user-visible:[ \t]*(.*)$", block, re.MULTILINE)
        non_visible = visible_match is not None and PLACEHOLDER.match(visible_match.group(1).strip())
        for field in CARD_ANALYTICS_FIELDS:
            match = re.search(rf"^{re.escape(field)}:[ \t]*(.*)$", block, re.MULTILINE)
            value = match.group(1).strip() if match else ""
            if not match or PLACEHOLDER.match(value):
                problems.append(f"card {label!r}: missing {field} (SDLC-D-025)")
                continue
            na_match = N_A_PREFIX.match(value)
            if not na_match:
                continue
            reason = N_A_SEPARATOR.sub("", value[na_match.end() :]).strip()
            if not reason:
                problems.append(f"card {label!r}: {field} 'n/a' needs a reason (SDLC-D-025)")
            elif not non_visible:
                problems.append(f"card {label!r}: {field} cannot be 'n/a' - the card is user-visible (SDLC-D-025)")
    return problems


def check_card_user_visible(text: str) -> tuple[list[str], bool]:
    """SDLC-D-026 point 1: a round card declares whether its change is user-visible, the same way
    SDLC-D-025's product question/metric/threshold are declared on every card - but unlike those,
    the field's own value may legitimately be a placeholder ('none': this card has no user-facing
    change), so only its absence is a problem. Returns (problems, any_visible): any_visible is
    True once any card in this brief is marked user-visible with a real (non-placeholder) value,
    which is what the caller uses to decide whether CHANGELOG.md needs an [unreleased] line."""
    problems = []
    any_visible = False
    for block in _heading_blocks(text, CARD_HEADING):
        heading = block.splitlines()[0].strip().lstrip("#").strip()
        label = heading[:70]
        match = re.search(r"^user-visible:[ \t]*(.*)$", block, re.MULTILINE)
        if match is None:
            problems.append(f"card {label!r}: missing user-visible (SDLC-D-026)")
            continue
        if not PLACEHOLDER.match(match.group(1)):
            any_visible = True
    return problems, any_visible


def check_unreleased_line(root: Path) -> list[str]:
    """SDLC-D-026 point 2 and the fix-profile amendment: a closed round card, or a closed fix
    brief, marked user-visible needs a non-empty `[unreleased]` line in CHANGELOG.md. A missing
    file is itself reported here: a real user-visible change just closed with nothing to show for
    it."""
    path = root / "CHANGELOG.md"
    if not path.is_file():
        return ["CHANGELOG.md is missing but a user-visible change just closed (SDLC-D-026)"]
    text = path.read_text(encoding="utf-8")
    for block in _heading_blocks(text, CHANGELOG_UNRELEASED_HEADING):
        body = block[block.find("\n") + 1 :] if "\n" in block else ""
        if any(line.strip().startswith(("-", "*")) for line in body.splitlines()):
            return []
    return ["CHANGELOG.md has no [unreleased] line but a user-visible change just closed (SDLC-D-026)"]


# SDLC-D-014's own Enforcement line: "a round closes only without GAP." spec_trace.py's cmd_matrix
# (a different writer's script) splices the generated coverage matrix between these markers; a row
# there counts a requirement GAP when its Status cell reads exactly "GAP". Deferred rows are
# spec_trace.py's exclusive concern (SDLC-D-014 pilot deviation) - this reads only its output, never
# the brief's own "## Deferred" input table.
MATRIX_BEGIN = "<!-- spec_trace:matrix:begin -->"
MATRIX_END = "<!-- spec_trace:matrix:end -->"
MATRIX_GAP_ROW = re.compile(r"^\|[^|\n]*\|[ \t]*GAP[ \t]*\|", re.MULTILINE)


def check_matrix_closed(text: str) -> list[str]:
    """SDLC-D-014's close gate for `Profile: round`, `State: done`: the generated coverage matrix
    block must exist and contain no GAP row."""
    start = text.find(MATRIX_BEGIN)
    end = text.find(MATRIX_END)
    if start == -1 or end == -1 or end < start:
        return ["Profile round State done requires the generated coverage matrix block (SDLC-D-014)"]
    if MATRIX_GAP_ROW.search(text[start + len(MATRIX_BEGIN) : end]):
        return ["Profile round State done: the coverage matrix has a GAP row (SDLC-D-014)"]
    return []


def _round_reviews_by_card(text: str) -> dict[str, list[tuple[int, str, str]]]:
    """Every "### Round N review" block (round number, heading label, block body), grouped by the
    card its heading names, falling back to the nearest preceding "#### Card:" heading in document
    order only when no card's slug appears in it. Repair round 1, medium 2: two cards each starting
    their own "Round 1", or a "Round 2" placed before "Round 1" in the text, must not
    cross-contaminate each other's repair count, so counting goes by round NUMBER within its own
    card's group, never by physical order across the whole document. Repair round 1, medium 2
    (second pass): "nearest preceding card" alone has no upper bound - reviews kept together in a
    trailing section (e.g. under a later "## Reviews" heading, after every card) all land on
    whichever card happens to be last, inflating its repair count for rounds that never touched it.
    A review named after its card's slug (SDLC-D-021's "<slice>" label) is matched to that card by
    name wherever it sits in the document; only a review whose slice label does not name any card
    (the interleaved case, where the slice label is often shared prose like "widget") falls back to
    positional nearest-preceding. Repair round 2, medium 1: the slice label is read out with
    ROUND_REVIEW_SLICE and compared to each card's slug by exact equality, not by a `\\b`-bounded
    substring search - a card whose slug is a hyphen-prefix of another's (e.g. "onboarding" inside
    "onboarding-copy") or of a word in unrelated review prose must never absorb that other
    review's findings."""
    card_positions = [(m.start(), m.group(2).strip()) for m in CARD_HEADING.finditer(text)]
    card_slugs = [(label, label.split("—", 1)[0].strip()) for _pos, label in card_positions]
    by_card: dict[str, list[tuple[int, str, str]]] = {}
    for match in ROUND_REVIEW_HEADING.finditer(text):
        level = len(match.group(1))
        end = len(text)
        for nxt in re.finditer(r"^(#{1,6})[ \t]+", text[match.end() :], re.MULTILINE):
            if len(nxt.group(1)) <= level:
                end = match.end() + nxt.start()
                break
        block = text[match.start() : end]
        heading = block.splitlines()[0].strip().lstrip("#").strip()
        slice_match = ROUND_REVIEW_SLICE.search(heading)
        review_slice = slice_match.group("slice").strip() if slice_match else None
        slug_match = next(
            (label for label, slug in card_slugs if slug and review_slice is not None and slug == review_slice),
            None,
        )
        if slug_match is not None:
            card = slug_match
        else:
            card = "(no card)"
            for pos, label in card_positions:
                if pos <= match.start():
                    card = label
                else:
                    break
        number_match = ROUND_NUMBER.search(heading)
        number = int(number_match.group(1)) if number_match else 0
        by_card.setdefault(card, []).append((number, heading[:70], block))
    for entries in by_card.values():
        entries.sort(key=lambda item: item[0])
    return by_card


def check_review_findings(text: str) -> tuple[list[str], int]:
    """SDLC-D-021/SDLC-D-022: every finding tags level, blocking mark and new/recurring (the
    reviewer's own declaration, SDLC-D-022 point 1), and a high or medium finding needs a concrete
    failure scenario. Pilot-minimum package (tasks/ios-sdlc-review.md, pilot deviations):
    cross-round pairing - checking a "new" tag against the previous round's findings by file and
    description text - is dropped, because exact-text pairing misflagged real recurrences;
    recurrence is judged by the reviewer against the rule text instead. Returns (problems,
    repair count): the repair count is the highest count reached by any single card, since
    SDLC-D-022 point 2's budget of three repairs is per card, while the Repair extension approval
    field the caller checks it against lives once at brief level."""
    problems: list[str] = []
    max_repairs = 0
    for entries in _round_reviews_by_card(text).values():
        for _number, label, block in entries:
            for item in TOP_LEVEL_ITEM.findall(block):
                if item.strip() == NO_FINDINGS:
                    continue
                match = FINDING.match("- " + item)
                if not match:
                    problems.append(
                        f"review {label!r}: finding missing required tags "
                        f"(level/blocking/new-or-recurring): {item.strip()[:60]}"
                    )
                    continue
                level, loc = match.group("level"), match.group("loc")
                desc = match.group("desc").strip()
                if level in ("high", "medium") and PLACEHOLDER.match(desc):
                    problems.append(f"review {label!r}: a {level} finding needs a concrete failure scenario: {loc}")
        max_repairs = max(max_repairs, len(entries) - 1, 0)
    return problems, max_repairs


def lint(
    path: Path,
    slugs: set[str],
    *,
    root: Path | None = None,
) -> tuple[dict[str, str], list[str]]:
    root = root if root is not None else path.parent
    text = path.read_text(encoding="utf-8")
    fields: dict[str, str] = {}
    for name, value in FIELD.findall(_header_block(text)):
        fields.setdefault(name, value.strip())
    problems = []
    state = fields.get("State")
    if state is None:
        problems.append("missing State")
    elif state not in STATES:
        problems.append(f"State must be one of {'|'.join(STATES)}, found: {state!r}")
    if "Assignee" not in fields:
        problems.append("missing Assignee")
    if state == "done" and PLACEHOLDER.match(fields.get("Evidence", "")):
        problems.append("State done requires Evidence")
    parallelism = fields.get("Parallelism")
    if parallelism is not None and not PARALLELISM.match(parallelism):
        problems.append(f"Parallelism must be 'none' or 'up to N', found: {parallelism!r}")
    for dependency in filter(None, re.split(r"[,\s]+", fields.get("Depends-on", ""))):
        if dependency != "none" and dependency not in slugs:
            problems.append(f"Depends-on names no brief: {dependency}")
    # Pilot-minimum package (2026-09-24): a brief opts into every check below by carrying a
    # `Profile:` line, replacing the separate `Schema: 2` opt-in - one field instead of two, and
    # `profile` is always present here (never None) because that is exactly the gate.
    if "Profile" in fields:
        problems.extend(check_dispatch_records(text))
        problems.extend(check_writer_steps_done(text, state))
        profile = fields["Profile"]
        if profile not in PROFILES:
            problems.append(f"Profile must be one of {'|'.join(PROFILES)}, found: {profile!r}")
        else:
            if state == "done":
                evidence = fields.get("Evidence", "").lower()
                for group in PROFILE_EVIDENCE_HINTS.get(profile, ()):
                    if not any(hint in evidence for hint in group):
                        problems.append(
                            f"Profile {profile}: Evidence lacks {'/'.join(group)} evidence required for this profile"
                        )
            if profile == "fix":
                # SDLC-D-026 fix-profile amendment: fix has a brief but no plan or cards, so the
                # single user-visible field lives at brief level instead of per-card.
                user_visible = fields.get("user-visible")
                if user_visible is None:
                    problems.append("Profile fix requires user-visible (SDLC-D-026)")
                elif state == "done" and not PLACEHOLDER.match(user_visible):
                    problems.extend(check_unreleased_line(root))
            if profile == "round":
                problems.extend(check_plan_hash_sections(text, list(DEFAULT_PLAN_HASH_HEADINGS)))
                computed = compute_plan_hash(text, list(DEFAULT_PLAN_HASH_HEADINGS))
                plan_hash = fields.get("Plan hash")
                if plan_hash is None or PLACEHOLDER.match(plan_hash):
                    problems.append("Profile round requires Plan hash")
                elif plan_hash.strip().lower() != computed:
                    problems.append(f"Plan hash mismatch: recorded {plan_hash.strip()!r}, computed {computed!r}")
                problems.extend(check_approved_plan_hash(text, computed))
                problems.extend(check_card_analytics(text))
                visible_problems, any_visible = check_card_user_visible(text)
                problems.extend(visible_problems)
                if state == "done" and any_visible:
                    problems.extend(check_unreleased_line(root))
                if state == "done":
                    problems.extend(check_matrix_closed(text))
        problems.extend(check_review_sha(text))
        problems.extend(check_cards(text))
        problems.extend(check_card_req_ids(text))
        finding_problems, repairs = check_review_findings(text)
        problems.extend(finding_problems)
        if repairs > REPAIR_BUDGET and PLACEHOLDER.match(fields.get("Repair extension approval", "")):
            problems.append(
                f"{repairs} repair rounds exceed the budget of {REPAIR_BUDGET}: "
                "Repair extension approval is required"
            )
        outage = fields.get("Outage")
        if outage is not None and not PLACEHOLDER.match(outage):
            if PLACEHOLDER.match(fields.get("Scope audit", "")):
                problems.append("Outage recorded but missing a Scope audit line")
    ticked_by: dict[str, str] = {}
    for section in WRITER_STEPS.findall(text):
        for step in TICKED.findall(section):
            sha = SHA.search(step)
            if not sha:
                problems.append(f"Writer steps: ticked step without a commit SHA: {step.strip()[:60]}")
            elif sha.group() in ticked_by:
                # One task, one commit: a shared SHA means two steps were bundled into one change.
                problems.append(f"Writer steps: SHA {sha.group()} ticks more than one step: {step.strip()[:60]}")
            else:
                ticked_by[sha.group()] = step
    return fields, problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--tasks", type=Path, default=Path("docs/tasks"))
    parser.add_argument("--board", action="store_true", help="print briefs grouped by State")
    parser.add_argument("--strict", action="store_true", help="exit 1 when any brief has a problem")
    parser.add_argument(
        "--compute-plan-hash",
        type=Path,
        metavar="BRIEF",
        help="print the sha256 Plan hash for one brief's normative sections and exit (SDLC-D-013)",
    )
    args = parser.parse_args()

    if args.compute_plan_hash is not None:
        print(
            compute_plan_hash(
                args.compute_plan_hash.read_text(encoding="utf-8"), list(DEFAULT_PLAN_HASH_HEADINGS)
            )
        )
        return 0

    tasks = args.tasks if args.tasks.is_absolute() else args.root / args.tasks
    if not tasks.is_dir():
        print(f"no task directory: {tasks}", file=sys.stderr)
        return 2
    briefs = sorted(p for p in tasks.rglob("*.md") if p.name not in {"template.md", "README.md"})
    slugs = {p.stem for p in briefs}
    board: dict[str, list[str]] = {}
    failed = 0
    for brief in briefs:
        fields, problems = lint(
            brief,
            slugs,
            root=args.root,
        )
        board.setdefault(fields.get("State", "?"), []).append(f"{brief.stem} ({fields.get('Assignee', '?')})")
        for problem in problems:
            failed += 1
            print(f"{brief.relative_to(args.root)}: {problem}")
    if args.board:
        for state in (*STATES, *sorted(set(board) - set(STATES))):
            for entry in board.get(state, []):
                print(f"{state:8} {entry}")
    mode = "" if args.strict or not failed else "  (report mode: exit 0; --strict fails)"
    print(f"briefs: {len(briefs)}  problems: {failed}{mode}")
    return 1 if args.strict and failed else 0


if __name__ == "__main__":
    sys.exit(main())
