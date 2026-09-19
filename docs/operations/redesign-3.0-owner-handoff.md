# Drive Check 3.0 — release preparation

Written by drivecheck-product. Release preparation is its own block of work
(owner, 2026-09-18: "это отдельный блок работы, называется подготовка к
релизу"). Everything below the line has to exist *before* it starts; then a
release agent, with App Store Connect opened for it, does the upload and the
submission. The owner's own acts are step 0 in section 1b and the four in section 1c.

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

## 1b. Repository hygiene — done, kept as the record

Executed 2026-09-18 by drivecheck-integrator after the owner granted narrow
permission rules for it. Owner ruling: "старые убираем, гит должен быть чистым
и с полезными данными" (remove the old ones, git should be clean and carry
useful data), and, on the frozen branch, "если в ней больше нет необходимости,
то можно сносить. не плодить мусорные артефакты" (if it is no longer needed it
can go — do not breed junk artefacts).

Removed, with the SHA recorded so each is restorable:

| Ref | Was at | Why it went |
|---|---|---|
| tag `v3.0.0` | `55621e5f4f42fd8d1e3516fc436e4c8e0bc8901d` | Marked a 3.0.0 candidate build that was never submitted; under ADR 0013 a `v` tag means "this commit's build went to Review", so it asserted something that did not happen |
| `claude/testflight-publish-logic-ho4h0g` | merged | Merged remote branch |
| `claude/zen-cori-f48f15` | `327ddbe728f1333c27778f47eed8b85e43f5513b` | Merged remote branch — surfaced by the integrator rather than assumed to be live work |

`origin` now carries `main`, `release`, `testflight` and the tags `v1.0.0`,
`v2.0.0`–`v2.4.0`, `v2.7.0`–`v2.9.0`. That is a state anyone can check:
`git ls-remote --heads origin` and `git ls-remote --tags origin`.

Still to remove, verified safe and waiting on the integrator's grant: the
`release` branch. It points at `55621e5`, which is an **ancestor of `main`**, so
deleting the branch loses no commits; no GitHub workflow references it
(`.github/workflows/` mentions `release` only in the marker job's own name); and
the Xcode Cloud workflow that started from it was deleted in App Store Connect
on 2026-09-17 (ADR 0013). The record of what that pipeline built is ADR 0013
itself, not a dangling ref.

Who may run destructive git, precisely, because the earlier draft of this page
said "no session runs them" and that is wrong: the integrator runs it **only**
for an action the owner has granted a permission rule for, and the grants are
narrow — tag deletion and remote-branch deletion. Force push, `reset --hard`
and history rewriting are not granted to any session.

## 1c. What the owner does, and nothing more

1. **Tag the TestFlight request.** `just tf-check` on the candidate commit,
   then `git tag -a tf-3.0.0-N -m "<what to test this round>"` and
   `git push origin tf-3.0.0-N`. The annotation becomes What to Test. `N` counts
   TestFlight rounds of 3.0.0 from 1. Only the owner creates these tags.
2. **Run the manual pass** (section 2) on the build that appears for the
   Friends&Family group. This is the step no automation replaces.
3. **Open App Store Connect for the release agent**, once the pass is clean.
4. **Create the `v3.0.0` marker** on the submitted commit, after submission. It
   requests no build; it records what went to Review. Step 0 has already
   removed the old one, so this name is free.

## 1d. What the release agent does, with App Store Connect open

Model taken from the OneCart project (owner, 2026-09-18). The agent is
drivecheck-release, and its authority is limited to the submission itself:

- Mark the pre-redesign 3.0.0 candidate "do not submit" if it is still
  submittable, and confirm the new build's number lands above it.
- Upload the reviewed English screenshot set.
- Paste the What's New text and the App Review notes from
  [releases/3.0.md](releases/3.0.md) — both are final and need no editing at
  submission time.
- Paste the What's New text and the App Review notes from RD-14.
- Select the TestFlight build produced by the `tf-` tag and submit it for review.

Not the agent's, at any point: pricing and availability, subscription
configuration, account or team settings, responding to a review rejection,
deleting or expiring builds, and anything involving credentials — the owner's
password manager or the owner does those. The agent stops and reports rather
than improvising if a screen asks for something outside this list.

RD-15C, layered Icon Composer icons, remains outside 3.0.0. Its current
[task brief](../tasks/rd-15c-layered-icons.md) records the deferred build
experiment and unresolved compatibility questions. A GUI-only limitation is
not the reason for deferral; this release preserves the existing icon assets.

## 1e. Where this is going: "ship the release"

The owner's target state, 2026-09-18: "в идеале, я говорю агенту который
занимается релизом - выпускай релиз - и он все делает сам" — one instruction to
the release agent, and it does the rest. The first release runs under the
owner's own control, and the automation is designed from what that run shows
("выработаем автоматизацию"), not guessed at beforehand.

So this section is not a list of steps that stay manual forever. It is what has
to be true before a single instruction is safe, and the first run is how we
find out which of these is still missing.

**1. The gate has to be machine-checkable.** Today section 1a is a table a
person reads. For "ship the release" it has to be a command that fails loudly:
texts with no `[PENDING]` row, the reviewed screenshot set present, catalogs
complete (`catalogsHaveNoMissingTranslations` already covers this), RD-17's
checklist with a result per item, `just verify` green, and the candidate
commit's own `main` CI run green. An agent that cannot check the gate cannot be
trusted to start behind one sentence.

**2. The human step has to be located, not removed.** Somebody has to look at
the app on a real build; no check replaces it. That leaves two shapes, and the
first run should tell us which the owner prefers:
- *Two instructions* — "cut a build" (the agent tags `tf-`, waits for
  TestFlight, reports), then, after the owner's pass, "ship it" (upload, paste,
  select, submit).
- *One instruction with the pass as evidence* — the owner's manual pass is
  already done and recorded, and "ship the release" consumes it. This is the
  owner's stated ideal, and it needs the pass to be recorded rather than
  remembered.

**3. The authorization has to be quoted, not inferred.** "Выпускай релиз" is
the owner's authorization for that release, and the agent records it verbatim
the way every approval in this epic is recorded — which release, which commit,
whose words. That is what makes the `tf-` tag and the `v` marker the agent's to
create in this model: not a policy the agent decided, but an instruction the
owner gave and the log can show.

**4. Irreversible steps still print before they act.** Submitting to App Review
reaches real users and cannot be taken back, so the agent states what it is
about to do — version, build number, commit, screenshot count, the What's New
text — and only then submits. Under "ship the release" that is a statement, not
a question; the owner asked for one instruction, not for a dialogue. Everything
outside section 1d stays outside it: pricing, subscriptions, account settings,
answering a rejection, credentials.

| Step | Today | What "ship the release" needs |
|---|---|---|
| Entry conditions (1a) | A table someone reads | A command that fails loudly |
| `just tf-check` | Owner runs it | Agent runs it, reports, refuses on failure |
| `tf-` tag | Owner creates | Agent creates, with the owner's instruction quoted |
| Wait for TestFlight | Owner watches | Agent polls and reports |
| Manual pass (section 2) | Owner, on a device | Stays human; recorded as evidence the agent can read |
| Upload, paste, select, submit | Agent, App Store Connect opened | Unchanged, plus the pre-submit statement |
| `v` marker | Owner creates | Agent creates after submission, same quoted authorization |

Filling in what the first run actually cost — where attention went, what the
owner had to correct — is a task after the release. That evidence is what turns
each row above into a script or leaves it alone.

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
