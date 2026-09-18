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
| Promotional text (≤170) | One glance answers whether it is safe to drive right now — on CarPlay or iPhone. Redesigned in 3.0, and free on every surface. |
| Keywords (≤100) | carplay,alert,region,status,ukraine,driver,widget,siri,utility,notice |
| Support URL | https://github.com/vil4max/regional-check/issues |
| Privacy Policy URL | https://vil4max.github.io/regional-check/privacy-policy.html |
| Primary CTA | Get Started |

## Description — English (U.S.)

```
Drive Check brings regional alert status to CarPlay and iPhone, answering one
question at a glance: is it safe to drive right now?

Open the app or CarPlay, see whether your current region is under alert, and
get back to driving. The status is glanceable — not a live map to navigate by,
not a notification feed, and it does not track you in the background.

What's free
• Current-region status on CarPlay and iPhone
• Follow your location, or pin a region manually
• Regions list with live statuses and search
• Alert map as a reference image, on CarPlay and iPhone, refreshed on demand
  and never on a timer
• Home Screen status widget
• Siri and Shortcuts status check
• Control Center control

Drive Check Pro (optional subscription)
• Session Live Activity on the Lock Screen and in the Dynamic Island while the
  app or CarPlay is active
• Extended source detail
• Widget refresh and richer detail
• A pinned secondary region
• An alternate Pro app icon

Important
Alert data is informational only. Do not rely on it for critical safety
decisions, and do not use the map for navigation — it is a reference image, not
turn-by-turn guidance. Always follow official instructions and local
authorities.

Privacy
Location is used only while the app is in use, to resolve your region, and it
stays on the device. No accounts. No ads. No third-party analytics SDK.

Subscriptions are billed through your Apple ID and renew automatically unless
cancelled at least 24 hours before the end of the period. Manage or cancel in
Settings → Apple ID → Subscriptions.
```

## Rules the copy follows

- Never "alert monitor": the app answers whether it is safe to drive, it does
  not monitor (`docs/core.md`, Never).
- The map is a reference image from the provider, never navigation — the phrase
  is identical on iPhone and CarPlay so App Review sees one claim.
- The current region's alert status, and the map picture of it, are free on
  every surface; the copy never implies otherwise.
- The store set is English only (owner ruling, 2026-09-17). Whether the What's
  New text also ships in `uk` and `ru` is an open owner decision; the app's own
  strings are fully localized either way.

Release-specific copy: [3.0](releases/3.0.md#whats-new--english),
[2.0](releases/2.0.md#asc-copy-20--english-us).
