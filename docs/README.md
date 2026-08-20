# Documentation

This index defines the role of each document and prevents plans, historical release notes, and current contracts from becoming competing sources of truth.

## Current sources of truth

| Question | Source |
|---|---|
| What product are we building? | [Product charter](product-charter.md) |
| Which surfaces and Pro gates exist? | [Surfaces](surfaces.md) |
| How is the code structured? | [Architecture](architecture.md) |
| Why was the architecture chosen? | [ADR 0008](adr/0008-mvvm-service-boundaries.md) |
| How are regions represented? | [Region model](region-model.md) |
| How does refresh behave? | [Refresh policy](refresh-policy.md) |
| How do we test? | [Testing strategy](testing-strategy.md) |
| How do agents operate here? | [Agent pilot brief](agent-pilot-brief.md) and root `AGENTS.md` |
| How is the provider constrained? | [Aerial alerts provider](aerial-alerts-provider.md) |

## Supporting references

- [Analytics](analytics.md)
- [TestFlight readiness](testflight-readiness.md)
- [Subscription implementation reference](../README_Subscriptions.md)
- [Historical StoreKit implementation plan](storekit-subscription-plan.md)

## Architecture decisions

- [ADR 0002 — Canonical alert region](adr/0002-canonical-alert-region.md)
- [ADR 0003 — Region resolver](adr/0003-region-resolver.md)
- [ADR 0004 — Adaptive refresh policy](adr/0004-adaptive-refresh-policy.md)
- [ADR 0005 — Region tracker hysteresis](adr/0005-region-tracker-hysteresis.md)
- [ADR 0006 — Shared module and App Group](adr/0006-shared-module-and-app-group.md)
- [ADR 0007 — Surface matrix and Pro gating](adr/0007-surface-matrix-and-pro-gating.md)
- [ADR 0008 — MVVM and service boundaries](adr/0008-mvvm-service-boundaries.md)

## Historical release material

- [Release 2.0 checklist and App Store copy](release-2.0.md)

Historical documents describe a completed or superseded planning state. They are evidence and release history, not current implementation instructions.
