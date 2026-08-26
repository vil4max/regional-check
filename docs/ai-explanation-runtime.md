# AI Status Explanation Runtime

Engineering notes for the bounded agentic workflow behind the `Explain status` action. Product boundaries stay authoritative in [product-charter.md](product-charter.md); this document describes the runtime added in runtime v1 and its validation gates.

## Problem

A single "send prompt to LLM" call cannot satisfy the learning objective or the production invariants: it has no context discipline, no tool boundary, no termination guarantee, no observability, and no evaluation story. The explanation feature is therefore implemented as a small agent runtime with explicit deterministic edges.

## Invariants

- `StatusController` and the alert domain remain the only source of alert truth. The model describes state; it never computes it.
- The dependency direction is fixed:

```text
AlertsSnapshot → StatusController → StatusExplanationInput
      → context projection → Agent Runtime → validated text
      → StatusExplanationViewModel → SwiftUI
```

- Swift owns orchestration: limits, deadline, cancellation, validation, fallback.
- Tool execution is read-only and deterministic (`get_current_status`, `get_data_freshness`). Freshness uses the same `DataFreshness`/`RefreshPolicy` rule as the UI.
- Caller cancellation outranks every failure shape; it never becomes a stale fallback.
- No API keys exist anywhere: the live transport is Apple's on-device Foundation Models. Private Cloud Compute is intentionally unused; no data leaves the device; `PrivacyInfo.xcprivacy` unchanged.

## Boundaries

| Boundary | Type | Notes |
|---|---|---|
| Context projection | Deterministic | Five fields max; full-value equality tests pin the shape |
| Model client | Probabilistic edge | `ExplanationModelClient` for orchestrated transports |
| Tools | Deterministic | Shared `ToolCallBudget` per run; rejection traced before execution |
| Final answer | Untrusted input | Single-field guided schema + shared length/non-empty validator |

## Orchestration

Two transports behind one product seam (`StatusExplanationProviding`):

1. **Orchestrated** (`ScriptedExplanationModelClient` today): Swift runs the turn loop — max 4 model turns, max 3 tool calls, 30 s deadline, per-step cancellation checks. `runCompleted(modelTurns:toolCalls:)` is emitted because turns are well-defined here.
2. **Framework-scheduled** (`FoundationModelsExplanationProvider`): `LanguageModelSession` schedules internal turns. Only deterministic facts are counted, hence `frameworkRunCompleted(toolCallCount:)`. Termination is guaranteed by `BoundedAwait`: the generation races a watcher and **loses by abandonment**, never by join — a hung, cancellation-ignoring transport still yields `deadlineExceeded` on time.

`Cancellation ≠ timeout ≠ guaranteed termination` is encoded in `BoundedAwait` and tested with a non-cooperative operation that ignores cancellation.

## Failure semantics

Every run failure maps through `ExplanationRunError.traceReason` to the composite `FallbackStatusExplanationProvider`, which serves the localized deterministic explanation and records `fallbackUsed(reason:)`. Budget-exhausted tool invocations are traced identically on both transports (`tool_limit`) before the executor would run. Cancellation propagates without fallback at every layer.

## Observability

`ExplanationTraceStore` appends `StoredTraceEvent(sequence:event:)`. Traces contain identifiers, step numbers, tool names, categories, and reasons — never payloads, timestamps of user data, credentials, or hidden reasoning. DEBUG-only sheet via `-ShowExplanationTraces`; OSLog mirrors semantic events.

## Evaluations

38-case deterministic corpus (`status-explanation-evals.json`) covering quiet/alarm/stale/source/tool-selection/invalid-tool/injection-like/loop-control/malformed/transport categories, executed against the real runtime with scripted models. Corpus is frozen for v1; device-phase failures become new regression cases later.

## Release gates

| Gate | Status |
|---|---|
| Unit tests | done |
| Eval suite | done |
| `just verify` | done |
| Release compilation | done |
| Non-cooperative timeout test | done (`BoundedAwaitTests`) |
| Real-device FM smoke test | pending |
| Real-device tool workflow | pending |
| Real-device cancellation/timeout | pending |
| Release AI wiring | blocked until the three device gates pass |

Until release wiring flips, production builds keep `LocalStatusExplanationProvider`; DEBUG builds compose Foundation Models primary with deterministic fallback.
