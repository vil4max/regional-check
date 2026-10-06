#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/spec-trace-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
cd "$REPO_ROOT"

# Do not let the caller's trace checkout or CI environment affect these fixtures.
unset CI IOS_AGENTIC_SDLC_ROOT IOS_AGENT_PROFILE_ROOT IOS_AGENT_RUNTIME_ROOT GITHUB_STEP_SUMMARY

status=0
CI=true bash scripts/spec-trace.sh >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 0 ]] || fail "CI without a trace root must exit 0, got $status"
grep -q '^TRACE NOT CHECKED:' "$FIXTURE/stderr" || fail 'CI must report the unchecked trace on stderr'
[[ ! -s "$FIXTURE/stdout" ]] || fail 'an unchecked trace must not print a passing result'

printf 'Existing summary\n' >"$FIXTURE/summary"
CI=true GITHUB_STEP_SUMMARY="$FIXTURE/summary" bash scripts/spec-trace.sh >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'CI with a step summary must exit 0'
{ printf 'Existing summary\n'; cat "$FIXTURE/stderr"; } >"$FIXTURE/expected-summary"
cmp -s "$FIXTURE/expected-summary" "$FIXTURE/summary" || fail 'CI must append the stderr warning to the step summary'

status=0
bash scripts/spec-trace.sh >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 2 ]] || fail "a local run without a trace root must exit 2, got $status"
grep -q '^Set IOS_AGENTIC_SDLC_ROOT to the absolute path of the requirement-trace tools checkout$' "$FIXTURE/stderr" || fail 'the local missing-root message must be preserved'

tools="$FIXTURE/sdlc/tools/spec"
mkdir -p "$tools"
printf 'import os,sys\nopen(os.environ["ARGS_LOG"],"a").write("trace "+" ".join(sys.argv[1:])+"\\n")\n' >"$tools/spec_trace.py"
printf 'import os,sys\nopen(os.environ["ARGS_LOG"],"a").write("briefs "+" ".join(sys.argv[1:])+"\\n")\nprint("briefs: 0  problems: 0")\n' >"$tools/brief_lint.py"
export ARGS_LOG="$FIXTURE/args.log"

CI=true IOS_AGENTIC_SDLC_ROOT="$FIXTURE/sdlc" bash scripts/spec-trace.sh >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'a configured trace must exit 0 in CI'
grep -q '^trace ' "$ARGS_LOG" || fail 'the trace tool must run'
grep -q '^briefs ' "$ARGS_LOG" || fail 'brief lint must run'

mkdir -p "$FIXTURE/incomplete/tools/spec"
cp "$tools/spec_trace.py" "$FIXTURE/incomplete/tools/spec/spec_trace.py"
status=0
CI=true IOS_AGENTIC_SDLC_ROOT="$FIXTURE/incomplete" bash scripts/spec-trace.sh >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 2 ]] || fail "a configured root missing a tool must exit 2 even in CI, got $status"
grep -Fxq "Missing requirement-trace tool: $FIXTURE/incomplete/tools/spec/brief_lint.py" "$FIXTURE/stderr" || fail 'the missing-tool message must be preserved'

echo "spec trace wiring contracts: passed"
