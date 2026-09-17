# App-owned. Runtime recipes come from Tooling/.
# Duplicates are allowed only so `verify` below can wrap the Runtime recipe.
set allow-duplicate-recipes

import 'Tooling/justfile'

# Wraps Runtime `verify` in a machine-wide slot (VERIFY_SLOTS, default 1) shared by all worktrees.
verify:
    ./scripts/verify-slot.sh ./Tooling/scripts/verify.sh

scenario name:
    just run-sim -- -ScreenshotPhase {{name}}

paywall:
    just run-sim -- -ShowPaywall

screenshots:
    ./scripts/capture-app-store-screenshots.sh

# Regenerates docs/engineering/coverage-pyramid.html (slow: 5 isolated test runs).
coverage-pyramid:
    ./scripts/coverage-pyramid.sh

# Lists landed task worktrees and branches; `--apply [--only <branch>]` removes them with their DerivedData.
prune-worktrees *args:
    ./scripts/prune-worktrees.sh {{args}}
