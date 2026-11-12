# ANALYTICS-need: does Drive Check need product analytics, and how much

Status: decided by the owner on 2026-11-12: option A, no SDK. Nothing is integrated.

## Request

Owner, 2026-11-12: «пора добавлять аналитику постхог», then: «Насчет постхох — это идея, которую
нужно проверить. Нужна ли сейчас аналитика и в каком объеме она нужна, если нужна.»

## Rules that already apply

- `docs/operations/analytics.md`: Apple-native first; a third-party analytics SDK "only by a
  recorded decision that names the product question Apple's sources cannot answer"; `os.log` is
  local only.
- drivecheck-api `AGENTS.md`: product rules include "no third-party analytics".
- App Store Connect App Privacy for 3.3.0 declares Precise Location, Coarse Location and Device ID,
  all "Data Not Linked to You", none for tracking (2026-11-11). Any new collection changes this
  declaration and the privacy policy.
- The repository is public; nothing private goes into it.

## Questions Apple's sources cannot answer today (candidates)

1. Does the Live Activity start by push on users' devices (the BUG-LA-push-start question)? Apple
   gives no per-feature delivery data. A server-side count of `start` sends and APNs answers
   (drivecheck-api spec 005) answers the server half without any SDK.
2. How many users use CarPlay, the Live Activity, notices, Siri? Not in App Analytics.
3. Where do users drop off in onboarding (location, notices)? Not in App Analytics.

## Options (neutral order)

- **A. No SDK: server counters only.** Aggregate counts in drivecheck-api (pushes by kind and
  answer, records per region), no device identifier. No privacy label change. Answers question 1;
  not 2 or 3.
- **B. Privacy-first event counts from the app to drivecheck-api.** A handful of anonymous events
  (feature used, no identifier), aggregated server-side. Small label change ("Product Interaction",
  not linked). Answers 1 to 3 roughly; we own the code.
- **C. PostHog SDK.** Funnels, retention and dashboards out of the box. A third-party SDK and data
  processor, a new App Privacy declaration, a privacy-policy change, a reversal of the two rules
  above (a recorded decision), and a dependency to approve.

## Decision (owner, 2026-11-12)

Option A: aggregate server counters only, no analytics SDK and no device identifier ("Да,
восьмое", answering the agent's lean). drivecheck-api #9 already logs Live Activity starts queued
per region and push outcomes per kind. PostHog, or option B, comes back only with a named product
question that these counters and Apple's sources cannot answer.

## Before the decision

Which question is worth answering now; then the smallest option that answers it. Agent's lean: A
now (it comes with the BUG-LA-push-start diagnostics), B or C only once a named question needs it.
