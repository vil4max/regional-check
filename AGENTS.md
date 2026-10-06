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
- Build configuration: [`Tooling/runtime.yml`](Tooling/runtime.yml) (scheme, simulator `iPhone 17` on iOS 27.0, backend)
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
Tooling/                  Shared build, lint, test and CI scripts (do not edit by hand)
scripts/                  App-specific scripts (screenshots, coverage, requirement trace)
docs/                     Core, requirements, decisions, engineering, operations, design
release/                  App Store screenshots
```

Architecture: [`docs/engineering/architecture.md`](docs/engineering/architecture.md) and
[`docs/engineering/project-map.md`](docs/engineering/project-map.md).

## Definition of done

```bash
just verify
```

It runs the requirement trace (`just trace`: every approved requirement is cited
by a tracked test), then format, lint, build and all tests. Details:
[testing strategy](docs/engineering/testing-strategy.md#measuring-req-coverage).
Before a release commit, `just release --check` requires a clean working tree and
matching successful verification evidence. It does not start a build.

## Commands

```bash
brew bundle --file=Tooling/Brewfile   # tool dependencies
just doctor                           # check the local setup
just format
just lint
just build
just test
just verify
just release --check
just run-sim                          # launch in a simulator
just scenario allClear                # launch with a fixture scenario (also: alertActive)
just screenshots                      # App Store screenshots
just tf-check                         # check a commit before tagging a TestFlight build
just prune-worktrees --apply --only <branch>
```

App-local recipes live in the root `justfile`, which imports `Tooling/justfile`.
Prefer `just …` over raw `xcodebuild`.

## Code conventions

- Style: [`Tooling/.swiftlint.yml`](Tooling/.swiftlint.yml) and [`Tooling/.swift-format`](Tooling/.swift-format) (Apple's swift-format). Install the Git hooks once with `./scripts/install-hooks.sh`; the pre-commit hook runs `just format` and `just lint`.
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
`just artifacts task <task-slug>`; see
[artifact lifecycle](docs/engineering/artifact-lifecycle.md).
