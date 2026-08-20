# Release 2.0 checklist

Status: Historical release record. This document is not the current roadmap or version source of truth.

Unified **2.0** release: audit remediation phases 0–8.

## What ships

- Region domain (25 oblasts + Kyiv), adaptive refresh, tabbed phone UI
- `DriveCheckKit` SPM + App Group `SharedStore`
- Status widget, secondary region widget (Pro), Control Center control
- App Intents / Siri shortcuts with optional region parameter
- Pro: extended detail, widget refresh, secondary pin, alternate icon
- Privacy manifests, Ubilling data disclaimer

## Before Archive

1. **Developer Portal:** App Group `group.vil4max.RegionalCheck` on app + widget extension IDs; reissue provisioning profiles.
2. **App Store Connect:** Subscription products Ready and linked to version **2.0**.
3. **Versions aligned:** `MARKETING_VERSION = 2.0`, `CURRENT_PROJECT_VERSION = 1` on app + extension.
4. **Alternate icon:** `AppIcon-Pro` 1024×1024 asset in place (crowned sun / gold road).
5. **Screenshots:** Recapture after tabbed UI (`scripts/capture-app-store-screenshots.sh`).
6. **Review notes:** paste from **ASC copy (2.0)** below.
7. **Privacy Policy URL:** `https://vil4max.github.io/regional-check/privacy-policy.html` (not vil4engineering — that host 404s).
8. **App Privacy:** declare Precise Location (when in use) — not “Data Not Collected”.

## ASC copy (2.0) — English (U.S.)

Paste into App Store Connect → iOS App Version 2.0.

### Subtitle (≤30)

```
Regional alerts for CarPlay
```

### Promotional Text (≤170)

```
Glanceable regional alert status on CarPlay — open, check, drive on. Widgets and Pro extras in 2.0.
```

### Description

```
DriveCheckUA brings regional alert status to CarPlay, helping drivers stay informed without handling their phone.

Open the app on CarPlay or iPhone, see whether your current region is all clear or alert-active, and get back to driving. Status is glanceable — not a map, not a notification monitor, and not a background tracker.

What’s free
• Current-region status on CarPlay and iPhone
• Follow location or pin a region manually
• Regions list with live statuses
• Home Screen status widget
• Siri / Shortcuts status check
• Control Center control

Drive Check Pro (optional subscription)
• Session Live Activity on Lock Screen and Dynamic Island while the app or CarPlay is active
• Extended source detail
• Widget refresh and richer detail
• Pin a secondary region
• Alternate Pro app icon

Important
Alert data is informational only. Do not rely on it for critical safety decisions. Always follow official instructions and local authorities.

Privacy
Location is used only while the app is in use to resolve your region. Location stays on device. No accounts. No ads. No third-party analytics SDK.

Subscriptions are billed through your Apple ID and renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel in Settings → Apple ID → Subscriptions.
```

### What’s New in This Version

```
Drive Check 2.0

• Regions tab with live statuses across Ukraine
• Home Screen widgets and Control Center control
• Siri / Shortcuts status checks
• Smarter location follow with clearer region switching
• Drive Check Pro: session Live Activity, extended detail, secondary region pin, alternate icon

Core current-region status stays free on CarPlay and iPhone.
```

### Keywords (≤100 chars)

```
carplay,alert,region,status,ukraine,driver,widget,siri,utility,notice
```

### Support URL

```
https://github.com/vil4labs/regional-check/issues
```

### Privacy Policy URL (App Privacy)

```
https://vil4max.github.io/regional-check/privacy-policy.html
```

### Review Notes

```
DriveCheckUA is a glanceable CarPlay / iPhone utility for regional alert status (informational only — not a background monitor).

No account / no sign-in.

Pro (StoreKit): regioncheck.pro.monthly and regioncheck.pro.yearly unlock session-scoped Live Activity (ends when the phone backgrounds unless CarPlay is connected), extended source detail, widget extras, secondary region pin, and alternate icon. Core current-region status remains free.

Restore Purchases is on the paywall. Symbolic demo pricing.

Location: when-in-use only, on-device reverse geocode for region selection.
```

## Validation

```bash
just verify
```

Manual: widget after reboot, Siri phrase without prior shortcut setup, CarPlay source line when Pro, icon switches to AppIcon-Pro when Pro unlocks and reverts on lapse.
