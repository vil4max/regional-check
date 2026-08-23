# Antigravity Agent Task — AI Explanation Boundary

## Role and experiment context

You are Antigravity, working in a controlled AI engineering experiment inside an existing production-style SwiftUI/iOS repository.

- Product: Drive Check
- Repository: `regional-check`
- Worktree: `regional-check-worktrees/ai-explanation`
- Branch: `feature/ai-explanation`
- Starting feature-contract commit: `7ad91fc`

Work only inside this worktree. This task creates a production-ready extension point and user-requested explanation flow. It does not integrate a real AI runtime.

## Required reading

Before editing, read these files in order:

1. `AGENTS.md`
2. `docs/agent-pilot-brief.md`
3. `Tooling/runtime.yml`
4. `docs/architecture.md`
5. `docs/product-charter.md`
6. This task contract

Repository instructions are authoritative. If this contract conflicts with them, stop and report the conflict.

## Objective

Replace the always-visible static explanation on the phone status screen with an explicit `Explain status` action backed by an asynchronous, initializer-injected explanation provider.

The first live provider is a deterministic local baseline that returns the existing localized status explanation. It establishes the UI, state-management, dependency, and testing seams required for a future AI implementation without pretending that an LLM is present.

## Authorization and boundaries

You are authorized to inspect repository files and Git state, modify files required for this feature and its tests, run `just doctor`, focused Runtime checks, and `just verify`, and format only files within the feature diff.

You must not:

- commit, push, merge, rebase, stash, or change branches;
- modify unrelated files;
- add dependencies, SDKs, API keys, secrets, network calls, or backend contracts;
- call an LLM or external explanation service;
- change alert calculation, severity, region status, or other business decisions;
- let SwiftUI call a provider directly;
- make explanation output a source of status truth;
- invent premium/paywall behavior;
- remove or redesign CarPlay explanation behavior;
- silently fix unrelated defects.

If the architecture does not provide enough information to implement this cleanly, stop and explain what is missing. Do not create fake abstractions only to satisfy the task.

## Mandatory research phase

Before coding:

1. Inspect `StatusState.explanation`, `StatusView`, `HomeView`, `StatusController`, `AppContainer`, CarPlay status presentation, and current status tests.
2. Identify the current source of snapshot, region, resolved status, localization, freshness, and source label.
3. Identify the smallest existing ViewModel/presentation-state pattern that can own an async user action.
4. Inspect dependency-injection and test-double conventions.
5. Determine how to prevent a late async result from being shown for a different snapshot, region, or status.
6. Run `git status --short --branch` and confirm the worktree contains no unexpected changes.
7. Write a concise implementation plan in your working response before editing.

Proceed without another approval only if the plan stays within this contract. Otherwise stop with `BLOCKED_CORRECTLY`.

## Architecture invariants

Preserve this dependency direction:

```text
StatusView
    |
    v
Explanation presentation state / ViewModel
    |
    v
StatusExplanationProviding protocol
    |
    v
Deterministic local baseline implementation
```

Alert state remains upstream and authoritative:

```text
AlertsSnapshot + selected region
              |
              v
      resolved StatusState
              |
              v
      explanation input
```

The explanation layer may describe existing state. It must not decide or mutate that state.

## Required behavior

- Replace the phone UI's permanently visible `StatusState.explanation` text with an accessible `Explain status` action.
- Enable the action only when a current snapshot exists and the resolved state is `.quiet` or `.alarm`.
- On request, show explicit async presentation states: loading, result, and error with retry.
- The deterministic local baseline provider returns the existing localized explanation for the already resolved state. Do not invent richer content.
- Build provider input from the current snapshot, selected region, and resolved status through a minimal immutable value type or equivalent existing pattern.
- Inject the provider through the composition root. UI must forward intent to presentation logic rather than call the provider directly.
- Reset an existing result when snapshot, selected region, or resolved status changes.
- Ignore or cancel a late async response if its input is no longer current.
- Provider failure must not change alert state or hide the core status UI.
- Preserve the current CarPlay explanation behavior in this iteration.
- Do not add real AI branding, network/privacy claims, entitlement logic, analytics, persistence, or streaming.

## Required test scenarios

Add or extend deterministic Swift Testing coverage for:

1. Action availability requires a snapshot and quiet/alarm state.
2. Request receives the current immutable explanation input.
3. Successful request transitions loading to result.
4. Failure transitions loading to error without changing status.
5. Retry starts a new request and can succeed.
6. Snapshot, region, or status change clears the old result.
7. A late result for obsolete input is not displayed.
8. Repeated taps while loading do not create unintended concurrent requests.
9. Existing status resolution and CarPlay explanation behavior do not regress.

Use protocol-conforming fakes/spies. Do not add timing-dependent sleeps when controllable continuations or existing async test patterns can express the scenario.

## Acceptance criteria

- Phone UI exposes an accessible user-requested explanation action instead of always-visible static explanation text.
- Async presentation state is owned outside the view and is testable.
- Provider is protocol-backed and initializer-injected from the composition root.
- The local baseline reuses existing localized explanation content without posing as AI output.
- Obsolete async responses cannot overwrite newer UI context.
- Alert state and all business decisions remain independent of explanation output.
- CarPlay retains its current behavior.
- Focused tests cover the required scenarios.
- `just verify` succeeds, or an exact environmental/product blocker is reported.
- The Git diff contains only feature-related production code, localization changes if strictly required, and tests.

## Failure conditions

The task fails if an API key, SDK, network client, LLM call, or backend contract is introduced; UI calls the provider directly; explanation determines alert state; a late result can be displayed for obsolete input; product, pricing, privacy, or AI behavior is invented; static and requested explanations are duplicated without reason; CarPlay is unintentionally changed; unrelated changes appear; or commands are claimed without evidence.

## Completion procedure

1. Inspect final `git diff` and `git status`.
2. Run the smallest focused checks useful during development.
3. Run `just verify` once for final technical verification.
4. Do not commit or push.
5. Return one final report using the exact structure below.

## Required final report

```markdown
# Agent Result

## Outcome
COMPLETED | BLOCKED_CORRECTLY | FAILED

## Summary
What changed or why implementation stopped.

## Research findings
Existing flow, relevant ownership boundaries, and evidence used.

## Files changed
Each file and why it changed.

## Architecture decisions
Decisions made, alternatives rejected, and how invariants were preserved.

## Tests added or changed
Scenarios covered and material gaps.

## Commands executed
Exact commands, including failed commands.

## Verification results
Pass/fail result for each check. Do not summarize an unexecuted command as passing.

## Risks
Residual correctness, concurrency, lifecycle, presentation, or integration risks.

## Open questions
Only unresolved decisions requiring human input. Write `None` if there are none.
```

The report will be compared with the actual Git diff and command evidence. Accuracy and transparency matter more than presenting the work as successful.
