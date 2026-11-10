# Quality gate

A pull request merges only when every check is green. SonarCloud Code Analysis is a required status
check on `main`, and its quality gate ("Sonar way") requires at least 80% coverage on new code
(owner, 2026-11-10). Nobody merges with a red gate, and only the owner relaxes a gate.

## Coverage exclusions

Coverage comes from the unit and snapshot test runs (`scripts/ci-extra.sh`,
`scripts/sonar-coverage.sh`). A few files are platform glue that those runs cannot execute. They
are listed in `sonar.coverage.exclusions` in [`sonar-project.properties`](../../sonar-project.properties).
SonarCloud still analyses them for bugs and code smells; only the coverage measure skips them.

The owner approved this list path by path (2026-11-10). A new path needs the owner's decision for
that path. The list never grows to turn a gate green. Logic stays covered: nothing in
`Packages/DriveCheckKit` and no view model is excluded.

| Path | Why unit and snapshot tests cannot reach it |
|---|---|
| `RegionalCheck/App/AppContainerFixture.swift` | DEBUG-only container for previews and scenario tests. |
| `RegionalCheck/App/FixturePush.swift` | DEBUG-only push fixture for previews. |
| `RegionalCheck/App/AppDelegate.swift` | App lifecycle callbacks (launch, APNs token, scene configuration). The unit-test host launches inert and never builds the live container. |
| `RegionalCheck/App/RegionalCheckApp.swift` | The `@main` App entry point and scene wiring, which the inert test host skips. |
| `RegionalCheck/LiveActivity/LiveActivityHosting.swift` | Thin adapters over ActivityKit (`Activity.request`, token and activity streams). Tests drive `FixtureLiveActivityHost` through the same protocol instead. |
| `RegionalCheck/Push/PushPermission.swift` | Adapters over `UNUserNotificationCenter` and `UIApplication.registerForRemoteNotifications`. Tests use fake permission sources through the same protocol. |
| `RegionalCheckWidgets/**` | The widget extension: widget, Live Activity and control views, plus WidgetKit glue. It is a separate binary that the coverage report does not include. Its logic (timelines, presentation, freshness) lives in `DriveCheckKit` and is covered there. |
