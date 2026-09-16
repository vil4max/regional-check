# ADR 0004 — Adaptive refresh and rate limits

## Status

Accepted

## Context

A fixed five-minute poll under-served alarm periods; a fixed one-minute poll wasted radio on Low Power / expensive networks. Ubilling returns HTTP 429 above 2 rps.

## Decision

1. `RefreshPolicy` chooses 60 / 30 / 300 second bases with ±10 % jitter from injectable environment signals.
2. Transient URL errors retry once after 2 s; 429 sets a suppress-until deadline for scheduled polls.
3. Freshness UI uses two× the current base interval against server `cachedat`.

## Consequences

- StatusController owns the timer, power-state restart, and rate-limit gate.
- Tests inject environment / clock / sleep — no real waits.
