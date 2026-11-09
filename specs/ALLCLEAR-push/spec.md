# ALLCLEAR-push: an "all clear" push when the alert in the driver's region ends

## Request

Owner, 2026-11-09, via the orchestrator brief: "All clear" push when the alert in the owner's region
ends. It is sent from the existing free drivecheck-api (Cloudflare Worker, Durable Object, Cron or
alarm, APNs JWT). Storing the device token and region is approved by the owner, and that changes the
README's "Never" rule in drivecheck-api. Start with a spike: can a Worker send to APNs within the
Free plan limits of 50 subrequests and 10 ms CPU per run? The APNs key is the owner's: he creates
and stores it himself.

## Goal

A driver who opted in gets one notification on the iPhone when the air-raid alert in their region
ends, without opening the app. Nothing else is pushed: no alert-start push, no history, no account.
The app stays free and the signal stays honest (core P2).

## Spike result (2026-11-09, before the plan)

| Question | Finding | Source |
|---|---|---|
| Free subrequests per invocation | 50; each push to APNs is one, the feed fetch is one | Cloudflare Workers limits page |
| Free CPU per invocation | 10 ms of active CPU; waiting on fetch does not count | same page |
| CPU limit of a Durable Object alarm on Free | Not resolved: the Durable Objects page says 30 s by default, the Workers page says 10 ms for Free | both pages |
| ES256 JWT signing cost | about 0.06 ms per signature (Node WebCrypto, 200 runs; not measured in workerd) | local timing |
| Alarms and cron on Free | Durable Object alarms: one per object, plan availability not stated; Cron Triggers: 5 per account, 10 ms CPU | same pages |
| Can `fetch` speak HTTP/2 to APNs and what APNs requires | Not verified: Apple's pages did not render for the fetch tool | none; needs the owner's key |

Consequences: at most about 48 pushes per invocation, so a batch must be spread over several
invocations; signing is not the bottleneck; whether the Worker reaches APNs at all and which CPU
limit an alarm gets can only be proved with a real send, which needs the owner's APNs key.

## Acceptance criteria

- **AC-1** Given an opted-in device whose region goes from alarm to clear in the feed, then it gets
  one notification "all clear" for that region, and none for a region that was already clear.
- **AC-2** Given a feed that is stale, rate limited or failing, then no all-clear push is sent: only
  a confirmed alarm-to-clear change sends (the rule of REQ-SURF-009).
- **AC-3** Given the driver turns the setting off, then the server forgets the device token and
  region, and iOS stops asking for permission again.
- **AC-4** Given APNs answers that a token is invalid or unregistered, then the server deletes it.
- **AC-5** Given one change touches more devices than one invocation can send, then the rest is sent
  by following invocations, each within 50 subrequests, and no device gets two pushes for one change.
- **AC-6** The server stores only a device token and a region code per device, no alert history, no
  account, no location; the privacy policy, core, the release note and drivecheck-api's README say so.
- **AC-7** Every new user-visible string exists in English, Ukrainian and Russian.

## Out of scope

- An alert-start push, other threat types (needs a personal token), Live Activity push updates,
  a push for neighbouring regions.
- Creating, rotating or storing the APNs key (the owner's), App Store Connect changes.
- Any use of the push to sell Pro.

## Decisions

- Owner, 2026-11-09: storing the device token and region on the server is approved.
- Collisions (`core.md:25` "not notifications", `core.md:41` "Never", REQ-SURF-009 "rejected for now:
  a server ... APNs", the privacy policy, release note 3.0) are settled in the plan.
