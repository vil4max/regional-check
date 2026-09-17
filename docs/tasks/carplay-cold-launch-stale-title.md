# CarPlay cold launch shows stale title over fresh cache

Assignee: regional-check-e2
State: done
Requested by: owner (direct, 2026-09-17)
Evidence: 041cc2f, ea9ab41 on local `main` (not pushed); `just verify` passed in regional-check-e2 and regional-check-d5 sessions
Requirements: `docs/requirements/refresh-policy.md` (CarPlay refresh cycle, CarPlay freshness)
Acceptance specs: `CarPlayLoadStateTests`, `CarPlayRefreshCoordinatorTests`, `CarPlayTemplateBuilderTests`
Owned files: `RegionalCheck/App/{AppDelegate,CarPlaySceneDelegate,CarPlayTemplateBuilder,CarPlayLoadState,CarPlayRefreshCoordinator}.swift`, `RegionalCheck/Views/StatusController.swift`, `RegionalCheck/Resources/Localizable.xcstrings`, `RegionalCheckTests/CarPlay{TemplateBuilder,LoadState,RefreshCoordinator}Tests.swift`
Out of scope: phone status freshness, `.github/workflows/release.yml`, `scripts/promote-release.sh`
Failure conditions: a failed request hides fresh cached status in the CarPlay title; stale cached status appears without its age; a superseded CarPlay cycle cancels the request shared with the phone UI

## Problem

A CarPlay-only cold launch on weak cellular showed "No current data" above a
one-minute-old cached status. `StatusController.isDataStale` treats any failed
request as stale regardless of `checkedAt`, and the template title followed it.
