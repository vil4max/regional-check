# UI-simplify: a calm, built-in look for Status, Details and onboarding

## Request

Owner, 2026-11-10: the app must be calm and informative, never frightening or nagging, and should
look and behave like a built-in iOS app. Use Apple's own wording and system defaults, and invent no
labels or design. The owner reviewed screenshots of the PR #29 build and approved the
simplification proposal in full ("All of it"), with the two-group Details layout of the mockup:
"Alerts" and "Notifications".

## Goal

Status, Details and onboarding drop the motion, warning glyphs and custom chrome that read as
alarm or as a custom design, and use the system's own patterns instead: a static status symbol,
plain rows, an inset-grouped Settings list and Apple's welcome sheet. Behaviour does not change,
except that a failed map is hidden instead of showing an error card.

## Acceptance criteria

Status:

- **AC-1** The hero shows the status symbol in the status colour, still: no radar beam, no lit
  ticks, no tick ring and no repeating symbol effect, at every status. Its frame keeps the
  current sizes, so REQ-SURF-012 (the glow reaches the top) and REQ-SURF-013 (compact hero first)
  hold unchanged.
- **AC-2** When a neighbouring region is under alert (REQ-SURF-005), Status shows a plain row
  "Nearby" with the region names as its value, with no warning glyph and no sentence. The names
  are the CarPlay nearby line's names (`NearbyAlertsLine.names`); CarPlay does not change.
- **AC-3** With a snapshot, Status shows the row "Regions under alert" with the value "N of 25"
  and a chevron; tapping it opens the region list. The map image carries no caption.
- **AC-4** A map that failed to load is hidden: no error text and no "Refresh map" button. A pull
  to refresh retries a failed map (one request, the same one the removed button sent); a loaded
  map is never re-requested by the pull (REQ-REFRESH-001, REQ-PROVIDER-002).

Details:

- **AC-5** Details is a system `List` in the inset-grouped style, with Section headers and
  footers and no leading row icons.
- **AC-6** The "Alerts" section holds the "Live Activities" switch (Apple's Settings label); its
  explanation is the section footer. The system-off note and Open Settings stay (REQ-SURF-008).
- **AC-7** The "Notifications" section holds the "Alerts in My Region" switch and the three rows
  mirroring iOS's notification settings from ALERT-push (Allow Notifications, Time Sensitive
  Notifications, Notification Delivery, with "Immediate" or "Scheduled Summary" as the delivery
  value); what is sent to the server is the section footer (REQ-PUSH-006).
- **AC-8** The last section holds Drive Check Pro (when offered or owned), Restore Purchases as a
  tinted button row, Manage Subscription (when subscribed) and "Data Source · Ubilling ›"; the
  disclaimer and the version form its footer. The disclaimer keeps its full REQ-PROVIDER-003
  wording (owner, 2026-11-10).

Onboarding:

- **AC-9** Onboarding is Apple's welcome-sheet pattern: the large title "Welcome to Drive Check",
  three feature rows with SF Symbols in the tint colour ("CarPlay", "Follows Your Location",
  "Free"), and one "Continue" button pinned at the bottom, reachable at every text size.

All:

- **AC-10** Every new or changed string exists in English, Ukrainian and Russian; a label that
  Apple uses in iOS 27 takes Apple's translation, and its String Catalog comment names the bundle
  and key (applelocalization.com, iOS 27.0.1 24A446).

## Out of scope

- CarPlay, widgets, the Live Activity and the Control Center control.
- The push controller, the Live Activity session and the map loading policy beyond AC-4.
- Light mode (the app is dark-only).

## Decisions

- Owner, 2026-11-10: the simplification proposal is approved in full ("All of it"), Details in the
  two-group version ("Alerts" and "Notifications").
- Owner, 2026-11-10: the disclaimer keeps its full wording ("Keep it full"); REQ-PROVIDER-003 is
  unchanged.
