# Debugging the server-driven Live Activity

Status: draft (BUG-LA-push-start, Group 1). Completed after the device runs of Group 3.

How to check, step by step, that a push from drivecheck-api starts, updates and ends the Drive Check
Live Activity, and where each step leaves evidence. The contract is ALERT-push
([spec](../../specs/ALERT-push/spec.md), REQ-PUSH-008, REQ-PUSH-009).

## The path and its evidence

| Step | Who | Evidence |
| --- | --- | --- |
| 1. The app gets a push-to-start token and sends its record (`PUT /v1/push/live-activity`) | App | App log, category `Push`: `live activity record sent`, or the reason it was not sent |
| 2. The server sees a confirmed alarm in the record's region and queues `start` | Server | Worker log: `push alarm: alert started in <region>` |
| 3. APNs accepts or refuses the request | Server | Worker log: `push batch: …` or `push refused: <status> <reason>` |
| 4. iOS starts the activity | Device | `liveactivitiesd`, `chronod` and `apsd` in Console.app |
| 5. The app wakes, holds the activity and sends its update token | App | App log, category `LiveActivity`: `new activity: held`, then `Push`: `live activity record sent, with activity token: true` |

None of these logs holds a token. A Debug build prints its push-to-start token, and only a
Debug build does.

## Logs

Worker, live only (the Worker keeps no log history):

```bash
npx wrangler tail drivecheck-api --format pretty --search push
```

The device, in Console.app with the iPhone selected, "Start streaming", filter on any of:

```text
process:liveactivitiesd
process:chronod
process:apsd
subsystem:vil4max.RegionalCheck
```

Simulator:

```bash
xcrun simctl spawn booted log stream --style compact --predicate 'process == "liveactivitiesd" OR process == "chronod" OR process == "apsd" OR subsystem == "vil4max.RegionalCheck"'
```

## Sending a Live Activity push by hand

`xcrun simctl push` cannot do this. It sends only application remote notifications ("Only
application remote push notifications are supported"; measured 2026-11-12, Xcode 27), and a
payload sent to the `.push-type.liveactivity` topic lands as a plain notification.

Use APNs sandbox with Apple's Push Notifications Console instead
([Apple: test Live Activity updates locally](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications#Test-Live-Activity-updates-locally);
a simulator needs an Apple silicon Mac):

1. Run a Debug build on the simulator. **Do not grant location**: without a location-confirmed
   region the app sends no record, so the test never writes to the production server.
2. Copy the `push-to-start token: …` line from the Xcode console.
3. Put the app in the state under test (see "App states") and start the log stream.
4. In the Push Notifications Console: environment Development, the app's bundle ID, push type
   Live Activity, priority 10, the token, and one of the payloads below with `timestamp`,
   `stale-date` and `checkedAt` set to now.

`start`, exactly as the server sends it (`src/push/liveActivity.ts` `startPayload`). `timestamp`
and `stale-date` are Unix seconds; `checkedAt` is seconds since 2001-01-01, Foundation's
reference date:

```json
{
  "aps": {
    "event": "start",
    "timestamp": 1794830400,
    "attributes-type": "DriveCheckActivityAttributes",
    "attributes": {},
    "input-push-token": 1,
    "stale-date": 1794831300,
    "interruption-level": "time-sensitive",
    "alert": { "title": "Air raid alert: Kyiv", "sound": "drivecheck.caf" },
    "content-state": {
      "phase": "alarm",
      "regionTitle": "Kyiv",
      "checkedAt": 816523200,
      "sourceLabel": "Alert feed",
      "isStale": false
    }
  }
}
```

Variant B is the same with `"body": "Test"` added to `alert`, to tell whether a start without a
body is ignored.

The Push Notifications Console refuses the payload above as it is: its schema for the
`liveactivity` push type has no `interruption-level` ("`$.aps.interruption-level: is not defined
in the schema`", 2026-11-12). Remove that key to send it from the console; whether APNs itself
refuses it is an open question of BUG-LA-push-start (H5), answered by the server's
`push refused: la-start <status> <reason>` line.

A simulator that APNs cannot reach shows "discarded as device was offline" in the console's
Delivery Log; such a run proves nothing about the payload.

## App states

Record which one every run used.

- **S1, suspended:** the app was sent to the background and left there.
- **S2, ended by the system:** the device was restarted and the app was not opened since.
- **S3, force-quit:** swiped away in the app switcher. iOS may not wake a force-quit app in the
  background, so the activity can appear without its update token reaching the server.
