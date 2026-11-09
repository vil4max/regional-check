# All-clear push

An opt-in notification on the iPhone when the air-raid alert in the driver's region ends, sent by
the Drive Check server (drivecheck-api). Spec and plan: [`specs/ALLCLEAR-push/`](../../specs/ALLCLEAR-push/).
Decision: the owner approved storing a device token and a region on the server on 2026-11-09.
Nothing is pushed when an alert starts, and the push is free (ADR 0016).

Server-side rules (a confirmed alarm → clear change only, the 10-minute gap rule, batches within
the free Workers limits) are verified in drivecheck-api's own spec and tests; this file holds what
the app does.

### REQ-PUSH-001 — Opt in registers the token and the region

Status: approved

Core: P2

Given the driver switches on the all-clear notice on Details and allows notifications\
When iOS returns a device token\
Then the app tells the server the token and the current region, once, and again only when the token, the region or the language changes

### REQ-PUSH-002 — The server pushes only on a confirmed change

Status: proposed — enforced and tested in drivecheck-api (its spec 003), not in this app

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

### REQ-PUSH-007 — Every string in three languages

Status: approved

Core: P3

Given a string of the all-clear switch\
When the String Catalog is read\
Then it has English, Ukrainian and Russian text
