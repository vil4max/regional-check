# AI Explanation Layer

## Goal

Add a user-facing explanation of the current regional status.

## Constraints

- Alert data remains the single source of truth.
- AI cannot decide alert state.
- AI cannot modify domain models.
- Existing networking flow remains unchanged.

## Acceptance Criteria

- User can request explanation.
- Explanation uses current snapshot data.
- Service is isolated behind protocol.
- Unit tests cover behavior.

## Failure Conditions

- AI changes business decisions.
- UI directly calls LLM.
- Domain layer depends on AI implementation.