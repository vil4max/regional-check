# Backlog

The task backlog for Drive Check. Each item links to a spec contract in `docs/tasks/` that an agent executes verbatim: Objective → Authorization → Research → Invariants → Behavior → Tests → Acceptance → Failure conditions → Final report.

Spec-driven cycle: **backlog item → task spec → bounded implementation → `just verify` → defect-first review → atomic commit → release notes**. No implementation without a spec; no spec without acceptance criteria.

Product boundaries in `docs/core.md` stay authoritative over every item below.

## Epic: Ukraine map tab (2.9, superseded by MAP-2)

Third phone-companion tab showing the upstream Ubilling raster alert map (`?map=`, theme-matched variant) loaded on demand via `AsyncImage`. Charter amended 2026-09-15: map picture of the free signal is allowed as a phone-only glanceable surface, never navigation. Owner rulings: upstream render accepted as-is (no Crimea cropping); tab shows the **image fetch time**, never the snapshot `checkedAt`.

| Item | Spec | Goal (testable) | Status |
|------|------|-----------------|--------|
| MAP-1 | [tasks/map-tab.md](../tasks/map-tab.md) | Map tab loads upstream image on appear + manual refresh, zero polling; VoiceOver label generated from snapshot; CarPlay untouched | Shipped 2.9, superseded by MAP-2 |
| MAP-2 | [tasks/map-on-home.md](../tasks/map-on-home.md) | Map moves off its own tab onto a compact card at the top of Home; two tabs remain (Home, Regions); all MAP-1 behavior (no polling, fetch-time stamp, VoiceOver label, free everywhere) preserved | Specified (3.0 candidate) |

Constraints: no polling, no WebView, no new data beyond the shared snapshot, free on all surfaces, phone-only.

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

See `CHANGELOG.md` and `docs/release-*.md` for shipped releases.
