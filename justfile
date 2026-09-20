# App-owned. Runtime recipes come from Tooling/.
# Duplicates are allowed only so the recipes below can wrap Runtime recipes.
set allow-duplicate-recipes

import 'Tooling/justfile'

# Xcode build and test recipes share BUILD_SLOTS (default 2) machine-wide slots across worktrees.
# The trace runs first: it needs no build slot, and a failure must not leave fresh release evidence behind.
verify:
    ./scripts/spec-trace.sh
    ./scripts/build-slot.sh run ./Tooling/scripts/verify.sh

build:
    ./scripts/build-slot.sh run ./Tooling/scripts/build.sh

test:
    ./scripts/build-slot.sh run ./Tooling/scripts/test.sh

run-sim *args:
    ./scripts/build-slot.sh run ./Tooling/scripts/run-sim.sh {{ args }}

# `just build-slot status`; `acquire <label> [minutes]` prints a token for `release <token>` (Xcode MCP work).
build-slot *args:
    ./scripts/build-slot.sh {{ args }}

# Approved requirements must have specs; `--results <bundle.xcresult>` also requires them to have run and passed; `--briefs` lists task brief problems.
trace *args:
    ./scripts/spec-trace.sh {{args}}

scenario name:
    just run-sim -- -ScreenshotPhase {{name}}

screenshots:
    ./scripts/build-slot.sh run ./scripts/capture-app-store-screenshots.sh

# Regenerates docs/engineering/coverage-pyramid.html (slow: 5 isolated test runs).
coverage-pyramid:
    ./scripts/build-slot.sh run ./scripts/coverage-pyramid.sh

# Checks a commit against the tf- tag rules and prints the tag command (default: HEAD).
tf-check *args:
    ./scripts/check-testflight-tag.sh {{args}}

# Lists landed task worktrees and branches; `--apply [--only <branch>]` removes them with their DerivedData.
prune-worktrees *args:
    ./scripts/prune-worktrees.sh {{args}}

# Resolve/create evidence in the primary checkout from any linked worktree.
[positional-arguments]
artifacts *args:
    python3 ./scripts/project-artifacts.py "$@"
