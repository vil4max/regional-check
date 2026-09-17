# Backlog

The task backlog for Drive Check. Each item links to a spec contract in `docs/tasks/` that an agent executes verbatim: Objective → Authorization → Research → Invariants → Behavior → Tests → Acceptance → Failure conditions → Final report.

Spec-driven cycle: **backlog item → task spec → bounded implementation → `just verify` → defect-first review → atomic commit → release notes**. No implementation without a spec; no spec without acceptance criteria.

Product boundaries in `docs/core.md` stay authoritative over every item below.

## Epic: Redesign — iPhone, CarPlay tabs, widgets (3.0.0)

Owner request 2026-09-17. Mockups: `docs/design/redesign/`. Epic brief: [tasks/redesign.md](../tasks/redesign.md); owner rulings R1–R8 and Q9–Q13 are recorded there (sections 4.2–4.3). Core and requirement amendments (section 4.4) are proposals, not approved. Ships as 3.0.0. Per [ADR 0013](../decisions/0013-one-build-pipeline-or-two.md) the owner tags `tf-3.0.0-N` to request the build, submits that build, and only then tags `v3.0.0`; the older plan to move `v3.0.0` onto the redesign commit is gone (R7). Owner steps: [operations/redesign-3.0-owner-handoff.md](../operations/redesign-3.0-owner-handoff.md).

**Status, session, batch, and owner approval live only on the GitHub Project [Drive Check Redesign](https://github.com/users/vil4max/projects/4)** (private). This table lists tasks, specs, goals, and dependencies; it carries no status.

| Item | Spec | Goal (testable) | Depends on |
|------|------|-----------------|------------|
| RD-EPIC | [tasks/redesign.md](../tasks/redesign.md) | Every mockup ships or has an approved deviation; all RD tasks landed with `just verify` | — |
| RD-0 | [tasks/redesign.md](../tasks/redesign.md) §4.4 | Owner approves or rejects each proposed core/requirement amendment | — |
| RD-1 | [tasks/rd-1-ios-27-minimum.md](../tasks/rd-1-ios-27-minimum.md) | All targets and `DriveCheckKit` require iOS 27; CI builds with release Xcode 27 | — |
| RD-2 | [tasks/rd-2-theme-tokens.md](../tasks/rd-2-theme-tokens.md) | Section 5 tokens and glass helpers exist; no screen changes yet | — |
| RD-3 | [tasks/carplay-map-spike.md](../tasks/carplay-map-spike.md) | Report on Variant B (image plus text) safety and edge cases, measured sizes, screenshots; Variant A not pursued ([ADR 0011](../decisions/0011-carplay-alert-map-candidates.md)) | — |
| RD-4 … RD-12 | [tasks/redesign.md](../tasks/redesign.md) §12 | Briefs written after RD-1/RD-2 land and REQ IDs exist for test-bearing work | RD-1, RD-2, RD-0 |
| RD-13 | [tasks/redesign.md](../tasks/redesign.md) §12 | New App Store screenshots of the new design, English only, owner-approved set | RD-5 … RD-12 |
| RD-14 | [tasks/redesign.md](../tasks/redesign.md) §12 | App Store copy, 3.0 release note and changelog for the redesign; version 3.0.0, owner tags after submission (ADR 0013) | RD-13 |
| RD-15A, RD-15B | [tasks/rd-15-app-icon-launch-cold-start.md](../tasks/rd-15-app-icon-launch-cold-start.md) | Mark icon and Pro alternate ship; launch screen shows the neutral mark; cold start turns it into the status within 400 ms of status, skips the sweep with fresh cache, respects Reduce Motion | A: — · B: RD-2, RD-5 |
| RD-15C | [tasks/rd-15c-layered-icons.md](../tasks/rd-15c-layered-icons.md) | Parked after 3.0.0: an `.icon` package replaces the icon asset catalog, so today's Dark and Tinted icons would be re-authored and the Pro alternate rests on undocumented behaviour; one build settles both | RD-15A |
| DS-1 | [tasks/ds-1-geometry-tokens.md](../tasks/ds-1-geometry-tokens.md) | One ring/launch/icon geometry and standard + Pro token tables in the repo; SVGs without C2PA | — |
| DS-2 | [tasks/ds-2-missing-states.md](../tasks/ds-2-missing-states.md) | PNGs for 11 missing states, including the stale cold-start path and accessibility variants of the DS-3 screens | DS-1 |
| DS-3 | [tasks/redesign.md](../tasks/redesign.md) §12 | Onboarding, About, Paywall, Outside Ukraine sheet designed; spec in `docs/design/redesign/screens-onboarding-about-paywall.md` | — |
| RD-R | [tasks/redesign.md](../tasks/redesign.md) §12 | REQ IDs in all requirements; proposed R4 and cold-start requirements | — |
| RD-CI | [tasks/redesign.md](../tasks/redesign.md) §12 | A later push never cancels a release commit's `main` test run | RD-1 |
| RD-16 | [tasks/redesign.md](../tasks/redesign.md) §12 | Onboarding as real first launch, About, Paywall with subscribed state, Outside Ukraine sheet on leaving Ukraine | DS-3, RD-2, RD-5, RD-0 |
| RD-17 | [tasks/redesign.md](../tasks/redesign.md) §12 | Regression checklist and TestFlight round pass before screenshots and tag | RD-1 … RD-16 |

Constraints: iOS 27 minimum; dark only; safety signal and map stay free; no polling for map images; refresh policy unchanged.

## Epic: Ukraine map tab (2.9, superseded by MAP-2)

Third phone-companion tab showing the upstream Ubilling raster alert map (`?map=`, theme-matched variant) loaded on demand via `AsyncImage`. Charter amended 2026-09-15: map picture of the free signal is allowed as a phone-only glanceable surface, never navigation. Owner rulings: upstream render accepted as-is (no Crimea cropping); tab shows the **image fetch time**, never the snapshot `checkedAt`.

| Item | Spec | Goal (testable) | Status |
|------|------|-----------------|--------|
| MAP-1 | [tasks/map-tab.md](../tasks/map-tab.md) | Map tab loads upstream image on appear + manual refresh, zero polling; VoiceOver label generated from snapshot; CarPlay untouched | Shipped 2.9, superseded by MAP-2 |
| MAP-2 | [tasks/map-on-home.md](../tasks/map-on-home.md) | Map moves off its own tab onto a compact card at the top of Home; two tabs remain (Home, Regions); all MAP-1 behavior (no polling, fetch-time stamp, VoiceOver label, free everywhere) preserved | Specified (3.0 candidate) |

Constraints: no polling, no WebView, no new data beyond the shared snapshot, free on all surfaces, phone-only.

## Epic: Test coverage baseline

Coverage analysis (2026-09-16) showed app launch alone covering 33% of `RegionalCheck.app`, `DriveCheckKit` missing from reports, and main-screen previews unusable for snapshots because they wired the live `AppContainer()`.

| Item | Spec | Goal (testable) | Status |
|------|------|-----------------|--------|
| TEST-1 | [tasks/test-coverage-baseline.md](../tasks/test-coverage-baseline.md) | Inert test host; `DriveCheckKit` measured; `AppContainer.fixture` backs previews and scenario tests; main screens snapshotted; coverage-by-layer re-measured against the baseline | Implemented (awaiting commit) |

## Epic: Siri behind the wheel (on hold — value doubtful)

Voice interface for the CarPlay mission. Specs are written and stay in backlog, but not scheduled until the map candidate ships and Siri value is re-evaluated.

| Item | Spec | Goal (testable) | Status |
|------|------|-----------------|--------|
| SIRI-1 | [tasks/siri-entity-string-query.md](../tasks/siri-entity-string-query.md) | `Kyiv` resolves to both city and oblast for Siri disambiguation; EN/UK/RU spellings resolve | Specified (on hold) |
| SIRI-2 | [tasks/siri-donate-actions.md](../tasks/siri-donate-actions.md) | Each completed check/refresh is donated exactly once; failures and renders donate nothing | Specified (on hold) |
| SIRI-3 | [tasks/siri-onscreen-reference.md](../tasks/siri-onscreen-reference.md) | Regions rows annotated for `this region` references on iOS 18.4+, zero visual change | Specified (on hold) |
| SIRI-4 | [tasks/siri-refresh-shortcut.md](../tasks/siri-refresh-shortcut.md) | `Refresh status in …` phrase in three locales; both actions listed in Shortcuts | Specified (on hold) |

Constraints for the whole epic: no Spotlight indexing (static catalog, not user content), no navigation handoff, no paywall on the safety signal, no change to fetch/persist/scheduling logic.

## Deferred (not in 2.9)

| Candidate | Why deferred |
|-----------|--------------|
| `system.open` + `TargetContentProvidingIntent` open-region intent | Requires iOS 27 SDK decision and a deep-link navigation ruling (per `architecture.md` escalation, Coordinator only when navigation becomes first-class) |
| `system.searchInApp` graceful fallback | Depends on the open-region decision above |
| `SyncableEntity` for cross-device Siri conversations | One-line adoption, but needs a device-pair verification setup first |

## Done

See `CHANGELOG.md` and `docs/operations/releases/` for shipped releases, and `docs/operations/release-process.md` for how to ship.
