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

No open items. Re-run `just lint` after future changes to catch new size
violations and add them here.
