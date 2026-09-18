# Launch and cold start

Launch screen and first-seconds behavior of the redesigned app (RD-15B).
Geometry and colors: `docs/design/redesign/geometry-and-tokens.md` §4.
Design: `docs/design/redesign/cold-start-storyboard.png`,
`docs/design/redesign/states/cold-start-stale.png`.

## Requirements

### REQ-LAUNCH-001 — No status color before status is known

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given the app launches\
When no current or cached status is known yet\
Then the launch screen and every cold-start frame show only the neutral mark, never a status color

### REQ-LAUNCH-002 — Cold start never delays a known status

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P1

Given status becomes known during a cold start\
When the transition plays\
Then it adds at most 400 ms before the Status screen is fully shown

### REQ-LAUNCH-003 — No sweep with a cached status

Status: approved — owner, 2026-09-18 ("согласен с двумя пунктами, всегда опираемся на документацию убилинг чтобы нас не заблочили", agreed with both points, we always rely on Ubilling's documentation so we do not get blocked); replaces the 2026-09-17 text, which covered only a fresh cache and left a stale one undefined

Core: P1

Given a cached status exists at launch, **fresh or stale** (REQ-REFRESH-006)\
When the app launches\
Then the checking sweep is skipped and the transition goes straight to that
status

A stale status is still a known status — it is available synchronously before
the view appears — so playing a sweep in front of it would delay something the
app already has in order to animate looking for it, which REQ-LAUNCH-002
forbids. Staleness is conveyed by the stale color and the clock symbol
(REQ-LAUNCH-004), never by making the driver wait. The refresh that follows the
hand-off is shown by the Status screen's own checking affordance, not by the
cold-start overlay. RD-15B (`1493281`) already behaves this way; this text
records the rule rather than asking for a change.

### REQ-LAUNCH-004 — Stale cache is never green

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given only a stale cached status exists at launch\
When the transition plays\
Then it uses the stale color and clock symbol, never the clear color

### REQ-LAUNCH-005 — Reduce Motion and accessibility

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P1

Given Reduce Motion is on, or VoiceOver is running\
When the app launches\
Then there is no sweep or spring (200 ms cross-fade only), the overlay ignores touches and is hidden from accessibility, and focus lands on the Status hero when it ends
