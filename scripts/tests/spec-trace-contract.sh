#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/spec-trace-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
cd "$REPO_ROOT"

# No kit: the skip must be loud, exit 0 by default, and fail when the caller requires the kit.
out="$(AGENTS_KIT_ROOT="$FIXTURE/missing" ./scripts/spec-trace.sh 2>&1)" || fail 'a missing kit must not fail the default gate'
grep -q 'SKIPPED' <<<"$out" || fail 'a missing kit must be reported, not silent'
if AGENTS_KIT_ROOT="$FIXTURE/missing" TRACE_REQUIRE_KIT=1 ./scripts/spec-trace.sh >/dev/null 2>&1; then
  fail 'TRACE_REQUIRE_KIT=1 must fail without the kit'
fi

# Stub kit: record the arguments each tool receives and control the trace exit code.
tools="$FIXTURE/kit/skills/spec-pyramid/scripts"
mkdir -p "$tools"
printf 'import os,sys\nopen(os.environ["ARGS_LOG"],"a").write("trace "+" ".join(sys.argv[1:])+"\\n")\nsys.exit(int(os.environ.get("TRACE_EXIT","0")))\n' >"$tools/spec_trace.py"
printf 'import os,sys\nopen(os.environ["ARGS_LOG"],"a").write("briefs "+" ".join(sys.argv[1:])+"\\n")\nprint("briefs: 0  problems: 0")\n' >"$tools/brief_lint.py"
export AGENTS_KIT_ROOT="$FIXTURE/kit" ARGS_LOG="$FIXTURE/args.log"

./scripts/spec-trace.sh >/dev/null || fail 'a passing trace must exit 0'
grep -q -- '--approved-only --strict' "$ARGS_LOG" || fail 'the trace must be strict and count approved requirements only'
grep -q -- "--tests RegionalCheckTests/" "$ARGS_LOG" || fail 'the trace must be limited to tracked test globs'
grep -q '^briefs ' "$ARGS_LOG" || fail 'brief lint must run'
grep -q -- '--results' "$ARGS_LOG" && fail 'no --results unless asked'

./scripts/spec-trace.sh --results "$FIXTURE/x.xcresult" >/dev/null
grep -q -- "--results $FIXTURE/x.xcresult" "$ARGS_LOG" || fail '--results must reach the trace'

if TRACE_EXIT=1 ./scripts/spec-trace.sh >/dev/null 2>&1; then fail 'a failing trace must fail the command'; fi
# The gate order is part of the contract: a failed trace must stop verify before the Runtime records evidence.
awk '/^verify:/{f=1;next} f&&/^[^ ]/{f=0} f' justfile | head -1 | grep -q 'spec-trace.sh' || fail 'verify must run the trace before the Runtime gate'

echo "spec trace wiring contracts: passed"
