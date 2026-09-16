# Analytics and observability

Drive Check does **not** use a third-party analytics SDK. Observability is **Apple-only**.

## Policy

| Approach | Status |
| --- | --- |
| Third-party analytics (Firebase, Amplitude, Mixpanel, etc.) | **Not used** — forbidden by product charter |
| Apple App Analytics (App Store Connect) | **Primary** product metrics |
| Crash reports (Xcode Organizer / ASC) | **Primary** stability signal |
| TestFlight feedback | **Beta** qualitative input |
| `os.log` / `Logger` in app code | **Local diagnostics only** — not uploaded |
| MetricKit | **Not integrated** — consider only if stability or performance issues appear at scale |

Binding rule in `docs/core.md` (**Never**): no user analytics.

## What Apple covers (sufficient for v1.x)

- Installs, sessions, retention, device breakdown → **App Store Connect → App Analytics**
- Crashes and symbolicated reports → **Xcode Organizer** / ASC crash logs
- Build adoption → TestFlight + production version mix in ASC
- No custom event SDK required for a single-screen CarPlay utility

## App Store Connect privacy labels

Use this checklist when creating or updating the app record. Align labels with actual behavior and `docs/privacy-policy.html`.

### Data collection to declare

| Data type | Collected? | Linked to user? | Used for tracking? | Purpose |
| --- | --- | --- | --- | --- |
| **Precise Location** | Yes (when in use) | No | No | App functionality — resolve region for status display |
| Contact info, identifiers, health, financial, etc. | No | — | — | — |
| Product interaction / analytics events | No | — | — | No analytics SDK |

### Practices

- **Tracking**: No — app does not track users across apps or websites.
- **Third-party network**: App fetches public JSON from Ubilling (`ubilling.net.ua/aerialalerts/`). No account, no user ID, no payload of personal data in that request. Location stays on device for reverse geocoding (Apple MapKit).
- **Privacy Policy URL**: host `docs/privacy-policy.html` (or equivalent) and link in ASC.

### Verification steps (manual, each release)

1. App Store Connect → **App Privacy** → confirm labels match the table above.
2. Compare with **Info.plist** `NSLocationWhenInUseUsageDescription` (when-in-use only).
3. Confirm no new SDKs were added that collect data (no analytics, no ads).
4. After a TestFlight build, spot-check **App Analytics** and **Crashes** in ASC.

## MetricKit (future, optional)

Do **not** add MetricKit preemptively. Revisit only if:

- Crash-free rate drops and Organizer reports are insufficient
- Users report hangs, battery drain, or CarPlay disconnects tied to performance
- Scale grows enough that aggregated performance metrics are needed without user-level tracking

If added later, prefer **MetricKit only** (no third-party SDK) and update this doc plus App Privacy labels if new diagnostic categories apply.

## Related docs

- Product constraints: `docs/core.md`
- Network / refresh behavior: `docs/requirements/aerial-alerts-provider.md`
- Public privacy policy copy: `docs/privacy-policy.html`
