# Refresh policy

Application-side polling, retry, and freshness rules for Drive Check. Upstream API limits live in `docs/aerial-alerts-provider.md` — this document is the app contract.

## Request triggers

| Trigger | Network |
|---------|---------|
| Session open (phone tab shell / CarPlay connect) | Immediate fetch |
| Manual Refresh | Immediate fetch |
| Region change | Local select from `AlertsSnapshot`, then background fetch |
| Periodic timer while session active | Yes, adaptive interval |
| Background with no phone UI and no CarPlay | No |

## Adaptive intervals (`RefreshPolicy`)

| Condition | Base interval |
|-----------|--------------:|
| Default | 60 s |
| Current region alarm | 30 s |
| Low Power Mode, thermal ≥ serious, constrained path (Low Data Mode) | 300 s (wins over alarm) |

Each sleep applies ±10 % jitter. Interval is recomputed every cycle and when `NSProcessInfoPowerStateDidChange` fires. Phone and CarPlay share one ref-counted timer on `StatusController`.

Load vs Ubilling **2 rps** host limit: at 60 s ≈ **0.017 rps** from the timer alone.

## Retries and 429

- One retry after **2 s** for transient `URLError` (timeout, connection lost, cannot connect, DNS).
- HTTP **429**: parse `Retry-After` (delta-seconds or HTTP-date); else exponential backoff 30 s → 60 s → … capped at **5 minutes**.
- While the rate-limit window is open, **scheduled** polls are skipped; manual refresh may still attempt.

## Freshness

- Requests use `URLRequest` with `.reloadIgnoringLocalCacheData` and `timeoutInterval = 15`.
- Display `checkedAt` = server `cachedat` when parseable, else local `fetchedAt`.
- Stale UI when `now - checkedAt > 2 × current base interval` (Status, CarPlay, Live Activity).

## Battery

A small HTTPS poll while the screen or CarPlay is active is cheap next to continuous location + reverse geocoding. Prefer kilometer accuracy, distance filter, and geocode throttling (`docs/region-model.md`) over stretching the poll interval alone.

## Related

- ADR 0004 — adaptive refresh and rate-limit behavior  
- Provider wiki limits — `docs/aerial-alerts-provider.md`
