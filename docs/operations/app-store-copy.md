# App Store copy

Moved from the core so product intent stays small. Each release note carries the
What's New text and the review notes for that release; this file carries the
fields that persist between releases.

Alert wording belongs in the description and keywords, never in the app name.

## Current fields — 3.0

| Field | Copy |
| --- | --- |
| Name | DriveCheckUA |
| Subtitle (≤30) | Regional alerts for CarPlay |
| Promotional text (≤170) | Your region's air raid alert status at a glance, on CarPlay and iPhone. Redesigned in 3.0: status and the alert map on one screen, following your location. (uk and ru: [releases/3.0.md](releases/3.0.md)) |
| Keywords (≤100) | carplay,alert,region,status,ukraine,driver,widget,siri,utility,notice |
| Support URL | https://github.com/vil4max/regional-check/issues |
| Privacy Policy URL | https://vil4max.com/regional-check/privacy-policy |
| Primary CTA | Get Started |

## Description — in App Store Connect

What App Store Connect holds on 2026-09-21. Only this wording was changed that day: the region is the one the user is in, not a selected one,
and in Ukrainian and Russian the app is "not navigation" rather than "not a map"
(3.0 has an alert map).

Since 2026-10-20 the legal pages live on vil4max.com. The live description and
3.2.0 still carry the retired `vil4max.github.io` links, which no longer
resolve; the next version's description MUST use the links below. The Privacy
Policy URL field is already changed and ships with the next version.

English (U.S.):

```
Drive Check provides a clear, glanceable view of the current alert status for the region of Ukraine you are in. The app combines deterministic regional status data with concise country-level context, while keeping critical alert state and freshness information easy to identify. Features include regional status, CarPlay support, widgets, Live Activities, manual refresh, and localized interface support.

Terms of Use: https://vil4max.com/regional-check/terms-of-use
Privacy Policy: https://vil4max.com/regional-check/privacy-policy
```

Ukrainian and Russian carry their own texts; the edited sentences read "…чи
оголошена повітряна тривога в регіоні, де ви зараз перебуваєте… це не
навігація…" and "…объявлена ли воздушная тревога в регионе, где вы сейчас
находитесь… это не навигация…".

## Description — proposed English replacement, not in App Store Connect

Written for 3.0, its Pro paragraph amended for 3.2, and not yet applied; it would replace the English text above. Its privacy sentence was corrected on 2026-09-21: the region
comes from MapKit reverse geocoding, a network service, so the location does not
stay on the device — it is only never sent to the developer or the data provider.

```
Drive Check brings regional alert status to CarPlay and iPhone, answering one
question at a glance: is your region under alert?

Open the app or CarPlay, see whether your current region is under alert, and
get back to driving. The status is glanceable — not a live map to navigate by,
not a notification feed, and it does not track you in the background.

What you get
• Current-region status on CarPlay and iPhone
• A region that follows your location — nothing to pick or pin
• Alerts in neighbouring regions, shown with your own status
• Alert map as a reference image on iPhone, loaded on demand and
  never on a timer; tap it for every region's status
• Live Activity on the Lock Screen and in the Dynamic Island for the length of
  an alert, until the app or CarPlay sees the all-clear
• Home Screen status widget
• Siri and Shortcuts status check
• Control Center control

Important
Alert data is informational only. Do not rely on it for critical safety
decisions, and do not use the map for navigation — it is a reference image, not
turn-by-turn guidance. Always follow official instructions and local
authorities.

Privacy
Location is used only while the app is in use, to resolve your region with
Apple's MapKit, and it is never sent to the developer or to the alert data
provider. No accounts. No ads. No third-party analytics SDK.

Drive Check Pro is an optional one-time purchase that changes only the look:
the Pro app icon, a crown badge and a gold tab accent. Every feature above is
free. An earlier Drive Check Pro subscription keeps renewing through your Apple
ID until you cancel it in Settings → Apple ID → Subscriptions, and includes the
same look while it is active.
```

The description presents one feature list with no free and paid split, and does not
announce that formerly paid features are free. The Pro paragraph names the purchase
as cosmetic so that no listed feature reads as paid
([ADR 0016](../decisions/0016-cosmetic-pro.md)), and keeps the subscription sentence
because subscribers of the earlier products exist.

## Rules the copy follows

- Never "alert monitor": the app shows regional alert status; it does
  not monitor (`docs/core.md`, Never).
- The map is a reference image from the provider, never navigation — the phrase
  is identical on iPhone and CarPlay so App Review sees one claim.
- The current region's alert status, and the map picture of it, are free on
  every surface; the copy never implies otherwise.
- The screenshot set is English only. What's New and
  the promotional text ship in `en`, `uk` and `ru`; the other
  store fields stay English.

Release-specific copy: [3.2 review notes](releases/3.2.md#app-review-notes),
[3.0](releases/3.0.md#whats-new),
[2.0](releases/2.0.md#asc-copy-20--english-us).
