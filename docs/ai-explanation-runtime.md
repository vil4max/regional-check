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

Every run failure maps through `ExplanationRunError.traceReason` to the composite `FallbackStatusExplanationProvider`, which serves the localized deterministic explanation and records `fallbackUsed(reason:)`. Budget-exhausted tool invocations are traced identically on both transports (`tool_limit`) before the executor would run. Cancellation propagates without fallback at every layer — including the window between primary failure and fallback start.

## Review disposition (v1)

**Milestone: Agent Runtime v1 — reviewed, verified, committed, production-disabled.**

All defects that could violate external runtime guarantees are closed. Both P2 classes are proven by tests: guaranteed termination under deadline (including cancellation-ignoring transports) and caller-cancellation propagation through every fallback window. Disposition of all findings:

| Outcome | Count | Items |
|---|---|---|
| Fixed | 6 | FM deadline/turn bounds; honest framework completion telemetry; budget-rejection tracing parity; trace sequence identity; cancellation normalization at transport boundaries; cancellation window inside composite fallback |
| Deferred (device-dependent) | 1 | Run-level reason when FoundationModels wraps tool-limit errors — needs observed error type/causal chain from a real runtime before any unwrap is written |
| Accepted v1 limits | 3 | Throw-on-first-budget-violation semantics; batch-rejection tracing beyond first call; test-only abandoned immortal operation |

Two standing notes:

- The abandoned non-cooperative task is the deliberate price of the hard deadline boundary. If a real transport ever holds a significant resource after abandonment, that becomes a separate resource-lifetime question, not a deadline-correctness one.
- The eval corpus stays frozen at 38 cases until device runs produce real failure modes; those become new regression evals rather than synthetic ones.

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
| Real-device FM validation | **done** — iPhone 15 Pro Max, 7/7 passed (`FoundationModelsDeviceValidationTests`, opt-in `TEST_RUNNER_RC_FM_DEVICE=1`) |
| Release AI wiring | pending owner decision |

### Device validation results (2026-08-26, iPhone 15 Pro Max)

1. Availability: `.available`; smoke response returned `OK`.
2. `get_current_status` workflow: model called tools, final answer grounded in deterministic facts.
3. `get_data_freshness` workflow: freshness relayed correctly ("not stale… last refreshed 60 seconds ago") — model never did its own timestamp math.
4. Multi-tool invocation: both tools called in one run (2 calls), grounded final.
5. **Tool-limit error shape**: framework wraps our typed error as `ToolCallError(underlyingError: ExplanationRunError.toolLimitExceeded)` — direct cast fails, but `underlyingError` carries the full typed error, so run-level reason recovery is feasible without speculation (v1.1 candidate).
6. Caller cancellation during `respond`: surfaces as native `CancellationError` — the transport is cooperative.
7. Deadline during active `respond`: `BoundedAwait` fired at 5.05s against a 5s budget.
8. Trace semantics: `toolRequested/toolSucceeded/toolFailed` recorded for every framework-invoked call, identical to the scripted transport.

Until release wiring flips, production builds keep `LocalStatusExplanationProvider`; DEBUG builds compose Foundation Models primary with deterministic fallback.

### Foundation Models Device Validation

Strictly empirical phase — each item records observed behavior, error type, causal chain, and resulting trace semantics:

1. availability check + smoke response
2. real `get_current_status` workflow
3. real `get_data_freshness` workflow
4. multi-tool invocation behavior
5. tool-limit error shape / framework wrapping (feeds the deferred run-level reason decision)
6. caller cancellation during an active `respond`
7. deadline firing while `respond` is active
8. inspection of resulting trace semantics

Outcomes are binary: either the adapter is confirmed and release wiring is enabled, or observed FM failure modes become new regression tests/evals driving a small v1.1.
