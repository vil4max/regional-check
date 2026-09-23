# Fold glass on Home

A lab effect on the phone's Status (Home) screen, allowed by the lab clause of
[core](../core.md) (owner, 2026-09-18). Epic, slices and the reference demo:
[backlog, "Epic: Fold glass on Home"](../planning/backlog.md).

The interface stays on the plane it had when Home appeared. Tilting the phone shows that plane
through frosted glass: turned by perspective against the tilt, blurred and dimmed in proportion
to the gap. Code: `RegionalCheck/FoldGlass/`. It is drawn with SwiftUI's own rotation, blur
and dim; a Metal shader waits for the Metal Toolchain component (owner, 2026-09-23).

Constraints for every requirement below: phone only, never a CarPlay surface (P1 Driver
attention; CarPlay is template-based and cannot draw it); no new data and no network traffic;
no third-party dependency.

## Requirements

### REQ-FG-001 — A Details switch, on by default

Status: approved — owner, 2026-09-23 ("Setting, default on"; plan approval the same day)

Core: P3

Given the driver has never touched the fold glass switch\
When Home is shown\
Then the effect is on; the "Tilt Status under glass" switch on Details turns it off and on, the
choice is kept across launches, and a switched-off Home is drawn exactly as without the effect

### REQ-FG-002 — Reduce Motion always turns it off

Status: approved — owner, 2026-09-23 ("Reduce Motion always turns it off"; plan approval the same
day)

Core: P2

Given Reduce Motion is on\
When Home is shown\
Then Home is flat whatever the switch says, and the switch keeps the driver's own choice for when
Reduce Motion is off again; Home is also flat while the cold-start overlay hands over its hero and
while the app is not active

### REQ-FG-003 — Without motion data Home is flat

Status: approved — owner, 2026-09-23 ("Flat interface", for the no-motion case; plan approval
the same day)

Core: P3

Given the device reports no motion (the simulator, or motion unavailable), no sample has arrived
yet, or motion has stopped\
When Home is shown\
Then Home is drawn exactly as without the effect: no rotation, no blur, no dim; the first sample
is the zero pose, so Home starts flat however the phone is held, and tilts under 1° count as
sensor noise

### REQ-FG-004 — The status stays readable at every tilt

Status: approved — owner, 2026-09-23 ("Never — clamp the tilt", for whether the effect may make the
status text unreadable; plan approval the same day)

Core: P2

Given the fold glass is on\
When the phone tilts by any angle around the screen's vertical axis\
Then the interface turns against the tilt by at most 18°, and blur and dim grow with the angle
but never pass their ceilings (2 pt blur, 18 % dim), so the status hero stays readable; the
vertical axis follows the interface orientation, and a roll across ±180° is measured the short way

The ceilings are a first estimate; the TestFlight device pass confirms them on real text. Lowering
them needs no owner round; raising them does.
