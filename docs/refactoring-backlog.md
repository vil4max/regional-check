# Refactoring backlog

Candidates captured from the current SwiftLint baseline. These items are
planned cleanup work, not release blockers.

## Swift file and type size

- [ ] Split `RegionalCheck/AI/CountrySummaryProvider.swift` (503 lines) into
  country summary composition, deterministic localization, and model transport
  components. Preserve the existing protocol boundaries and tests.
- [ ] Split `RegionalCheck/Views/CountrySummaryViewModel.swift` (442 lines)
  into focused country-summary and status-details view model files.
- [ ] Reduce `RegionalCheck/Views/StatusView.swift` (254-line view body) by
  extracting presentation sections without changing the status contract.
- [ ] Reduce `RegionalCheck/App/CarPlaySceneDelegate.swift` (271-line class)
  by extracting template construction and rendering helpers while keeping the
  scene delegate lifecycle in one place.

## Test organization

- [ ] Split `RegionalCheckTests/StatusDetailsViewModelTests.swift` (406 lines,
  316-line test type) into lifecycle, stale-data, localization, and rendering
  behavior suites.

## Acceptance criteria

- Keep behavior unchanged and preserve the existing MVVM and protocol seams.
- Add or retain focused tests for each extracted unit.
- Remove the related SwiftLint warnings without raising thresholds or excluding
  files.
- Run `just verify` after each candidate or atomic group.
