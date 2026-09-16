# ADR 0005 — `RegionTracker` debounce and hysteresis

## Status

Accepted

## Context

Driving near oblast borders produced region flicker. Core Location also delivers stale/cached fixes at session start. Reverse geocoding on every update wastes power.

## Decision

Move auto-follow logic into `RegionTracker` with injectable clock and geocoder:

- Accept only fresh, ≤ 1 km accuracy fixes.
- Throttle geocodes (≥ 60 s and ≥ 5 km).
- Hysteresis candidate (≥ 90 s or ≥ 5 km) before commit.
- Manual pin (`followsLocation == false`) bypasses the tracker.

Show a non-modal “region changed” notice with Undo; never a blocking alert while driving.

## Consequences

- Auto-switch is slower near borders by design.
- Constants are named on `RegionTracker` and documented in `docs/requirements/region-model.md`.
- Location manager uses kilometer accuracy, 2 km distance filter, automotive activity.
