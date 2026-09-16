# ADR 0003 — Geocoding seam and normalizing resolver

## Status

Accepted

## Context

`RegionSelection` used MapKit reverse geocoding inline, which blocked unit tests and mixed transport with matching. Administrative names vary by locale (`обл.`, `Oblast`, English city names).

## Decision

1. `ReverseGeocoding` protocol + `MapKitReverseGeocoder` (preferred locale `uk_UA`).
2. Pure `AlertRegionResolver` with normalization and Kyiv-city precedence over oblast.
3. Unresolved names return `nil` and log; current region is kept.

## Consequences

- Tracker and selection tests inject fakes without MapKit.
- Resolver tables live in tests (`AlertRegionResolverTests`) and `docs/requirements/region-model.md`.
