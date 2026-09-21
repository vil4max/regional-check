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
| Promotional text (≤170) | Your region's alert status at a glance on CarPlay and iPhone. Simpler in 3.0: two tabs, the alert map on the main screen, and a region that follows your location. (uk and ru: [releases/3.0.md](releases/3.0.md)) |
| Keywords (≤100) | carplay,alert,region,status,ukraine,driver,widget,siri,utility,notice |
| Support URL | https://github.com/vil4max/regional-check/issues |
| Privacy Policy URL | https://vil4max.github.io/regional-check/privacy-policy.html |
| Primary CTA | Get Started |

## Description — English (U.S.)

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
• Alert map as a reference image, on CarPlay and iPhone, loaded on demand and
  never on a timer; tap it on iPhone for every region's status
• Session Live Activity on the Lock Screen and in the Dynamic Island while the
  app or CarPlay is active
• Home Screen status widget
• Siri and Shortcuts status check
• Control Center control

Important
Alert data is informational only. Do not rely on it for critical safety
decisions, and do not use the map for navigation — it is a reference image, not
turn-by-turn guidance. Always follow official instructions and local
authorities.

Privacy
Location is used only while the app is in use, to resolve your region, and it
stays on the device. No accounts. No ads. No third-party analytics SDK.

An existing Drive Check Pro subscription keeps renewing through your Apple ID
until you cancel it in Settings → Apple ID → Subscriptions; version 3.0 sells no
subscription.
```

The description presents one feature list with no free and paid split, and does not
announce that formerly paid features are free (owner, 2026-09-20). The last paragraph
stays because subscribers exist and the products remain in App Store Connect
([ADR 0014](../decisions/0014-hide-pro-for-3-0.md)); whether it should stay is the
owner's call at submission.

## Rules the copy follows

- Never "alert monitor": the app shows regional alert status; it does
  not monitor (`docs/core.md`, Never).
- The map is a reference image from the provider, never navigation — the phrase
  is identical on iPhone and CarPlay so App Review sees one claim.
- The current region's alert status, and the map picture of it, are free on
  every surface; the copy never implies otherwise.
- The screenshot set is English only (owner ruling, 2026-09-17). What's New and
  the promotional text ship in `en`, `uk` and `ru` (owner, 2026-09-20); the other
  store fields stay English until the owner reopens them.

Release-specific copy: [3.0](releases/3.0.md#whats-new),
[2.0](releases/2.0.md#asc-copy-20--english-us).
