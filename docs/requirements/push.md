# All-clear push

An opt-in notification on the iPhone when the air-raid alert in the driver's region ends, sent by
the Drive Check server (drivecheck-api). Spec and plan: [`specs/ALLCLEAR-push/`](../../specs/ALLCLEAR-push/).
Decision: the owner approved storing a device token and a region on the server on 2026-11-09.
The push is free (ADR 0016). Since ALERT-push (owner, 2026-11-10) the same switch also covers a
time-sensitive notice when an alert starts, and the server starts, updates and ends the Live
Activity by push (REQ-PUSH-008, REQ-PUSH-009).

Naming amendment, 2026-11-10 (owner: «и это уже не детали а настройки»; UI-simplify AC-12): the
phone's second tab, called Details in the requirement texts below, is now the **Settings** tab.
Wherever a requirement here says "Details" or "the Details tab", read "Settings"; the behaviour
is unchanged.

Server-side rules (a confirmed alarm → clear change only, the 10-minute gap rule, batches within
the free Workers limits) are verified in drivecheck-api's own spec and tests; this file holds what
the app does.

### REQ-PUSH-001 — Opt in registers the token and the region

Status: approved

Core: P2

Given the driver switches on the all-clear notice on Details and allows notifications\
When iOS returns a device token\
Then the app tells the server the token and the current region, once, and again when the token, the region or the language changes, and, on each launch or foreground, when the last registration is a week old, so the server's 60-day expiry never drops a device the app still runs on

### REQ-PUSH-002 — The server pushes only on a confirmed change

Status: proposed — approved by the owner on 2026-11-10 for drivecheck-api, where it is enforced and tested (its spec 003); it stays proposed here because no app test can prove server behaviour

Core: P2

Given the feed is fresh and a region's previous confirmed status was an alarm seen at most 10 minutes earlier\
When the feed shows the region clear\
Then each opted-in device of that region gets one notification; a stale, failing or unknown feed, a cold start or a longer gap sends nothing (REQ-SURF-009)

### REQ-PUSH-003 — Switching off makes the server forget

Status: approved

Core: P2

Given the notice is on\
When the driver switches it off\
Then the app deletes the token on the server, and a delete that fails offline is retried on the next foreground

### REQ-PUSH-004 — Only a region location confirmed is registered

Status: approved

Core: P2

Given the region is only the Kyiv fallback of a first launch, or the driver is outside Ukraine\
When the app would register the region\
Then it registers nothing until location has confirmed a region inside Ukraine, and the Details caption says the notice is for the last region the app saw

### REQ-PUSH-005 — The switch follows the system permission

Status: approved

Core: P2

Given iOS refuses notifications, at opt-in or later in Settings\
When Details is shown\
Then the switch reads off, the app deletes the token, and a note with an Open Settings button says why

### REQ-PUSH-006 — Only four fields leave the device

Status: approved

Core: P2

Given the app registers a device\
When it sends the request\
Then the body holds exactly the token, the region code, the APNs environment and the language (en, uk or ru), and no location, account or identifier; the server adds only the time it last heard from the device, and drops a token not refreshed for 60 days

Amendment, ALERT-push (owner, 2026-11-10, proposed with REQ-PUSH-009): the Live Activity record is a
second request with the same rule, its tokens in place of the device token: the push-to-start
token, the region code, the APNs environment, the language and, while an activity runs, its update
token.

### REQ-PUSH-007 — Every string in three languages

Status: approved

Core: P3

Given a string of the all-clear switch\
When the String Catalog is read\
Then it has English, Ukrainian and Russian text

### REQ-PUSH-008 — Alert start and a server-driven Live Activity

Status: approved — owner, 2026-11-10; the server half is enforced and tested in drivecheck-api, the app side (holding a push-started activity, the green end with a 5-minute dismissal) is specified in [ALERT-push](../../specs/ALERT-push/spec.md) and tested here

Core: P1, P2

Given a confirmed alarm in the region (fresh feed, a clear status seen at most 10 minutes earlier)\
When the server polls\
Then opted-in devices get one time-sensitive notice ("Air raid alert: <region>"), the Live Activity starts in red by push, it is updated every 5 minutes at low priority with a stale date 15 minutes after its check, and at a confirmed all-clear it turns green, the all-clear notice is sent, and it ends with a dismissal 5 minutes later (owner, 2026-11-10)

Calm by default (owner, 2026-11-10): every push plays Drive Check's own short sound
(`drivecheck.caf`). The alert-start notice and the Live Activity alert are sent as
`time-sensitive` and the all-clear as `active`; whether a time-sensitive push breaks through Focus
is the driver's iOS setting, which Details mirrors with the delivery and permission settings, in
Apple's own words, each row opening the app's notification settings (ALERT-push AC-12..AC-15). The
app has no urgency switch and sends no extra field.

### REQ-PUSH-009 — Every Live Activity can be ended by the server

Status: approved — owner, 2026-11-10; tested by name

Core: P1

Given Live Activities are allowed (the Details switch and iOS), whatever the notice switch\
When ActivityKit hands the app a push-to-start token or the update token of a running activity\
Then the app sends the server that token with the region, environment and language, so an all-clear the app missed still ends the activity (owner, 2026-11-10: a stale activity after a missed all-clear)

## Release note (draft; the owner sets the version)

The all-clear notification is new and optional. Switching it on sends the server a push token, the
last region the app saw, the language and the build environment; the server keeps them with the time
it last heard from the device and deletes a token not refreshed for 60 days. The privacy manifest
now lists coarse location (the region) and device ID (the token) as collected for app functionality,
not linked and not used for tracking. The app's earlier statement "the app has no server of its own"
([3.0 release note](../operations/releases/3.0.md)) no longer holds for this switch. App Store
Connect: update the App Privacy answers (Coarse Location, Device ID), add the Push Notifications
capability to the App ID, and mention the opt-in switch in the review notes.

ALERT-push adds: the switch now also sends a time-sensitive notice when an alert in the region
starts. While Live Activities are on (the Details switch and iOS), whether or not notices are on,
the app sends the server the Live Activity tokens Apple issues (push-to-start and the running
activity's update token) with the region, language and build environment, so the server can start
the Live Activity in red at an alert, refresh it every 5 minutes, turn it green at the all-clear
and remove it 5 minutes later. App Store Connect: the Time Sensitive Notifications capability on
the App ID before the build, and the App Privacy answers cover these tokens under Device ID.
