# Analytics and observability

Analytics is as mandatory as functionality, and it is Apple-native first
(owner, 2026-09-24, `docs/core.md` "Analytics"). This replaces the earlier
"Never: no user analytics" line, which the owner called early thinking.

## Policy

| Approach | Status |
| --- | --- |
| App Store Connect App Analytics | **Used**: installs, sessions, active devices, retention, version adoption |
| Xcode Organizer and App Store Connect crash, hang, launch and energy reports | **Used**: stability and performance signal |
| TestFlight crash submissions and feedback | **Used**: beta signal |
| App Store Connect API reports (Analytics Reports, Power and Performance Metrics) | **Planned**: pulled by a Runtime script once the owner creates an API key |
| MetricKit in the app | **Not integrated**: its payloads arrive on the device, and the app has no server to send them to; the same aggregated crash, hang and performance data already reaches Organizer and ASC without app code (owner, 2026-09-24) |
| Third-party analytics SDKs (Firebase, Amplitude, Mixpanel, …) | **Not used**: only by an owner decision that names the product question Apple's sources cannot answer |
| `os.log` / `Logger` in app code | **Local diagnostics only**: not uploaded |

## Starting metrics

Each metric answers a product question. Add a metric only together with its question.

| Metric | Product question | Source |
| --- | --- | --- |
| Crash-free sessions and users | Does the app stay up while driving? | Organizer / ASC Crashes |
| Hang rate | Does the Status screen or CarPlay freeze? | Organizer Hangs, ASC Power and Performance |
| Launch time, memory, energy | Do the cold start and the fold glass stay cheap? | Organizer / ASC Power and Performance |
| Adoption: installs, active devices, version mix | Do drivers take up new releases? | ASC App Analytics |
| Retention (day 1, 7, 28) | Do drivers come back to the app? | ASC App Analytics |
| Task success | Does a driver get the status at a glance? | **Not covered** by Apple's aggregate sources; waits for a concrete product question, and its destination is decided then: CloudKit as the Apple option, a third-party service only if Apple is not enough |

HEART is the frame (Happiness, Engagement, Adoption, Retention, Task success);
only adoption and retention have an Apple source today. Happiness is covered by
App Store ratings and TestFlight feedback, not by an app metric.

## App Store Connect privacy labels

The app itself collects nothing for analytics: every source above is Apple's
own reporting. Keep the labels aligned with actual behavior and
`docs/privacy-policy.html`, and revisit both before any in-app metric, MetricKit
upload or SDK lands.

### Data collection to declare

| Data type | Collected? | Linked to user? | Used for tracking? | Purpose |
| --- | --- | --- | --- | --- |
| **Precise Location** | Yes (when in use) | No | No | App functionality — resolve region for status display |
| Contact info, identifiers, health, financial, etc. | No | — | — | — |
| Product interaction / analytics events | No | — | — | The app sends no events; analytics comes from Apple's reports |

### Practices

- **Tracking**: No — app does not track users across apps or websites.
- **Third-party network**: App fetches public JSON from Ubilling (`ubilling.net.ua/aerialalerts/`). No account, no user ID, no payload of personal data in that request. Location stays on device for reverse geocoding (Apple MapKit).
- **Privacy Policy URL**: host `docs/privacy-policy.html` (or equivalent) and link in ASC.

### Verification steps (manual, each release)

1. App Store Connect → **App Privacy** → confirm labels match the table above.
2. Compare with **Info.plist** `NSLocationWhenInUseUsageDescription` (when-in-use only).
3. Confirm no SDK or code was added that collects or uploads data (analytics, ads, MetricKit uploads).
4. After a TestFlight build, spot-check **App Analytics** and **Crashes** in ASC.

## Related docs

- Product constraints: `docs/core.md`
- Network / refresh behavior: `docs/requirements/aerial-alerts-provider.md`
- Public privacy policy copy: `docs/privacy-policy.html`
