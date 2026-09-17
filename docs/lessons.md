# Lessons

Record a lesson only when a failure changed a spec, a requirement, a decision,
the core, or agent instructions. Name the check that now catches it.

| Date | Failure | Layer changed | Check that now catches it | Replay |
|---|---|---|---|---|
| 2026-09-17 | Every merge to `main` that passed checks archived and uploaded a TestFlight build, documentation commits included; the App Store Connect build limits ran out during the redesign waves | L1 `decisions/0012-tag-gated-testflight-builds.md` (supersedes the `testflight` row of ADR 0010); `docs/operations/release-process.md` invariants 3-4 | `tests.yml` promotes nothing; `testflight` moves only through `promote-testflight.sh`, which requires an annotated `tf-MAJOR.MINOR.PATCH-BUILD` tag | Push a commit to `main` and confirm no Xcode Cloud build starts; then tag it and confirm one does |
| 2026-09-16 | Siri answered "All Clear" / "Alert Active" (DriveCheckKit catalog) while phone, CarPlay, widgets, and Live Activity showed "No Alert" / "Alert"; the Siri test matched the raw key, so drift passed | L1 `requirements/surfaces-and-pro-gating.md` (REQ-SURF-001) | `StatusWordingConsistencyTests`; `AlertStatusAnswerBuilderTests` asserts resolved wording | Change one catalog's `All Clear` value and run `just test` |
