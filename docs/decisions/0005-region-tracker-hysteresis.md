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

Amended 2026-09-20 by [ADR 0015](0015-two-tab-phone-ia.md): the manual pin and the notice's
Undo are removed. The region follows location only, so the tracker is the single path to a
region change and nothing bypasses it; the notice stays, dismissible, without Undo. The two
lines above are kept as the decision that was taken at the time.

Amended 2026-09-21: once location became the only way to choose a region, two gaps in the
rules above had no workaround left. A session's first resolve now commits at once, because the
stored region it competes with is older evidence than a fresh fix; and the 5 km geocode
condition is lifted while a candidate is pending or after a resolve that produced no region, so
a parked driver's candidate can be confirmed after 90 s and a failed geocode is retried after
60 s. Rejected: dropping hysteresis altogether (border flapping while driving is what it was
built for) and restoring a manual override (the owner removed it on purpose).

## Consequences

- Auto-switch is slower near borders by design.
- Constants are named on `RegionTracker` and documented in `docs/requirements/region-model.md`.
- Location manager uses kilometer accuracy, 2 km distance filter, automotive activity.
