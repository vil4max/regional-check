# Drive Check 3.0 — release preparation

This checklist separates repository preparation, TestFlight candidate creation,
and App Review submission. The authoritative pipeline is
[release-process.md](release-process.md). Preparing a candidate does not imply
that device acceptance or submission has completed.

## 1a. Release stages and current readiness

Reconciled on 2026-09-19. Planned code is complete in `fix/release-closure`
through `88e858a`; the branch is not yet integrated into `main`. The subsequent
project map and release-document edits are documentation only.

| Stage | Required evidence | Current state |
|---|---|---|
| Repository preparation | Code review, release copy, explicit unresolved decisions | Code review found no introduced defects; copy reconciliation in progress |
| Candidate freeze | Integrated commit, clean tree, matching `just verify` and `just release --check` evidence | Pending; no final candidate SHA selected |
| TestFlight request | Candidate on `main`, its successful CI run, `just tf-check`, owner-created annotated `tf-3.0.0-N` tag | Pending |
| Device acceptance | TestFlight build identified by SHA/build; phone, CarPlay, widget and Live Activity pass | Pending; simulator visual smoke is not this pass |
| Submission | Accepted device pass, approved screenshots/copy, resolved product decisions, explicit submission authorization | Not ready |

Open acceptance and decision items:

- RD-13: accept a current English screenshot set. The bounded phone smoke is
  not an approved App Store screenshot set.
- RD-15B: confirm the 400 ms display ceiling on a device; simulator evidence
  remains inconclusive. Do not repeat the simulator measurement loop.
- RD-17: complete candidate-bound regression and the device pass below.
- ADR 0011: Variant B is implemented, but the spike leaves measured CarPlay
  readability and final decision evidence open. Do not silently mark Accepted.
- Provider trigger clarification remains a proposal; existing behavior is
  retained and release wording must not claim a narrower trigger set.
- Live Activity creation requires Pro plus its preference in code. Resolve
  the older free-content matrix wording without changing the gate by accident.
- RD-12: extended accessibility acceptance is deferred and optional for 3.0
  by owner decision; it is not a release blocker.

A TestFlight manual pass is a submission prerequisite, not a prerequisite for
preparing the TestFlight build that will be tested. Failed technical gates stop
candidate promotion; missing device evidence keeps submission pending.

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

Rewritten on 2026-09-21 for the final 3.0 build: two phone tabs, a
location-only region, Pro hidden, two CarPlay tabs. Each line is a thing to look
at, not a thing to trust. Lines marked **(not yet seen live)** were never checked
on a running app by any agent session and depend on this pass.

### Phone — first launch

- On a fresh install the system location prompt does **not** appear over
  onboarding; it appears once, after "Get Started" (REQ-REGION-010).
- Onboarding claims nothing the app does not do: no navigation, no
  notifications, no monitoring, and no region picker ("Nothing to pick or pin").
- At the largest accessibility text size the title and subtitle scale with the
  rows and "Get Started" stays reachable.

### Phone — Status

- No alert, alert and stale states: the ring, the disc, the symbol and the meta
  line agree with each other; stale never reads as current, and an active alert
  stays red while its data is stale.
- **(not yet seen live)** The standalone nearby-alert line appears when
  neighbouring regions are under alert, including while your own region is.
- There is no summary card on Status; the summary is on Details.
- The alert map fills its box with no bands, carries the count of regions under
  alert and its age, loads once per session, and is **not** reloaded by pull to
  refresh.
- Tapping the map opens the read-only region list; back returns to Status.
- Pull to refresh produces one visible result.
- Location access off: the region falls back to Kyiv and a row offers Open
  Settings.
- A region change shows a floating notice above the tab bar that can be
  dismissed and has **no** Undo.
- At the largest text size the map caption wraps instead of truncating, and the
  summary header does not break mid-word.

### Phone — Details

- The summary: your region's line, the nearby line, the country count, and the
  regions under alert in the same order as the region list.
- **(not yet seen live)** With Live Activities off for the app in iOS Settings,
  the Live Activity switch shows off and disabled with a line and Open Settings;
  turning Live Activities back on restores the choice you had (REQ-SURF-008).
- Restore Purchases ends in a message; Manage Subscription appears only with an
  active subscription.
- Data source link, disclaimer, and the version line of the installed TestFlight
  build — "3.0.0 (111)" for `tf-3.0.0-4`; Xcode Cloud assigns the build number.

### Phone — outside Ukraine

- Crossing out of Ukraine keeps the last region and shows the sheet once; it
  does not repeat while you stay outside.

### Phone — Status traffic light

- With the region quiet and most neighbours under alert, the hero reads "Stay
  Alert" in yellow, and CarPlay's title reads "🟡 Stay Alert".
- Old data shows the hero in light grey, not amber.
- The radar sweep turns in every status, and stands still with Reduce Motion on.
- The widget shows the mini ring and no provider name.

### CarPlay (in the car)

Confirmed by the owner in the car on TestFlight build 3.0.0 (115), 2026-09-22.

- One screen, no tabs: the status in the title, the region with its update time,
  nearby alerts only when there are any, and Refresh.
- **(not yet seen live)** The Status region row reads "Updated HH:mm", or "Last
  update HH:mm" when stale, with no "Automatic".
- Refresh always finishes: the screen never stays on "Checking…".
- The app icon is the new one. If the head unit still shows the old one, unpair
  and pair the phone again: CarPlay caches icons.

### Widgets, Live Activity, Siri, Control Center

- The Status widget, the Control Center control, the Live Activity and Siri all
  report the same status as the app at the same moment.
- **(not yet seen live)** Installing over a build that had the second-region
  widget: a placed Status widget keeps working, and the second-region widget is
  gone.
- The widget gallery shows representative data, not "Checking…".
- During an alert the Live Activity starts with the app open, stays when the
  app is minimised, and ends once the app or CarPlay sees the all-clear. With no
  alert, none starts.
- Stale shows the clock symbol and "last known" wording, never "Updating…".

### Icon

- The app icon on the Home screen, in Dark appearance and in Tinted appearance.
  There is no alternate icon in 3.0.

### What must never happen

- The alarm-versus-clear signal for the current region, or the map picture of
  it, behind any purchase (`docs/core.md`, Never).
- Stale data presented as current anywhere.
- Anything that positions Drive Check as an alert monitor, or the map as
  navigation.
- Accounts, ads, history, analytics or social features appearing anywhere.

### Reporting

Report each finding with the surface, the state and a screenshot. It becomes a
defect with a requirement ID and a failing test before the fix, and the next
TestFlight round is `tf-3.0.0-5`.
