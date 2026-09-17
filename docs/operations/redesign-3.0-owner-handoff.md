# Drive Check 3.0 redesign — owner hand-off

Written by drivecheck-product for the owner's last mile. Everything on this
page is a step no session may take: tags, App Store Connect, submission, and
the manual pass on a real build. The sessions' side is done when every redesign
task has landed on `main` and RD-17 reports its automated regression green.

Order matters, and it is the order [ADR 0013](../decisions/0013-one-build-pipeline-or-two.md)
left us with: a `tf-` tag is the only build request, the build it produces is
the build that gets submitted, and `v3.0.0` is a marker created afterwards.
Owner ruling, 2026-09-17: the release steps come last, after the code —
"это в самом концу, мануал тестирование".

## 1. Owner steps, in order

1. **Pick the commit.** The head of `main` with every redesign task landed.
   `just tf-check` prints whether that commit can be tagged and the next free
   `BUILD` number. Details and failure modes: [release-process.md](release-process.md).
2. **Mark the old 3.0.0 candidate "do not submit"** in App Store Connect, if it
   is still submittable. The redesign's build number must be above it (Q16).
3. **Tag and push the TestFlight request.**
   `git tag -a tf-3.0.0-N -m "<what to test this round>"` then
   `git push origin tf-3.0.0-N`. The annotation becomes What to Test in App
   Store Connect. `N` counts TestFlight rounds of 3.0.0, starting at 1.
4. **Wait for the build.** The Release/TestFlight workflow moves `testflight`
   to the tag, Xcode Cloud archives it, and it appears for the
   Friends&Family group.
5. **Run the manual pass** in section 2 on that build. Anything that fails goes
   back to me (drivecheck-product) as an item, not to a task session.
6. **Upload the screenshots.** RD-13 prepares the English set locally and hands
   you the files; uploading is yours.
7. **Submit that build** for App Review. The App Review notes (CarPlay map is a
   source image, not navigation; paywall; onboarding claims) are collected in
   RD-14's release note.
8. **Tag `v3.0.0` on the submitted commit**, after submission. It requests no
   build; it records which commit went to Review.
9. **Decide the stale `v3.0.0`.** The tag currently sits on 55621e5, a build
   that was never submitted, so under ADR 0013 it marks something that did not
   happen. Either delete it and re-tag the submitted commit, or leave it as
   history and pick a different marker — your call, and whoever applies it
   rewords ADR 0013's consequences section and `release-process.md`
   invariant 6, which both still assume the tag gets moved. Owner ruling,
   2026-09-17: settled at the end of the work, "это также проставим в конце
   работ".

Not on this list because no session can do them either: RD-15C, the layered
Icon Composer icons. Icon Composer is a GUI-only tool, so those icons are an
owner task whenever you want them; 3.0.0 ships without them unless you make
them.

## 2. Manual pass on the TestFlight build

Derived from `docs/tasks/redesign.md`, `docs/design/redesign/states.md` and the
requirements. Each line is a thing to look at, not a thing to trust.

### Phone — Status

- Clear, alert and stale states: hero ring, disc, symbol and the meta line
  agree with each other; stale never reads as current.
- `Checking…` sweeps and the round button is disabled while it does.
- Pull to refresh and the round Refresh button both produce one visible result.
- Pro off: no PRO chip, no Source label, no "Also watching" row; the crown
  button is still there.
- Location access off: the row above "Alert map" offers Open Settings.
- Region change notice appears as a floating pill with Undo.
- Cold start with a cached status: stale colours and a clock symbol, never
  green (REQ-LAUNCH-*).

### Phone — Alert map

- The "Alert map" row opens the map full screen; the image carries its fetch
  age and the count of regions under alert.
- Loading shows a spinner in the image area; a failure shows the message and
  hint and **not** a previous image.
- "Refresh map" refetches; no polling happens on its own.

### Phone — Regions

- Search finds a region by its Ukrainian, Russian and English name regardless
  of the phone's language — "Kyiv", "Київ", "Киев" all work, and Kyiv returns
  both the city and the oblast.
- No results shows the empty state with its hint, not an empty card.
- An empty ALERT ACTIVE section is hidden rather than drawn empty.
- Follow-location toggle and the manual pin behave as before the redesign.

### Phone — onboarding, About, Paywall, outside Ukraine

- First launch: onboarding claims nothing the app does not do (no navigation,
  no notifications, no monitoring).
- Paywall lists only what Pro actually gates; purchase, restore and a lapsed
  entitlement all end in a sane state.
- Outside Ukraine: the sheet explains the situation instead of showing a broken
  status.

### CarPlay (in the car, or the CarPlay Simulator)

- Status and Details tabs, and the Map tab if RD-9 landed: the map image
  renders, and its fallback is text when the image is missing or stale.
- Rows stay short enough to read at a glance: nearby is at most two names plus
  "+N"; the country row at most three plus "and N more".
- Data does not flicker or re-render more often than it should; a manual
  Refresh always produces a visible result.

### Widgets, Live Activity, Siri

- Home screen widget, Control Center control, Live Activity and Siri answers
  all report the same status as the app at the same moment.
- Stale shows the clock symbol and "last known" wording, never "Updating…".

### Icon and system integration

- The app icon on the Home screen, in Dark appearance, and in Tinted
  appearance; the Pro alternate icon switches and survives a restart.

### What must never happen

- The alarm-vs-clear signal for the current region, or the map picture of it,
  sitting behind the paywall (`docs/core.md`, Never).
- Stale data presented as current anywhere.
- Anything that positions Drive Check as an alert monitor, or the CarPlay map
  as navigation.
- Accounts, ads, history, analytics or social features appearing anywhere.

### Reporting

Send findings to me (drivecheck-product) with the surface and the state. I file
them against the owning task and, if a check should have caught it, add the
lesson and the check. Do not file them into task sessions directly — they do
not hold the epic's state.
