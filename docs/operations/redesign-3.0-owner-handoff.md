# Drive Check 3.0 — release preparation

Written by drivecheck-product. Release preparation is its own block of work
(owner, 2026-09-18: "это отдельный блок работы, называется подготовка к
релизу"). Everything below the line has to exist *before* it starts; then a
release agent, with App Store Connect opened for it, does the upload and the
submission. The owner's own acts are four, listed in section 1b.

## 1a. Entry conditions — release preparation does not start until all of these hold

| Condition | Owner | Done when |
|---|---|---|
| Every redesign task landed on `main` | drivecheck-product | The board shows no open implementation card; RD-6 is the last one |
| RD-14 texts final | drivecheck-release → drivecheck-product lands them | `docs/operations/releases/3.0.md`, the `[3.0]` section of `CHANGELOG.md`, `app-store-copy.md` and the App Review notes carry no `[PENDING]` row |
| The English screenshot set recaptured and reviewed | drivecheck-release captures, drivecheck-product reviews | One pass after RD-6, with `about` and `paywall` live rather than skipped; the 2026-09-17 set is not used |
| Catalogs complete | RD-11 | `catalogsHaveNoMissingTranslations` green; no key en-only, none stale in meaning |
| RD-17 regression green | drivecheck-qa | Its checklist has a result per item, with evidence, and `just verify` plus the `main` CI run are green on the candidate commit |
| The manual pass done on a TestFlight build | **owner** | Section 2, with anything that fails routed back to drivecheck-product |

A failure in any row sends the work back to the session that owns it, not
forward with a note.

## 1b. What the owner does, and nothing more

1. **Tag the TestFlight request.** `just tf-check` on the candidate commit,
   then `git tag -a tf-3.0.0-N -m "<what to test this round>"` and
   `git push origin tf-3.0.0-N`. The annotation becomes What to Test. `N` counts
   TestFlight rounds of 3.0.0 from 1. Only the owner creates these tags.
2. **Run the manual pass** (section 2) on the build that appears for the
   Friends&Family group. This is the step no automation replaces.
3. **Open App Store Connect for the release agent**, once the pass is clean.
4. **Create the `v3.0.0` marker** on the submitted commit, after submission. It
   requests no build; it records what went to Review. Before that, **delete the
   old `v3.0.0`** — it still points at `55621e5`, a build that was never
   submitted, and the owner ruled on 2026-09-18 that it goes rather than moves.
   Deleting a tag locally and on `origin` is owner-only; the commands are in
   `release-process.md`'s remediation table.

## 1c. What the release agent does, with App Store Connect open

Model taken from the OneCart project (owner, 2026-09-18). The agent is
drivecheck-release, and its authority is limited to the submission itself:

- Mark the pre-redesign 3.0.0 candidate "do not submit" if it is still
  submittable, and confirm the new build's number lands above it.
- Upload the reviewed English screenshot set.
- Paste the What's New text and the App Review notes from RD-14.
- Select the TestFlight build produced by the `tf-` tag and submit it for review.

Not the agent's, at any point: pricing and availability, subscription
configuration, account or team settings, responding to a review rejection,
deleting or expiring builds, and anything involving credentials — the owner's
password manager or the owner does those. The agent stops and reports rather
than improvising if a screen asks for something outside this list.

Not on any list because no session can do it: RD-15C, the layered Icon Composer
icons. Icon Composer is GUI-only, so those icons are the owner's whenever they
are wanted; 3.0.0 ships without them.

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
