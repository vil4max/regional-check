# ADR 0008 — MVVM and service boundaries

Status: Accepted

## Context

Drive Check has grown from a small SwiftUI and CarPlay utility into an application with widgets, App Intents, Live Activity, StoreKit, location tracking, and shared App Group state. The current static `AppDependencies` composition root keeps live state consistent across phone and CarPlay, but views resolve global dependencies directly and several types combine presentation with application lifecycle responsibilities.

The project needs clearer boundaries before independent features are developed in parallel worktrees. The architecture must remain proportional to a small, single-team product.

## Decision

Adopt MVVM at feature boundaries with protocol-backed services where substitution is required and an instance-based `AppContainer` as the composition root.

```text
View → ViewModel → Store / Service protocol → live implementation
```

Long-lived state shared by multiple surfaces belongs to an application Store or Session. It must not be forced into a screen ViewModel merely to satisfy naming conventions.

### View

- Owns layout, bindings, and local presentation.
- Forwards user actions to its ViewModel.
- Does not resolve `AppDependencies` or access persistence and networking directly.

### ViewModel

- Is `@MainActor` when it drives UI state.
- Uses Observation for new SwiftUI features.
- Owns presentation state and feature actions.
- Receives substitutable dependencies through its initializer.

### Store or Session

- Owns long-lived application state shared across screens or surfaces.
- Coordinates state transitions that are not specific to one View.
- May expose a protocol when tests or multiple implementations require substitution.

### Service

- Encapsulates one external integration or side-effect boundary.
- Uses protocols for networking, persistence, StoreKit, location, or similar dependencies when substitution is required.

### AppContainer

- Is created once at the application boundary.
- Constructs and connects live dependencies.
- Is concrete; no container protocol is required.
- Supplies the same application stores to phone and CarPlay adapters.

## Naming

| Suffix | Meaning |
|---|---|
| `View` | SwiftUI presentation |
| `ViewModel` | State and actions for one feature presentation |
| `Store` / `Session` | Long-lived application state |
| `Service` | External integration or focused side-effect boundary |
| `Controller` | Imperative lifecycle coordination where that role is explicit |

Avoid `Manager` for new types unless no more specific role name describes the responsibility.

## Comments

Comments preserve non-obvious implementation context: intent, invariants, constraints, ownership, ordering, and trade-offs. They do not narrate obvious code. Comments are written in English and updated or removed with the implementation contract they describe.

## Alternatives considered

### Keep the static dependency bag

Rejected as the target because it hides dependencies from feature initializers, couples previews to live state, and makes isolated feature composition difficult.

### Add a Coordinator now

Rejected because current navigation is still expressible with SwiftUI tabs and sheets. Reconsider when deep links, independent navigation stacks, or multi-step flows make navigation a separate problem.

### Adopt Clean Architecture

Rejected at the current scale. The product does not yet have enough rich domain rules, independent module ownership, or competing data sources to justify Presentation, Domain, and Data layers with use cases for each operation.

### Adopt a third-party architecture framework

Rejected because the current problems can be solved with Swift, SwiftUI Observation, explicit dependency injection, and existing project protocols.

## Consequences

### Positive

- Dependencies become explicit and testable.
- Views become smaller and more predictable.
- Phone and CarPlay can share application state without sharing presentation state.
- Parallel feature work receives consistent boundaries.
- The project can add Coordinator or Clean layers later when concrete signals appear.

### Costs

- Existing global access must be removed incrementally.
- Some behavior needs characterization tests before structural moves.
- Transitional types may temporarily bridge static and instance-based composition.

## Migration constraints

- Preserve observable behavior at each step.
- Do not rewrite all features in one change.
- Do not introduce protocols for symmetry alone.
- Run focused tests after each structural step.
- Run `just verify` when the configured simulator runtime is available.
