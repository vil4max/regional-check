# ADR 0002 — Canonical `AlertRegion` enum

## Status

Accepted

## Context

Regions were represented with a legacy `kyivCity` / `oblast(name:)` shape and free-form strings. Ubilling’s live feed exposes a fixed set of 25 keys (no Crimea / Sevastopol). Free-form names caused silent mismatches and made full-catalog snapshots awkward.

## Decision

Introduce `AlertRegion: String, CaseIterable, Codable` with exactly the live feed keys (`apiKey`). Persist as `selected_region_v2` and migrate from `selected_region_v1` once.

## Consequences

- Catalog changes require an explicit app update when Ubilling adds keys.
- Unknown feed keys are ignored (logged), not invented as regions.
- UI, CarPlay, and tests share one type and 25 cases.
