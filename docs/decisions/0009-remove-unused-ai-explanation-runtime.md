# ADR 0009 — Remove the unused AI explanation runtime and country summary

Status: Accepted

## Context

Two AI features stayed in the codebase after their UI was removed:

- **Agent Runtime v1** behind the `Explain status` action: an orchestrated agent loop (`StatusExplanationAgent`, read-only tools, scripted model client), a Foundation Models transport with a deterministic fallback, `StatusExplanationViewModel`, a 38-case eval corpus, and opt-in device validation tests. It was documented as "production-disabled"; `StatusExplanationView` was deleted in `51ef207`.
- **Country summary** (`CountrySummaryViewModel` with deterministic, Foundation Models, and fallback providers), superseded by the Status details summary (`a410906`, `ecbfe21`).

Periphery (`--exclude-tests`) and SwiftLint `unused_declaration` both reported these types as reachable only from tests: about 1,200 production lines and 1,700 test lines with no user-facing function. They inflated coverage denominators, slowed every build and test run, and implied capabilities the app does not ship.

## Decision

Delete both features, their tests, the eval corpus, and the requirement document `requirements/ai-status-explanation.md`.

Keep only what the shipped Status details feature uses, now in `RegionalCheck/AI/ExplanationRun.swift` and `RegionalCheck/Views/StatusExplanation.swift`: `ExplanationRunLimits`, `ExplanationRunError`, `ExplanationOutputValidator`, `ExplanationTransportNormalizer`, `ModelStatusSource`, `StatusExplanationInput`, and `ExplanationStatusContext`. `ExplanationTraceStore` and `CountrySituationAggregator` remain; the unused `CountrySituationAggregator.fallbackSummary` is removed because Status details builds its own headline in `StatusDetailsProvider`, with the same rule that zero coverage never claims an alert-free country.

## Rejected alternatives

- **Keep Agent Runtime v1 as a documented experiment.** Unshipped code still has to compile, pass lint, and be migrated with every Swift and Foundation Models change. The design and its lessons remain in git history (`169e1d4` onward) and in `docs/tasks/ai-explanation-layer.md`.
- **Hide it behind a feature flag.** A flag would keep the maintenance cost without a product owner or a plan to ship.
- **Exclude it from coverage only.** That fixes the metric, not the dead code.

## Consequences

- Reintroducing an explanation feature starts from the Status details pipeline, not from the removed agent loop.
- Device-level Foundation Models validation for the removed transport no longer exists; Status details keeps its own tests.
