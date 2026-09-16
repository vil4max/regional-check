# Lessons

Record a lesson only when a failure changed a spec, a requirement, a decision,
the core, or agent instructions. Name the check that now catches it.

| Date | Failure | Layer changed | Check that now catches it | Replay |
|---|---|---|---|---|
| 2026-09-16 | Siri answered "All Clear" / "Alert Active" (DriveCheckKit catalog) while phone, CarPlay, widgets, and Live Activity showed "No Alert" / "Alert"; the Siri test matched the raw key, so drift passed | L1 `requirements/surfaces-and-pro-gating.md` (REQ-SURF-001) | `StatusWordingConsistencyTests`; `AlertStatusAnswerBuilderTests` asserts resolved wording | Change one catalog's `All Clear` value and run `just test` |
