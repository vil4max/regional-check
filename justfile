# App-owned. Runtime recipes come from Tooling/.
import 'Tooling/justfile'

scenario name:
    just run-sim -- -ScreenshotPhase {{name}}

paywall:
    just run-sim -- -ShowPaywall

screenshots:
    ./scripts/capture-app-store-screenshots.sh

# Regenerates docs/engineering/coverage-pyramid.html (slow: 5 isolated test runs).
coverage-pyramid:
    ./scripts/coverage-pyramid.sh

# Lists landed task worktrees and branches; `--apply` removes them with their DerivedData.
prune-worktrees *args:
    ./scripts/prune-worktrees.sh {{args}}
