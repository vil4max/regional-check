# App-owned. Runtime recipes come from Tooling/.
# Duplicates are allowed only so the recipes below can wrap Runtime recipes.
set allow-duplicate-recipes

import 'Tooling/justfile'

# The trace runs first: it needs no build slot, and a failure must not leave fresh release evidence behind.
verify:
    ./scripts/spec-trace.sh
    ./Tooling/scripts/build-slot.sh run ./Tooling/scripts/verify.sh

# CI (Tooling/docs/ci.md): the same gate as verify, then the app's own work — the Snapshots
# plan and Sonar coverage for both runs (scripts/ci-extra.sh).
ci:
    ./scripts/spec-trace.sh
    ./Tooling/scripts/build-slot.sh run ./Tooling/scripts/ci.sh
    ./Tooling/scripts/build-slot.sh run ./scripts/ci-extra.sh

# Approved requirements must have specs; `--results <bundle.xcresult>` also requires them to have run and passed; `--briefs` lists task brief problems.
trace *args:
    ./scripts/spec-trace.sh {{args}}

scenario name:
    just run-sim -- -ScreenshotPhase {{name}}

screenshots:
    ./Tooling/scripts/build-slot.sh run ./scripts/capture-app-store-screenshots.sh

# Regenerates docs/engineering/coverage-pyramid.html (slow: 5 isolated test runs).
coverage-pyramid:
    ./Tooling/scripts/build-slot.sh run ./scripts/coverage-pyramid.sh

# Lists landed task worktrees and branches; `--apply [--only <branch>]` removes them with their DerivedData.
prune-worktrees *args:
    ./scripts/prune-worktrees.sh {{args}}

# Resolve/create evidence in the primary checkout from any linked worktree.
[positional-arguments]
artifacts *args:
    python3 ./scripts/project-artifacts.py "$@"
