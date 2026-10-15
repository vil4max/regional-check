# Backlog run: plan and progress

Working file for finishing the backlog that started on 2026-10-15. A new session resumes from
here: read the plan, check `git log` against the "Done" list, and continue with the first open
group. Delete this file when the backlog is empty.

## Scope and order

1. Baseline gate on the untouched tree.
2. Record the owner's decision that Pro is a cosmetic bundle (ADR 0016) and park PRO-VIS-1/2.
3. Verify the unverified audit findings of 2026-10-10 against the code; fix the confirmed ones
   in groups, each ending green in one commit; record every rejection with a one-line reason
   in [audit-2026-10-10-findings.md](audit-2026-10-10-findings.md).
4. Remaining in-scope backlog items (REGION-*, LOCATION-PAUSE, GEOCODE-TIMEOUT,
   RATE-LIMIT-WINDOW, FEED-26-KEYS, ARCH-LOWS, LINT-BASELINE, PRO-COSMETIC).

Out of scope without the owner: new requirements, App Store Connect actions, product IDs,
prices, releases and `v` tags.

## Progress

| Step | State | Evidence |
|------|-------|----------|
| 1 Baseline gate | running | |
| 2 Cosmetic Pro decision recorded | done (uncommitted) | ADR 0016, core.md, backlog.md |
| 3 Audit verification | running | |
