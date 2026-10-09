# regional-check — project notes

<!-- repository-visibility-policy -->
Repository visibility: **PUBLIC**.

## Data handling

Never include confidential or sensitive personal data in source, documentation,
Git history, commit messages, issues, pull requests, logs, or artifacts. This
includes private financial information, compensation expectations or offers,
personal assessments, health or family details, private correspondence, and
application records. Use fictional data in examples and tests. Never commit
credentials, tokens, passwords, session data, or private keys.

## Documentation quality

Write public-facing documentation in clear, technical English for readers
without access to private workspace context. Keep instructions accurate,
repository-relative, and reproducible. Distinguish implemented behavior from
plans, state relevant prerequisites and limitations, and update documentation
with the behavior it describes. Exclude personal notes, internal handoffs,
machine-specific paths, and unsupported claims.
<!-- /repository-visibility-policy -->

## Project

Drive Check (App Store name DriveCheckUA) is an iOS app that shows a driver in
Ukraine whether their region is under an air raid alert, at a glance on
CarPlay, the iPhone, widgets and Live Activities.

- Repository / scheme / bundle ID: `regional-check` / `RegionalCheck` / `vil4max.RegionalCheck`
- Platform: iOS 27+, Swift 6, SwiftUI, Swift Testing
- Build configuration: [`ios-verify.conf`](ios-verify.conf) (scheme, project, simulator `iPhone 17` on iOS 27.0, device family, App Group check)
- Product boundaries: [`docs/core.md`](docs/core.md)

## Folder structure

```text
Packages/DriveCheckKit/   Domain models, provider, SharedStore, intents
RegionalCheck/
  App/                    Lifecycle, composition root, CarPlay, theme
  Views/                  Phone presentation and presentation controllers
  Data/                   Region, location, refresh and freshness policies
  Subscription/           StoreKit 2 and entitlement state
  LiveActivity/           Session lifecycle and ActivityKit integration
  AI/                     Status details summary providers
  Resources/              Assets, string catalogs, Info.plist, entitlements
RegionalCheckWidgets/     Widgets, Live Activity UI, Control Center control
RegionalCheckTests/       Swift Testing unit, scenario and snapshot tests
TestPlans/                Default and Snapshots test plans
scripts/                  App scripts: requirement trace (spec/), CI extras, screenshots, coverage
ci_scripts/               TestFlight tag checks and the Xcode Cloud post-clone script
docs/                     Core, requirements, decisions, engineering, operations, design
release/                  App Store screenshots
```

New feature specs go in `specs/<KEY>-<slug>/` (`spec.md`, `plan.md`). The requirements
already in `docs/requirements/` stay and are traced by `scripts/spec-trace.sh`.

Architecture: [`docs/engineering/architecture.md`](docs/engineering/architecture.md) and
[`docs/engineering/project-map.md`](docs/engineering/project-map.md).

## Agent tooling

This repository holds the product only. The `ios-agentic-sdlc` plugin supplies the iOS
rules, the stage skills and the gate; enable it at local scope in each checkout
(`claude plugin install ios-agentic-sdlc@ios-agentic-sdlc --scope local`).
`.worktreeinclude` copies the local settings file that records this into every worktree
Claude Code creates. Tools: Xcode 27 and SwiftLint in the version recorded in `.swiftlint-version` (CI downloads exactly that release).

## Definition of done

```bash
ios-verify              # project checks, lint of the changed Swift files, build, unit tests
scripts/spec-trace.sh   # every approved requirement is cited by a tracked test
```

`ios-verify` is on the Bash tool's PATH while the plugin is enabled. A full run takes
minutes: run it in the background or with a 10-minute timeout. Details:
[testing strategy](docs/engineering/testing-strategy.md#measuring-req-coverage).
Before a release commit, run both, check that the working tree is clean, and follow the
[release process](docs/operations/release-process.md).

## Commands

```bash
ios-verify                                       # the gate above, without the trace
ios-verify --only-testing Target/Class/test      # one test; not a substitute for the gate
ios-verify lint [--all] [--fix]                  # swift-format and swiftlint only
ios-verify run-sim                               # build, install and launch on this worktree's own simulator
ios-verify run-sim -- -ScreenshotPhase allClear  # launch with a fixture scenario (also: alertActive)
scripts/spec-trace.sh [--results <bundle.xcresult>] [--briefs]
scripts/capture-app-store-screenshots.sh         # App Store screenshots
scripts/coverage-pyramid.sh                      # regenerate docs/engineering/coverage-pyramid.html (slow)
scripts/swiftlint-baseline.sh                    # rewrite the SwiftLint baseline
scripts/prune-worktrees.sh [--apply [--only <branch>]]
python3 scripts/project-artifacts.py task <task-slug>   # shared evidence directory
ci_scripts/tf-check.sh [<commit>]                # check a commit before tagging a TestFlight build
```

CI runs the same checks without the plugin (`.github/workflows/tests.yml`).

## Code conventions

- Style: [`.swiftlint.yml`](.swiftlint.yml) and [`.swift-format`](.swift-format) (Apple's swift-format); `ios-verify` lints the Swift files changed since the merge base and CI lints all of them. [`.swiftlint.baseline.json`](.swiftlint.baseline.json) records the size violations that existed when the limits were adopted: only new ones fail, and a refactor that removes some shrinks the file (`scripts/swiftlint-baseline.sh`). SwiftLint matches a baseline entry by its text, which includes the current length, so a change to a baselined type or function must either bring it under the limit or regenerate the baseline in the same commit and say why ([testing strategy](docs/engineering/testing-strategy.md#lint-and-the-swiftlint-baseline)).
- Architecture: MVVM with protocol seams at service boundaries ([ADR 0008](docs/decisions/0008-mvvm-service-boundaries.md)). Long-lived shared state belongs in an application Store or Session, not a screen view model.
- Comments carry only what code cannot: intent, invariants, constraints and trade-offs, in English. Update or remove them with the code.
- Commit messages: `<type>[(<scope>)]: <summary>`, in English, lowercase imperative, no final period. Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `build`, `ci`, `perf`. One logical change per commit.
- Tests: name each requirement test with its ID (`REQ-<AREA>-NNN`) in the test's display name. A bug starts with a failing test.
- Requirements and core: a change starts at the highest affected layer (core → [requirements](docs/requirements/) and [decisions](docs/decisions/) → tests → code). Index: [`docs/README.md`](docs/README.md).
- Localization: String Catalogs in `en`, `uk` and `ru`; every key carries all three.

## Versioning

- Use three-component marketing versions: `MAJOR.MINOR.PATCH`. All three are
  integers, not decimal fractions.
- A feature release increases `MINOR` and resets `PATCH` to `0`: `2.8.0` →
  `2.9.0`, and `2.9.0` → `2.10.0`. A fix-only release with no new features
  increases `PATCH` instead: `2.9.0` → `2.9.1`. Change `MAJOR` only for a
  deliberate major release.
- Keep app and widget marketing versions aligned in Debug and Release configurations.
- Reset the local build number to `1` for a new marketing version; increment it for
  subsequent builds of that version. Xcode Cloud may assign its own build number.
- An annotated tag `tf-MAJOR.MINOR.PATCH-BUILD` (for example `tf-3.0.0-2`) on a
  verified commit requests an internal TestFlight build; `BUILD` counts the
  TestFlight builds of that marketing version, starting at `1`. Merging to `main`
  requests nothing.
- An annotated tag `vMAJOR.MINOR.PATCH` (for example `v3.0.0`) marks the commit
  whose build was submitted to App Review; it requests no build, because the
  submitted build is that commit's TestFlight build. A pushed release tag may be
  moved only while no build of that version was submitted to App Review or
  released, and only to a later commit on `main`; after submission it is never
  moved or reused. Follow
  [docs/operations/release-process.md](docs/operations/release-process.md).

## Local artifacts

Screenshots, recordings, logs and coverage evidence go to the ignored
`.artifacts/` directory of the primary checkout through
`python3 scripts/project-artifacts.py task <task-slug>`; see
[artifact lifecycle](docs/engineering/artifact-lifecycle.md).
