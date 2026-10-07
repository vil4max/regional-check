# Documentation

Spec pyramid: each layer details the one above it. A change starts at the
highest affected layer; evidence from operations flows back up.

| Layer | Question | Source |
|---|---|---|
| L0 core | What product are we building, and what must never happen? | [core.md](core.md) |
| L1 requirements | How must regions, refresh, surfaces and the provider behave? | [requirements/](requirements/) |
| L1 decisions | Why was it built this way? | [decisions/](decisions/) |
| L2 specs | Which tests prove the requirements? | `RegionalCheckTests/` — name tests with `REQ-<AREA>-NNN` |
| Engineering | How is the code structured and tested? | [engineering/](engineering/) |
| Operations | Analytics, TestFlight, App Store copy, release history | [operations/](operations/) |
| Design | Mockup exports and design tokens | [design/](design/) |
| Planning | Backlog and historical plans (not requirements) | [planning/](planning/) |
| Lessons | Failures that changed a check or an upper layer | [lessons.md](lessons.md) |

## Requirements

- [Region model](requirements/region-model.md)
- [Refresh policy](requirements/refresh-policy.md)
- [Surfaces and Pro gating](requirements/surfaces-and-pro-gating.md)
- [Aerial alerts provider](requirements/aerial-alerts-provider.md)
- [Launch and cold start](requirements/launch-and-cold-start.md)
- [Fold glass on Home](requirements/fold-glass.md) (retired 2026-09-24, never shipped)

## Decisions

- [0002 — Canonical alert region](decisions/0002-canonical-alert-region.md)
- [0003 — Region resolver](decisions/0003-region-resolver.md)
- [0004 — Adaptive refresh policy](decisions/0004-adaptive-refresh-policy.md)
- [0005 — Region tracker hysteresis](decisions/0005-region-tracker-hysteresis.md)
- [0006 — Shared module and App Group](decisions/0006-shared-module-and-app-group.md)
- [0007 — Surface matrix and Pro gating](decisions/0007-surface-matrix-and-pro-gating.md)
- [0008 — MVVM and service boundaries](decisions/0008-mvvm-service-boundaries.md)
- [0009 — Remove the unused AI explanation runtime](decisions/0009-remove-unused-ai-explanation-runtime.md)
- [0013 — One build pipeline, gated by CI and requested by a tag](decisions/0013-one-build-pipeline-or-two.md)
- [0014 — Hide Pro for 3.0.x, keep the code](decisions/0014-hide-pro-for-3-0.md)
- [0015 — Two-tab phone IA: Status and Details](decisions/0015-two-tab-phone-ia.md)

## Engineering

- [Project map: roles, screens and data flow](engineering/project-map.md)
- [Architecture](engineering/architecture.md)
- [Architecture diagrams: system context, building blocks, status states, refresh and Live Activity](engineering/architecture-diagrams.md)
- [Testing strategy](engineering/testing-strategy.md)
- [Local artifact lifecycle](engineering/artifact-lifecycle.md)
- [Subscriptions and Live Activity](engineering/subscriptions-and-live-activity.md)

## Operations

- [Analytics](operations/analytics.md)
- [Release process](operations/release-process.md)
- [TestFlight readiness](operations/testflight-readiness.md)
- [App Store copy](operations/app-store-copy.md)
- [Releases](operations/releases/)

Historical release notes and plans describe a completed or superseded state.
They are evidence, not current implementation instructions.
