# Documentation

Spec pyramid: each layer details the one above it. Change starts at the
highest affected layer; evidence from operations flows back up.

| Layer | Question | Source |
|---|---|---|
| L0 core | What product are we building, and what must never happen? | [core.md](core.md) |
| L1 requirements | How must regions, refresh, surfaces, provider, and AI explanation behave? | [requirements/](requirements/) |
| L1 decisions | Why was it built this way? | [decisions/](decisions/) |
| L2 specs | Which tests prove the requirements? | `RegionalCheckTests/` — name tests with `REQ-<AREA>-NNN` |
| Engineering | How is the code structured and tested; how do agents work here? | [engineering/](engineering/) |
| Operations | Analytics, TestFlight, App Store copy, release history | [operations/](operations/) |
| Tasks | Agent task briefs | [tasks/](tasks/) |
| Design | Mockup exports for active design work | [design/](design/) |
| Planning | Backlogs and historical plans (not requirements) | [planning/](planning/) |
| Lessons | Failures that changed a check or an upper layer | [lessons.md](lessons.md) |

## Requirements

- [Region model](requirements/region-model.md)
- [Refresh policy](requirements/refresh-policy.md)
- [Surfaces and Pro gating](requirements/surfaces-and-pro-gating.md)
- [Aerial alerts provider](requirements/aerial-alerts-provider.md)
- [Launch and cold start](requirements/launch-and-cold-start.md) (proposed, RD-15B)

## Decisions

- [0002 — Canonical alert region](decisions/0002-canonical-alert-region.md)
- [0003 — Region resolver](decisions/0003-region-resolver.md)
- [0004 — Adaptive refresh policy](decisions/0004-adaptive-refresh-policy.md)
- [0005 — Region tracker hysteresis](decisions/0005-region-tracker-hysteresis.md)
- [0006 — Shared module and App Group](decisions/0006-shared-module-and-app-group.md)
- [0007 — Surface matrix and Pro gating](decisions/0007-surface-matrix-and-pro-gating.md)
- [0008 — MVVM and service boundaries](decisions/0008-mvvm-service-boundaries.md)
- [0009 — Remove the unused AI explanation runtime](decisions/0009-remove-unused-ai-explanation-runtime.md)
- [0010 — Gated TestFlight builds and tag-driven releases](decisions/0010-gated-testflight-and-tag-releases.md)
- [0011 — CarPlay alert map: two candidates, decided by a spike](decisions/0011-carplay-alert-map-candidates.md) (Proposed)

## Engineering

- [Architecture](engineering/architecture.md)
- [Testing strategy](engineering/testing-strategy.md)
- [Agent workflow](engineering/agent-workflow.md)
- [Subscriptions and Live Activity](engineering/subscriptions-and-live-activity.md)

## Operations

- [Analytics](operations/analytics.md)
- [Release process](operations/release-process.md)
- [TestFlight readiness](operations/testflight-readiness.md)
- [App Store copy](operations/app-store-copy.md)
- [Releases](operations/releases/)

Historical release notes and plans describe a completed or superseded state.
They are evidence, not current implementation instructions.
