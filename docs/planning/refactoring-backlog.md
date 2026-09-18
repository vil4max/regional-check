# Refactoring backlog

Candidates captured from the current SwiftLint baseline. These items are
planned cleanup work, not release blockers.

## Completed

- [x] Split `RegionalCheck/AI/CountrySummaryProvider.swift` (503 lines) into
  country summary composition (`CountrySummaryProvider.swift`) and status
  details transport/localization (`StatusDetailsProvider.swift`).
- [x] Split `RegionalCheck/Views/CountrySummaryViewModel.swift` (442 lines)
  into `CountrySummaryViewModel.swift` and `StatusDetailsViewModel.swift`.
- [x] Reduce `RegionalCheck/Views/StatusView.swift` (254-line view body) by
  extracting `StatusHeroView`, `StatusRegionHeaderView`,
  `StatusFooterMessagesView`, and `StatusRefreshButtonView`.
- [x] Reduce `RegionalCheck/App/CarPlaySceneDelegate.swift` (271-line class)
  by extracting template construction into `CarPlayTemplateBuilder.swift`.
- [x] Split `RegionalCheckTests/StatusDetailsViewModelTests.swift` (406 lines,
  316-line test type) into lifecycle, model-prompt, and deterministic
  localization suites, with shared harness in `StatusDetailsTestSupport.swift`.

All five items removed the related SwiftLint warnings without raising
thresholds or excluding files. `just verify` passes.

## Open

Both items are at or over a SwiftLint ceiling, print on every pre-commit run in
the repository, and are tracked as cards on the redesign board with
drivecheck-qa. Neither is a release blocker; both land before RD-12 edits those
files, so that task does not pay for the split mid-flight.

- [ ] `RegionalCheck/App/CarPlaySceneDelegate.swift` — **466 lines against the
  400 limit**, with a **285-line class body against 250**. It grew with RD-9's
  Map tab. Split along a seam the file already has: RD-9 extracted
  `makeRootTemplates(loadState:freshness:)` for exactly this reason, which the
  earlier `CarPlayTemplateBuilder` extraction did not provide. The comment at
  that extraction explains why it exists (`CPInterfaceController` has no public
  initializer, so the scene-lifecycle path cannot be driven from a test) and
  must survive the split.
- [ ] `RegionalCheck/App/StatusController.swift` — **exactly 400 of 400**, so
  the next line added anywhere in it trips `file_length`. Candidate seams the
  file already has: persistence, the periodic-refresh loop, and the DEBUG
  screenshot fixture — whose `applyScreenshotFixture` guard has to stay visible
  at its decision point, because a regression test points at it.

Re-run `just lint` after future changes to catch new size violations and add
them here. An item belongs here the moment it is at a ceiling, not once it is
over one: at exactly 400 lines the file is already a trap for whoever touches
it next.
