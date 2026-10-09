#!/usr/bin/env python3
"""Report traceability between requirement IDs and executable specs, or normative prose without an ID."""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import re
import subprocess
import sys
from html.parser import HTMLParser
from pathlib import Path

# Area NEW is reserved: REQ-NEW marks a proposed requirement a writer found mid-round; only the
# integrator gives it a number, so it is never defined, covered or reported as unknown.
REQ_HEADING = re.compile(r"^#{2,4}\s+(?P<id>REQ-(?!NEW-)[A-Z][A-Z0-9]*-\d{3})\b")
# A requirement may also be a bold label that opens a sentence, list item or table cell.
INLINE_REQ = re.compile(r"\*\*(?P<id>REQ-(?!NEW-)[A-Z][A-Z0-9]*-\d{3})\b")
CORE_LINE = re.compile(r"^Core:\s*\S")
STATUS_LINE = re.compile(r"^Status:\s*(\S+)")
# XCTest method names cannot contain dashes, so an underscored area/number is accepted too.
TEST_REF = re.compile(
    r"(?<![A-Za-z0-9])REQ[-_](?!NEW[-_])(?P<area>[A-Z][A-Z0-9]*)[-_](?P<num>\d{3})(?![0-9])"
)
NEW_REQ = re.compile(r"(?<![A-Za-z0-9])REQ[-_]NEW(?![A-Za-z0-9])")
# Swift Testing: the display name carries the ID, the function name identifies the result node.
SWIFT_TEST_FUNC = re.compile(r'@Test\(\s*"([^"]*)"[^\n]*\)\s*(?:@\w+(?:\([^)]*\))?\s*)*func\s+(\w+)')
DEFAULT_TESTS = ("**/*Tests/**/*.swift", "**/*Tests*.swift", "**/tests/**/*", "**/*.test.*", "**/*_test.*")
# .claude holds nested task worktrees; their tests must not count as coverage for this checkout.
SKIP_PARTS = {".git", ".claude", "node_modules", ".build", "DerivedData", "Pods", "Tooling", "build"}

# Prose mode: words that make a sentence read as a rule. A keyword list is a heuristic, not a
# parser; the report is for a human to triage. Tuned on Pitstop's requirements and mockup
# (2026-09-23): "do not" added (imperative prohibitions, mostly real rules); "not only" and
# "-only" compounds dropped as noise; "should", "required" and "may" left out as mostly guidance.
NORMATIVE = re.compile(
    r"\b(shall|must|never|always|at most|at least|cannot|do not|(?<!not )(?<!-)only(?!-))\b", re.IGNORECASE
)
FENCE = re.compile(r"^\s*(```|~~~)")
MD_HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
# Requirement metadata lines are labels, not rules.
METADATA = re.compile(r"^\**(Status|Core|Source)\**:")
LIST_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
TABLE_RULE = re.compile(r"^\|?[\s:|-]*-[\s:|-]*\|?$")
SENTENCE_END = re.compile(r"(?<=[.!?])\s+(?=[\"'“(*_\[A-Z0-9])")
LEADING_ID = re.compile(r"^[*_\s]*REQ[-_](?:NEW(?![A-Za-z0-9])|[A-Z][A-Z0-9]*[-_]\d{3})")
HTML_BLOCK = {
    "address", "article", "aside", "blockquote", "br", "caption", "dd", "div", "dl", "dt", "figcaption",
    "figure", "footer", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr", "li", "main", "nav", "ol",
    "p", "pre", "section", "table", "tr", "ul",
}
HTML_SKIP = {"head", "script", "style", "svg", "template"}
HTML_VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}


def requirements(req_dir: Path) -> dict[str, dict]:
    found: dict[str, dict] = {}
    for doc in sorted(req_dir.rglob("*.md")):
        current = None
        in_doc: list[str] = []
        # Core: lines above the first requirement are the document's default. SDLC-D-042
        # point 4 scopes the file-level restriction to approval only ("requirement
        # approval is per requirement... never per file"): a file-level Status: value
        # other than approved (retired, proposed, inferred, ...) still cascades the
        # same way Core: does (round-1 repair, finding 11); Status: approved alone
        # stays ignored, since that specific value is what defeated the SDLC-D-003 lock.
        doc_core = False
        doc_status: str | None = None

        def define(req_id: str) -> None:
            if req_id in found:
                raise SystemExit(f"duplicate requirement ID {req_id} in {doc}")
            found[req_id] = {"file": str(doc), "core": False, "status": None}
            in_doc.append(req_id)

        for line in doc.read_text(encoding="utf-8").splitlines():
            heading = REQ_HEADING.match(line)
            if heading:
                current = heading.group("id")
                define(current)
                continue
            if line.startswith("#"):
                current = None
                continue
            if current and CORE_LINE.match(line):
                found[current]["core"] = True
            elif current and (status := STATUS_LINE.match(line)):
                found[current]["status"] = status.group(1)
            elif not in_doc and CORE_LINE.match(line):
                doc_core = True
            elif not in_doc and (doc_status_match := STATUS_LINE.match(line)):
                value = doc_status_match.group(1)
                if value == "approved":
                    # SDLC-D-042: a file-level Status: approved marker (above the first
                    # heading) is never a default for its requirements — that let a
                    # whole file be marked "approved" regardless of each entry's own
                    # text, defeating the SDLC-D-003 lock, which reads only
                    # per-requirement status.
                    print(
                        f"warning: file-level Status: marker ignored in {doc} "
                        "(SDLC-D-042: Status: is per requirement, not per file)",
                        file=sys.stderr,
                    )
                else:
                    doc_status = value
            if not current:
                # The first bold label defines the requirement; later mentions are references.
                for req_id in INLINE_REQ.findall(line):
                    if req_id not in found:
                        define(req_id)
        for req_id in in_doc:
            found[req_id]["core"] = found[req_id]["core"] or doc_core
            if found[req_id]["status"] is None:
                found[req_id]["status"] = doc_status
    return found


def req_ids(text: str) -> set[str]:
    return {f"REQ-{m.group('area')}-{m.group('num')}" for m in TEST_REF.finditer(text)}


def cites_requirement(text: str) -> bool:
    """A numbered ID or a REQ-NEW placeholder: either way the rule is recorded, not untraced prose."""
    return bool(req_ids(text) or NEW_REQ.search(text))


def spec_references(
    root: Path, patterns: list[str]
) -> tuple[dict[str, list[str]], dict[str, set[str]], list[str]]:
    refs: dict[str, list[str]] = {}
    functions: dict[str, set[str]] = {}
    proposed: list[str] = []
    seen: set[Path] = set()
    for pattern in patterns:
        for path in root.glob(pattern):
            if not path.is_file() or path in seen or SKIP_PARTS & set(path.relative_to(root).parts):
                continue
            seen.add(path)
            try:
                text = path.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue
            for req_id in req_ids(text):
                refs.setdefault(req_id, []).append(str(path.relative_to(root)))
            if NEW_REQ.search(text):
                proposed.append(str(path.relative_to(root)))
            for display_name, function in SWIFT_TEST_FUNC.findall(text):
                for req_id in req_ids(display_name):
                    functions.setdefault(function, set()).add(req_id)
    return refs, functions, proposed


def load_results(path: Path) -> dict:
    if path.suffix == ".xcresult":
        command = ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(path)]
        try:
            output = subprocess.run(command, check=True, capture_output=True, text=True).stdout
        except (OSError, subprocess.CalledProcessError) as error:
            raise SystemExit(f"cannot read test results from {path}: {error}")
    else:
        try:
            output = path.read_text(encoding="utf-8")
        except OSError as error:
            raise SystemExit(f"cannot read test results from {path}: {error}")
    try:
        return json.loads(output)
    except json.JSONDecodeError:
        # A bundle that xcodebuild is still writing yields no JSON; unreadable results must not look like "not run".
        raise SystemExit(f"test results from {path} are not valid JSON (is the bundle still being written?)")


def executed_outcomes(results: dict, functions: dict[str, set[str]]) -> dict[str, set[str]]:
    """Map each requirement ID to the outcomes of the executed test cases that cite it."""
    outcomes: dict[str, set[str]] = {}

    def visit(node: dict) -> None:
        if node.get("nodeType") == "Test Case":
            name, identifier = node.get("name", ""), node.get("nodeIdentifier", "")
            cited = req_ids(f"{name} {identifier}")
            if not cited:
                # Bare function names can repeat across suites, so use them only when the result carries no ID.
                function = identifier.rsplit("/", 1)[-1].split("(", 1)[0]
                cited = functions.get(function, set())
            for req_id in cited:
                outcomes.setdefault(req_id, set()).add(node.get("result", "unknown"))
        for child in node.get("children", []):
            visit(child)

    for node in results.get("testNodes", []):
        visit(node)
    return outcomes


def slug(title: str) -> str:
    """GitHub-style heading anchor, so a cited link such as `file.md#first-launch-state` works as given."""
    return re.sub(r"[^\w\- ]", "", title.strip().lower()).replace(" ", "-")


def markdown_blocks(text: str, fragment: str | None) -> tuple[list[tuple[int, str, str]], bool]:
    """Return (line, section, text) blocks and whether the fragment matched a heading."""
    blocks: list[tuple[int, str, str]] = []
    current: dict | None = None
    in_fence = False
    section = ""
    matched = fragment is None
    scope_level: int | None = None
    req_level: int | None = None

    def flush() -> None:
        nonlocal current
        if current:
            blocks.append((current["line"], current["section"], " ".join(current["parts"])))
        current = None

    def start(number: int, kind: str, part: str) -> None:
        nonlocal current
        flush()
        current = {"line": number, "section": section, "kind": kind, "parts": [part]}

    for number, line in enumerate(text.splitlines(), 1):
        if FENCE.match(line):
            flush()
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        heading = MD_HEADING.match(line)
        if heading:
            flush()
            level, title = len(heading.group(1)), heading.group(2)
            if scope_level is not None and level <= scope_level:
                scope_level = None
            if fragment is not None and scope_level is None and fragment.lower() in (slug(title), title.lower()):
                scope_level, matched = level, True
            if req_level is not None and level <= req_level:
                req_level = None
            # A requirement's own section (Given/When/Then) is the traced rule, not untraced prose.
            if req_level is None and cites_requirement(title):
                req_level = level
            section = title
            continue
        in_scope = fragment is None or scope_level is not None
        stripped = line.strip()
        if not in_scope or req_level is not None:
            flush()
            continue
        if not stripped or METADATA.match(stripped) or stripped.startswith("<!--"):
            flush()
        elif stripped.startswith("|"):
            flush()
            # A table row is one rule; an ID in any cell traces the whole row.
            if not TABLE_RULE.match(stripped) and not cites_requirement(stripped):
                start(number, "row", " | ".join(cell.strip() for cell in stripped.strip("|").split("|")))
        elif stripped.startswith(">"):
            start(number, "quote", stripped.lstrip("> ").strip())
        elif LIST_ITEM.match(line):
            start(number, "list", LIST_ITEM.sub("", line, count=1).strip())
        elif current and current["kind"] in ("para", "list"):
            current["parts"].append(stripped)
        else:
            start(number, "para", stripped)
    flush()
    return blocks, matched


class _HTMLText(HTMLParser):
    """Collect visible text blocks from an HTML mockup, optionally inside the element with a given id."""

    def __init__(self, fragment: str | None) -> None:
        super().__init__(convert_charrefs=True)
        self.fragment = fragment
        self.matched = fragment is None
        self.blocks: list[tuple[int, str, str]] = []
        self.stack: list[tuple[str, str | None]] = []
        self.skip_depth = 0
        self.scope_depth: int | None = None
        self.heading = False
        self.parts: list[str] = []
        self.line: int | None = None

    def section(self) -> str:
        return next((f"#{element_id}" for _, element_id in reversed(self.stack) if element_id), "")

    def flush(self) -> None:
        text = " ".join("".join(self.parts).split())
        if text and not self.heading:
            self.blocks.append((self.line or 0, self.section(), text))
        self.parts, self.line = [], None

    def _close_open(self, tag: str) -> None:
        """Tolerate an unclosed element: pop back to its nearest matching open tag, if
        any, decrementing skip_depth for every HTML_SKIP element it closes along the
        way. Shared by handle_endtag and the implied </head> close below."""
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                for closed, _ in self.stack[index:]:
                    if closed in HTML_SKIP:
                        self.skip_depth -= 1
                del self.stack[index:]
                break
        if self.scope_depth is not None and len(self.stack) <= self.scope_depth:
            self.flush()
            self.scope_depth = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        element_id = dict(attrs).get("id")
        if tag == "body":
            # HTML allows an omitted </head>: a <body> start tag implicitly ends an
            # open <head> (and whatever it left open), the same way a browser's
            # parser would. Without this, an unclosed <head> never decrements
            # skip_depth, so the whole body reads as still "inside head" and its
            # prose is silently dropped (d1-spec-trace-1, assessment.md §5).
            self._close_open("head")
        if tag in HTML_BLOCK:
            self.flush()
            self.heading = tag in {"h1", "h2", "h3", "h4", "h5", "h6"}
        elif tag in ("td", "th"):
            self.parts.append(" | ")
            self.line = self.line or self.getpos()[0]
        if tag in HTML_VOID:
            return
        if self.fragment is not None and self.scope_depth is None and element_id == self.fragment:
            self.scope_depth, self.matched = len(self.stack), True
        self.stack.append((tag, element_id))
        if tag in HTML_SKIP:
            self.skip_depth += 1

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in HTML_BLOCK:
            self.flush()

    def handle_endtag(self, tag: str) -> None:
        if tag in HTML_BLOCK:
            self.flush()
            self.heading = False
        # Tolerate unclosed elements: close back to the nearest matching open tag, if any.
        self._close_open(tag)

    def handle_data(self, data: str) -> None:
        in_scope = self.fragment is None or self.scope_depth is not None
        if self.skip_depth or not in_scope:
            return
        if self.line is None and data.strip():
            self.line = self.getpos()[0]
        self.parts.append(data)


def html_blocks(text: str, fragment: str | None) -> tuple[list[tuple[int, str, str]], bool]:
    parser = _HTMLText(fragment)
    parser.feed(text)
    parser.close()
    parser.flush()
    return parser.blocks, parser.matched


def untraced_prose(root: Path, specs: list[str]) -> list[dict]:
    """List normative sentences that cite no requirement ID in the given documents or sections."""
    findings: list[dict] = []
    for spec in specs:
        location, _, fragment = spec.partition("#")
        path = Path(location) if Path(location).is_absolute() else root / location
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as error:
            print(f"cannot read prose source {spec}: {error}", file=sys.stderr)
            raise SystemExit(2)
        extract = html_blocks if path.suffix.lower() in (".html", ".htm") else markdown_blocks
        blocks, matched = extract(text, fragment or None)
        if not matched:
            # A mistyped anchor would otherwise report nothing and look like fully traced prose.
            print(f"no section {fragment!r} in {location}", file=sys.stderr)
            raise SystemExit(2)
        name = str(path.relative_to(root)) if path.is_relative_to(root) else str(path)
        for line, section, block in blocks:
            # A block opened by a requirement label is that requirement; an HTML table row is one rule.
            if LEADING_ID.match(block) or (block.startswith("|") and cites_requirement(block)):
                continue
            for sentence in SENTENCE_END.split(block):
                keyword = NORMATIVE.search(sentence)
                # A question asks for a decision; it does not state a rule.
                if keyword and not cites_requirement(sentence) and not sentence.rstrip().endswith("?"):
                    findings.append(
                        {
                            "file": name,
                            "line": line,
                            "section": section,
                            "keyword": keyword.group(1).lower(),
                            "text": sentence.strip(),
                        }
                    )
    return findings


def prose_report(root: Path, specs: list[str], as_json: bool) -> list[dict]:
    findings = untraced_prose(root, specs)
    by_keyword: dict[str, int] = {}
    for finding in findings:
        by_keyword[finding["keyword"]] = by_keyword.get(finding["keyword"], 0) + 1
    if as_json:
        print(json.dumps({"prose_without_req": findings, "by_keyword": by_keyword}, indent=2))
        return findings
    counts = ", ".join(f"{keyword} {count}" for keyword, count in sorted(by_keyword.items()))
    print(f"prose without a REQ ID: {len(findings)} sentences in {len(specs)} sources" + (f" ({counts})" if counts else ""))
    for finding in findings:
        section = f" [{finding['section']}]" if finding["section"] else ""
        print(f"{finding['file']}:{finding['line']}{section} {finding['keyword']}: {finding['text']}")
    return findings


DEFAULT_LOCK_FILE = Path("docs/requirements/.spec-lock.json")


def normalize_normative_text(text: str) -> str:
    """Whitespace and punctuation normalised, case kept (SDLC-D-003.W2): a
    Given/When/Then block's trailing `\\` line-continuation markers collapse
    like any other whitespace, so the fingerprint moves only when the words do,
    not on a line-wrap or a comma."""
    text = text.replace("\\", " ")
    text = re.sub(r"[^\w\s]", " ", text, flags=re.UNICODE)
    return re.sub(r"\s+", " ", text).strip()


def normative_body_lines(doc_text: str, req_id: str) -> list[str] | None:
    """Raw non-blank, non-metadata lines between a heading-defined requirement's
    own heading and the next heading: its EARS sentence and Given/When/Then, the
    text the SDLC-D-003 lock fingerprints. None when req_id is not heading-defined
    in this document (see the bold-label fallback in `normative_text_for`).
    Fenced content (e.g. a ```gherkin block) is captured like any other body line,
    only exempted from heading detection: a `#` comment inside it must not read as
    the next heading and truncate the body early (P1-R0-2's bug class)."""
    capturing = False
    in_fence = False
    body: list[str] = []
    for line in doc_text.splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
        elif not in_fence:
            heading = MD_HEADING.match(line)
            if heading:
                if capturing:
                    break
                match = REQ_HEADING.match(line)
                if match and match.group("id") == req_id:
                    capturing = True
                continue
        if not capturing:
            continue
        stripped = line.strip()
        if stripped and not METADATA.match(stripped):
            body.append(stripped)
    return body if capturing else None


def normative_text_for(req_id: str, doc_path: Path) -> str:
    """Raw normative text for the lock fingerprint: a heading-defined requirement's
    EARS sentence and Given/When/Then body. Falls back to an inline bold-label
    requirement's own sentence, list item or table cell (its first, defining
    occurrence) for robustness, though SDLC-D-042 makes this fallback currently
    unreachable from `cmd_lock`: a bold label has no line of its own to carry a
    per-requirement Status:, so it can never read Status: approved and reach the
    lock at all."""
    text = doc_path.read_text(encoding="utf-8")
    body = normative_body_lines(text, req_id)
    # A heading-defined requirement with a genuinely empty body (an empty list) must
    # not fall through to the bold-label search below: that search would happily match
    # an unrelated mention of the same id elsewhere in the document, reporting stray
    # prose as this requirement's normative text (round-1 repair, finding 10). Only
    # None (not heading-defined at all) reaches the fallback.
    if body is not None:
        return "\n".join(body)
    blocks, _ = markdown_blocks(text, None)
    for _, _, block in blocks:
        if req_id in req_ids(block):
            return block
    return ""


def requirement_fingerprint(normalized_text: str) -> str:
    return hashlib.sha256(normalized_text.encode("utf-8")).hexdigest()


def load_lock(path: Path) -> dict:
    if not path.is_file():
        return {"version": 1, "requirements": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(f"lock file is not valid JSON ({path}): {error}")
    # A valid JSON document that is not an object (an array, a string, a number, null)
    # would otherwise crash on .setdefault below with an unrelated AttributeError,
    # instead of a clean message naming the actual problem (round-1 repair, finding 14).
    if not isinstance(data, dict):
        raise SystemExit(f"lock file is not a JSON object ({path}): got {type(data).__name__}")
    data.setdefault("requirements", {})
    data.setdefault("version", 1)
    return data


def write_lock(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def lock_path_for(args, root: Path) -> Path:
    path = args.lock_file if getattr(args, "lock_file", None) else root / DEFAULT_LOCK_FILE
    return path if path.is_absolute() else root / path


def cmd_lock(args) -> int:
    root = args.root.resolve()
    req_dir = args.requirements if args.requirements.is_absolute() else root / args.requirements
    if not req_dir.is_dir():
        print(f"no requirements directory: {req_dir}", file=sys.stderr)
        return 2
    reqs = requirements(req_dir)
    approved = {k: v for k, v in reqs.items() if v["status"] == "approved"}
    lock_path = lock_path_for(args, root)

    current: dict[str, dict] = {}
    for req_id, meta in approved.items():
        normalized = normalize_normative_text(normative_text_for(req_id, Path(meta["file"])))
        current[req_id] = {"normative_text": normalized, "fingerprint": requirement_fingerprint(normalized)}

    lock = load_lock(lock_path)
    stored = lock["requirements"]

    if args.write:
        # SDLC-D-001/SDLC-D-003: an approved requirement must carry EARS text; a heading
        # defined but never filled in (Status: approved with no body written yet) must
        # never be silently locked with an empty fingerprint (round-1 repair, finding
        # 10). Checked, and the write refused entirely, before anything is written.
        empty = sorted(req_id for req_id, entry in current.items() if not entry["normative_text"])
        if empty:
            print(
                f"lock write: FAILED, empty normative text for {', '.join(empty)} "
                "(an approved requirement needs its EARS sentence and Given/When/Then)",
                file=sys.stderr,
            )
            return 2
        new_requirements: dict[str, dict] = {}
        added, changed = [], []
        for req_id, entry in current.items():
            prior = stored.get(req_id)
            if prior is None:
                revision = 1
                added.append(req_id)
            elif prior.get("fingerprint") != entry["fingerprint"]:
                revision = prior.get("revision", 0) + 1
                changed.append(req_id)
            else:
                revision = prior.get("revision", 1)
            new_requirements[req_id] = {"revision": revision, "active": True, **entry}
        # SDLC-D-003 locks approved requirements; a requirement that leaves Status:
        # approved (reopened for editing, or any other reason it drops out of `current`)
        # is never deleted from the lock, only marked inactive. Dropping it would reset
        # a later re-approval's revision to 1 ("new"), losing the history `--check` needs
        # to catch a text change that slipped through the unapproved window without an
        # Owner-Approval trailer (round-1 repair, finding 3).
        for req_id, prior_entry in stored.items():
            if req_id not in new_requirements:
                new_requirements[req_id] = {**prior_entry, "active": False}
        lock["requirements"] = new_requirements
        write_lock(lock_path, lock)
        print(f"lock write: {len(current)} approved requirement(s) -> {lock_path}")
        if added:
            print("new: " + ", ".join(sorted(added)))
        if changed:
            print("revised: " + ", ".join(sorted(changed)))
        return 0

    # --check is read-only and report-only (SDLC-D-003.W2 pilot: lands without --range
    # or Owner-Approval trailer correlation; the owner re-approves a changed approved
    # requirement in chat, recorded in the brief, before the next lock --write).
    if not lock_path.is_file():
        # A missing lock file with at least one approved requirement means the lock was
        # never written for it: `mismatches` below would stay empty (nothing is `in
        # stored`, the empty default) and read as trivially clean, when nothing is
        # actually protected yet (round-1 repair, finding 6).
        if current:
            print(f"no lock file: {lock_path} (run lock --write)", file=sys.stderr)
            return 2
        print(f"no lock file: {lock_path} (no approved requirements to lock)", file=sys.stderr)
        return 0
    mismatches = sorted(
        req_id for req_id, entry in current.items()
        if req_id in stored and stored[req_id].get("fingerprint") != entry["fingerprint"]
    )
    # A locked entry that was still active (approved) as of the last lock --write but
    # is not approved now: the fingerprint comparison above only looks at requirements
    # that are still approved today, so a demote-and-edit (Status: approved -> proposed
    # with the text then changed, or the requirement removed outright) would otherwise
    # never surface at --check, even though the text protection it relied on is gone.
    demoted = sorted(
        req_id for req_id, entry in stored.items()
        if entry.get("active") and req_id not in current
    )
    if not mismatches and not demoted:
        print(f"lock check ({lock_path}): clean")
        return 0
    for req_id in mismatches:
        print(f"lock mismatch: {req_id}")
    for req_id in demoted:
        print(f"lock demoted: {req_id} (locked active, no longer approved)")
    if mismatches:
        print(f"lock check: {len(mismatches)} approved requirement(s) changed (report only)")
    if demoted:
        print(f"lock check: {len(demoted)} locked requirement(s) demoted since the lock (report only)")
    return 0


# SDLC-D-014.W1: the two markers delimit spec_trace.py's own generated block inside a
# brief's "## Coverage matrix" section, so a re-run replaces only what it wrote and a
# re-scan of the brief for cited ids does not pick up spec_trace.py's own last table.
MATRIX_BEGIN = "<!-- spec_trace:matrix:begin -->"
MATRIX_END = "<!-- spec_trace:matrix:end -->"
COVERAGE_HEADING = "## Coverage matrix"
DEFERRED_REASONS = {"device-only", "tool-blocked", "out-of-scope", "owner-decision"}
# SDLC-D-014 rule 1's exact column order (round-1 repair 74e29a7 rejected a reordered
# header in brief_lint.py; that check has no equivalent left now that brief_lint's
# Deferred table helpers are parked, so cmd_matrix enforces it here instead).
DEFERRED_HEADER = "| Requirement | Status | Reason | Backlog | Expiry |"
# SDLC-D-014 rule 2: the owner approves deferrals as one batch at round close. The
# approval journal (SDLC-D-011) that would prove it is parked, and so is the per-row
# Approval column a writer once invented; this one quoted line, under the table, is
# the pilot's substitute record (the AskUserQuestion answer, quoted verbatim).
DEFERRED_APPROVAL_LINE = re.compile(r"(?m)^Deferred approval:\s*\S")


def _strip_between(text: str, begin: str, end: str) -> str:
    if begin not in text:
        return text
    before, _, rest = text.partition(begin)
    _, _, after = rest.partition(end)
    return before + after


def parse_deferred_table(brief_text: str) -> tuple[dict[str, dict], bool]:
    """`## Deferred` table: Requirement | Status (Deferred|N/A) | Reason | Backlog |
    Expiry (SDLC-D-014 rules for Deferred; the backlog link is SDLC-D-004). Returns
    (entries, header_ok): header_ok is False when the section's first table row is
    not exactly DEFERRED_HEADER, so `cmd_matrix` can refuse to misread a reordered
    or renamed column instead of silently binding the wrong cell to Reason or
    Backlog."""
    entries: dict[str, dict] = {}
    in_section = False
    header_seen = False
    header_ok = True
    in_fence = False
    for line in brief_text.splitlines():
        # Same bug class as P1-R0-2 (cited_ids_in_cards): a `#` comment inside a
        # fenced block must not read as the heading that opens or closes the section.
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        heading = MD_HEADING.match(line)
        if heading:
            in_section = heading.group(2).strip().lower() == "deferred"
            continue
        stripped = line.strip()
        if not in_section or not stripped.startswith("|") or TABLE_RULE.match(stripped):
            continue
        if not header_seen:
            header_seen = True
            if stripped != DEFERRED_HEADER:
                header_ok = False
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if not cells:
            continue
        cited = req_ids(cells[0])
        if not cited:
            continue
        # A cell citing several ids binds the row to every one of them, not an
        # arbitrary single id picked from this set, whose iteration order depends on
        # PYTHONHASHSEED.
        entry = {
            "status": cells[1] if len(cells) > 1 else "",
            "reason": cells[2] if len(cells) > 2 else "",
            "backlog": cells[3] if len(cells) > 3 else "",
            "expiry": cells[4] if len(cells) > 4 else "",
        }
        for req_id in cited:
            entries[req_id] = entry
    return entries, header_ok


def cited_ids_in_cards(text: str) -> set[str]:
    """SDLC-D-014 point 1: 'every requirement the round's cards cite' — ids inside a
    '#### Card:' block only, not the status block, authorization quotes, review text
    or the Deferred table itself. Round-2 finding: req_ids() of the whole brief
    picked up ids from those other sections too, so an id quoted in passing (an
    authorization quote, a review comment) got a matrix row of its own though no
    card actually cited it. Fenced code inside a card is skipped, the same as
    markdown_blocks() does: unskipped, a `# comment` line in the fence would match
    MD_HEADING as a level-1 heading and end the card early, dropping every id cited
    after the fence (round-1 repair, finding P1-R0-2)."""
    cited: set[str] = set()
    in_card = False
    card_level = 0
    in_fence = False
    for line in text.splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        heading = MD_HEADING.match(line)
        if heading:
            level, title = len(heading.group(1)), heading.group(2)
            if title.strip().lower().startswith("card:"):
                in_card, card_level = True, level
                cited |= req_ids(title)
                continue
            if in_card:
                if level <= card_level:
                    in_card = False
                else:
                    cited |= req_ids(title)
            continue
        if in_card:
            cited |= req_ids(line)
    return cited


def cmd_matrix(args) -> int:
    root = args.root.resolve()
    req_dir = args.requirements if args.requirements.is_absolute() else root / args.requirements
    brief_path = args.brief if args.brief.is_absolute() else root / args.brief
    if not brief_path.is_file():
        print(f"no brief: {brief_path}", file=sys.stderr)
        return 2
    brief_text = brief_path.read_text(encoding="utf-8")
    # The splice below assumes at most one matched begin/end pair; more than one (or a
    # begin with no matching end, or vice versa) would otherwise silently swallow or
    # duplicate content instead of failing (round-1 repair, finding 14, low).
    begin_count, end_count = brief_text.count(MATRIX_BEGIN), brief_text.count(MATRIX_END)
    if begin_count > 1 or end_count > 1 or begin_count != end_count:
        print(
            f"cannot splice the coverage matrix into {brief_path}: found {begin_count} "
            f"begin marker(s) and {end_count} end marker(s), expected exactly one matched pair or neither",
            file=sys.stderr,
        )
        return 2
    authored = _strip_between(brief_text, MATRIX_BEGIN, MATRIX_END)
    cited = cited_ids_in_cards(authored)

    # Same guard as cmd_lock (round-1 repair, finding 14, low): a missing or mistyped
    # --requirements directory must fail clearly, not silently read as zero requirements.
    if not req_dir.is_dir():
        print(f"no requirements directory: {req_dir}", file=sys.stderr)
        return 2
    reqs = requirements(req_dir)
    refs, functions, proposed = spec_references(root, args.tests or list(DEFAULT_TESTS))
    outcomes = executed_outcomes(load_results(args.results), functions) if args.results else {}
    deferred_table, deferred_header_ok = parse_deferred_table(authored)
    if not deferred_header_ok:
        print(
            f"cannot read the ## Deferred table in {brief_path}: header must be exactly {DEFERRED_HEADER!r}",
            file=sys.stderr,
        )
        return 2
    # SDLC-D-014 rule 2: one batch approval for the whole table, quoted verbatim,
    # not a per-row column (see DEFERRED_APPROVAL_LINE above); read once, applied
    # to every row below.
    approval_count = len(DEFERRED_APPROVAL_LINE.findall(authored))
    today = datetime.date.today()

    rows: list[tuple[str, str, str]] = []
    blocking = False
    for req_id in sorted(cited):
        meta = reqs.get(req_id)
        if meta is None:
            status, detail = "GAP", "not defined in the requirements catalog"
        elif req_id not in refs:
            status, detail = "GAP", "no test cites this requirement"
        elif not args.results:
            status, detail = "GAP", "no --results given"
        elif "Failed" in outcomes.get(req_id, set()):
            status, detail = "GAP", "test failed"
        elif not ({"Passed", "Failed"} & outcomes.get(req_id, set())):
            status, detail = "GAP", "test did not run"
        else:
            status, detail = "OK", "passed"

        deferral = deferred_table.get(req_id)
        if status == "GAP" and deferral:
            reason = (deferral["reason"] or "").strip()
            backlog = (deferral["backlog"] or "").strip()
            expiry_text = (deferral["expiry"] or "").strip()
            expiry_date: datetime.date | None = None
            if expiry_text:
                try:
                    expiry_date = datetime.date.fromisoformat(expiry_text)
                except ValueError:
                    expiry_date = None
            # SDLC-D-014: a Deferred row is valid only with a reason from the closed
            # list, a backlog link, an ISO expiry, and exactly one 'Deferred
            # approval:' line for the whole table; an invalid row counts as GAP
            # (round-1 repair 74e29a7's header check plus SDLC-D-014 rules 1-2, now
            # enforced here since brief_lint's Deferred table checks are parked).
            problems = []
            # Case-insensitive (round-1 repair, finding 14, low): DEFERRED_REASONS
            # members are lowercase.
            if reason.lower() not in DEFERRED_REASONS:
                problems.append(f"reason not in {sorted(DEFERRED_REASONS)}")
            if not backlog:
                problems.append("no backlog link")
            if expiry_date is None:
                problems.append("expiry is not an ISO date")
            if approval_count != 1:
                problems.append(f"{approval_count} 'Deferred approval:' line(s) in the brief, need exactly 1")
            if problems:
                status, detail = "GAP", f"invalid Deferred row: {'; '.join(problems)}"
            elif deferral["status"].strip().lower() == "n/a":
                status, detail = "N/A", reason
            elif expiry_date < today:
                status, detail = "GAP", f"Deferred expired {expiry_text}"
            else:
                status, detail = "Deferred", f"{reason}, expires {expiry_text}"

        if status == "GAP":
            blocking = True
        rows.append((req_id, status, detail))

    unknown = {k: sorted(set(v)) for k, v in refs.items() if k not in reqs}
    if unknown:
        blocking = True
    new_ids = sorted(set(proposed))

    table_lines = ["| Requirement | Status | Detail |", "|---|---|---|"]
    table_lines += [f"| {req_id} | {status} | {detail} |" for req_id, status, detail in rows]
    block = MATRIX_BEGIN + "\n" + "\n".join(table_lines) + "\n" + MATRIX_END

    if MATRIX_BEGIN in brief_text and MATRIX_END in brief_text:
        before, _, rest = brief_text.partition(MATRIX_BEGIN)
        _, _, after = rest.partition(MATRIX_END)
        new_text = before + block + after
    elif COVERAGE_HEADING in brief_text:
        idx = brief_text.index(COVERAGE_HEADING) + len(COVERAGE_HEADING)
        new_text = brief_text[:idx] + "\n\n" + block + brief_text[idx:]
    else:
        new_text = brief_text.rstrip("\n") + f"\n\n{COVERAGE_HEADING}\n\n{block}\n"
    if new_text != brief_text:
        brief_path.write_text(new_text, encoding="utf-8")

    print("\n".join(table_lines))
    gap_count = sum(1 for _, status, _ in rows if status == "GAP")
    print(f"matrix: {len(rows)} requirement(s), {gap_count} GAP")
    # SDLC-D-014 rule 5: the 20% threshold is not enforced during the pilot; the share
    # is printed so the owner can calibrate it from real rounds (rule 5's own 20%
    # starting value).
    deferred_count = sum(1 for _, status, _ in rows if status == "Deferred")
    print(f"Deferred share: {deferred_count} of {len(rows)}")
    if not cited:
        print(f"warning: no requirement ids cited in {brief_path}", file=sys.stderr)
    # SDLC-D-020 point 1: an id cited by a test but absent from the catalog fails, here
    # unconditionally like every other round-close finding (unlike the flat report mode).
    for req_id, files in sorted(unknown.items()):
        print(f"unknown_in_specs: {req_id} ({', '.join(files)})")
    # SDLC-D-020 point 4: reported, not blocking — the integrator numbers it at round close.
    if new_ids:
        print("proposed_new (REQ-NEW still cited, must be numbered before round close): " + ", ".join(new_ids))
    return 1 if blocking else 0


def cmd_report(args) -> int:
    root = args.root.resolve()
    if args.prose:
        return 1 if prose_report(root, args.prose, args.json) and args.strict else 0
    req_dir = args.requirements if args.requirements.is_absolute() else root / args.requirements
    if not req_dir.is_dir():
        print(f"no requirements directory: {req_dir}", file=sys.stderr)
        return 2
    reqs = requirements(req_dir)
    refs, functions, proposed = spec_references(root, args.tests or list(DEFAULT_TESTS))
    for doc in sorted(req_dir.rglob("*.md")):
        if NEW_REQ.search(doc.read_text(encoding="utf-8")):
            proposed.append(str(doc.relative_to(root)) if doc.is_relative_to(root) else str(doc))
    # Retired requirements need no spec; inferred and proposed ones still report so gaps stay visible.
    active = {k: v for k, v in reqs.items() if v["status"] != "retired"}
    unapproved: list[str] = []
    if args.approved_only:
        # An unapproved requirement is an upper-layer owner decision, not a spec gap to close with tests.
        unapproved = sorted(k for k, v in active.items() if v["status"] != "approved")
        active = {k: v for k, v in active.items() if v["status"] == "approved"}
    report = {
        "requirements": len(active),
        "covered": sorted(k for k in active if k in refs),
        "uncovered": sorted(k for k in active if k not in refs),
        "unknown_in_specs": {k: sorted(set(v)) for k, v in sorted(refs.items()) if k not in reqs},
        "missing_core_link": sorted(k for k, v in active.items() if not v["core"]),
        # Files still citing REQ-NEW: the integrator's numbering batch, not a gap.
        "proposed_new": sorted(set(proposed)),
    }
    if args.approved_only:
        report["unapproved"] = unapproved
    if args.results:
        outcomes = executed_outcomes(load_results(args.results), functions)
        covered = report["covered"]
        # One failing test is enough to fail the requirement; only an executed pass proves it.
        report["failed"] = [k for k in covered if "Failed" in outcomes.get(k, set())]
        report["not_run"] = [k for k in covered if not {"Passed", "Failed"} & outcomes.get(k, set())]
        report["passed"] = [k for k in covered if k not in report["failed"] and k not in report["not_run"]]
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        total = report["requirements"]
        print(f"requirements: {total}  covered: {len(report['covered'])}  uncovered: {len(report['uncovered'])}")
        if args.results:
            print(f"passed: {len(report['passed'])}  failed: {len(report['failed'])}  not_run: {len(report['not_run'])}")
        for key in ("uncovered", "missing_core_link", "failed", "not_run", "unapproved", "proposed_new"):
            if report.get(key):
                print(f"{key}: " + ", ".join(report[key]))
        for req_id, files in report["unknown_in_specs"].items():
            print(f"unknown_in_specs: {req_id} ({', '.join(files)})")
    # An approved-only trace over zero approved requirements passes vacuously; say so instead of looking green.
    empty = args.approved_only and not active
    if empty:
        report["empty_approved_set"] = True
        print(
            f"warning: no approved requirements ({len(unapproved)} unapproved); this trace proves nothing",
            file=sys.stderr,
        )
    gaps = (
        empty
        or report["uncovered"]
        or report["unknown_in_specs"]
        or report["missing_core_link"]
        or report.get("failed")
        or report.get("not_run")
    )
    return 1 if args.strict and gaps else 0


def main() -> int:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--root", type=Path, default=Path("."))
    common.add_argument("--requirements", type=Path, default=Path("docs/requirements"))
    common.add_argument("--json", action="store_true")

    # SUPPRESS defaults: a subparser copies its whole sub-namespace onto the parent
    # unconditionally, so a real default here would silently overwrite a value already
    # set before the subcommand token whenever the option is omitted after it.
    common_sub = argparse.ArgumentParser(add_help=False)
    common_sub.add_argument("--root", type=Path, default=argparse.SUPPRESS)
    common_sub.add_argument("--requirements", type=Path, default=argparse.SUPPRESS)
    common_sub.add_argument("--json", action="store_true", default=argparse.SUPPRESS)

    parser = argparse.ArgumentParser(description=__doc__, parents=[common])
    parser.add_argument("--tests", action="append", help="glob relative to root; repeatable")
    parser.add_argument("--strict", action="store_true", help="exit 1 when any gap is found")
    parser.add_argument(
        "--approved-only",
        action="store_true",
        help="count only Status: approved requirements as gaps; list the rest as unapproved",
    )
    parser.add_argument(
        "--results",
        type=Path,
        help=".xcresult bundle or `xcresulttool get test-results tests` JSON; a covered requirement must have run and passed",
    )
    parser.add_argument(
        "--prose",
        action="append",
        metavar="PATH[#section]",
        help="report normative sentences without a REQ ID in a Markdown section (heading anchor or text) "
        "or an HTML mockup (element id); repeatable; replaces the test trace",
    )

    subparsers = parser.add_subparsers(dest="command")

    lock_parser = subparsers.add_parser(
        "lock", parents=[common_sub], help="SDLC-D-003.W2: fingerprint approved requirements' normative text"
    )
    lock_mode = lock_parser.add_mutually_exclusive_group(required=True)
    lock_mode.add_argument(
        "--write", action="store_true", help="record current fingerprints, giving a changed requirement a new revision"
    )
    lock_mode.add_argument(
        "--check",
        action="store_true",
        help="report an approved requirement whose normative text differs from the lock (SDLC-D-003.W2 "
        "pilot: report only, no --range or Owner-Approval trailer correlation)",
    )
    lock_parser.add_argument(
        "--lock-file", type=Path, default=None, help="default <root>/docs/requirements/.spec-lock.json"
    )
    lock_parser.set_defaults(func=cmd_lock)

    matrix_parser = subparsers.add_parser(
        "matrix", parents=[common_sub], help="SDLC-D-014.W1: a generated coverage matrix for a brief's cited requirements"
    )
    matrix_parser.add_argument("--brief", type=Path, required=True, help="docs/tasks/<slug>.md; must have a ## Coverage matrix section, or one is appended")
    # SUPPRESS default for the same reason as common_sub above: these two are also
    # declared on the top-level parser (so `--tests`/`--results` work before the
    # subcommand too), and must not re-default themselves away when omitted here.
    matrix_parser.add_argument("--tests", action="append", default=argparse.SUPPRESS, help="glob relative to root; repeatable")
    matrix_parser.add_argument(
        "--results",
        type=Path,
        default=argparse.SUPPRESS,
        help=".xcresult bundle or `xcresulttool get test-results tests` JSON; without it every cited "
        "requirement is GAP, since OK requires an executed, passing test",
    )
    matrix_parser.set_defaults(func=cmd_matrix)

    args = parser.parse_args()
    if getattr(args, "command", None):
        return args.func(args)
    return cmd_report(args)


if __name__ == "__main__":
    sys.exit(main())
