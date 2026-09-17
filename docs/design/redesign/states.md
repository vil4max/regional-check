# Redesign missing states — spec

Status: design landed (DS-2, exports 9fc5bc5, canvas version
`1789651344-540e`, row "Missing states — DS-2"). This file is the contract; a
newer canvas version is a proposal until this file changes. Written by
drivecheck-product from drivecheck-designer's decision report.

All states use [`geometry-and-tokens.md`](geometry-and-tokens.md): round tick
caps, flat 38 % ring, `proAccent` `#EAD7B0` for Pro chrome, the casing rule.
Copy follows the rule "reuse an existing catalog key when the meaning matches";
strings marked *proposal* are new and go through RD-11.

| # | State | PNG (`states/`) | Rules | Copy | Used by |
|---|---|---|---|---|---|
| 1 | Status, Checking… | `status-checking.png` | Hero ring sweeps with `ringSweep`; round button shows a spinner and is disabled | `Checking…` (existing) | RD-4, RD-5 |
| 2 | Status, Pro off | `status-pro-off.png` | No PRO chip, no "Source" label, no "Also watching" row; crown button stays (Q10) | — | RD-5 |
| 3 | Location denied | `status-location-denied.png` | Row above "Alert map" in the grouped list: `location.slash` icon, title, subtitle, trailing "Open Settings" in `statusStale` (it is a warning) | Title `location.access.denied` "No location access" (existing; the mockup's "Location access is off" is not used); subtitle `location.access.pick_region` (existing); action `location.access.open_settings` (existing) | RD-5 |
| 4 | Region change notice | `status-region-change-notice.png` | Floating `barGlass` pill 98 pt above the bottom bar with Undo | `regions.changed_notice` "Region changed: %@" and `regions.changed_undo` "Undo" (existing; the mockup's "Switched to …" is not used) | RD-4, RD-5 |
| 5a | Regions search, results | `regions-search-results.png` | Search field replaces the large title; both sections filter by name; an empty ALERT ACTIVE section is hidden, never drawn as an empty card | Placeholder "Search regions" (§9 proposal) | RD-7 |
| 5b | Regions search, no results | `regions-search-empty.png` | Both sections hidden; centered empty state | "No regions found" (*proposal*) | RD-7 |
| 6a | Full-screen map, loaded | `map-fullscreen-loaded.png` | Close, title, "Refresh map" in the navigation row; image with its fetch age and regions-under-alert count | "Alert map", "Refresh map" (§9 proposals) | RD-6 |
| 6b | Full-screen map, loading | `map-fullscreen-loading.png` | Spinner in the image area | "Loading map…" (*proposal*) | RD-6 |
| 6c | Full-screen map, failed | `map-fullscreen-failed.png` | Icon, message, hint; previous image not shown | `map.error` "Couldn’t load the map." (existing) plus "Check your connection and refresh." (*proposal*) | RD-6 |
| 7 | Reduce Transparency, Status | `status-reduce-transparency.png` | Tab bar and round button become solid `glassFallback` `#1C1F24`, no blur; the filled stale button is unchanged | — | RD-4, RD-5, RD-12 |
| 8 | AX5 Dynamic Type, Status and Regions | `status-ax5.png`, `regions-ax5.png` | Hero shrinks to 108 / 76 pt before any text truncates; content scrolls (dashed line marks the first screen) | — | RD-5, RD-7, RD-12 |
| 9 | Live Activity, Dynamic Island, Home Screen widget: stale and checking | `widgets-live-activity-stale.png`, `widgets-live-activity-checking.png` | Stale: clock symbol, `statusStale`, "No Current Data", time with "last known", footer "Last known: {status}". Checking: spinner, `statusChecking` | Stale title per casing rule; the existing `liveActivity.stale` key reads "Updating…" and is used for checking, not stale — RD-10 must not show "Updating…" for stale data | RD-10 |
| 10 | Cold start with stale cached status | `cold-start-stale.png` | Ring and disc in `statusStale`, clock symbol, never green; exported at the ready frame | — | RD-15B |
| 11 | AX5 and Reduce Transparency for DS-3 screens | `onboarding-ax5.png`, `about-ax5.png`, `paywall-ax5.png`, `outside-ukraine-ax5.png`, `ds3-reduce-transparency.png` | AX5: content scrolls, CTA stays reachable; About free layout stands for Pro too (only chip and toggle differ). Reduce Transparency: the only glass (round close/nav buttons, Paywall top strip) becomes `glassFallback`; one before/after board covers all four screens | — | RD-12, RD-16 |

## Decisions made without an owner round

drivecheck-product accepted these visual choices from the designer:
the AX5 hero size 108 / 76 pt, one combined Reduce Transparency board for the
DS-3 screens, and the extra Home Screen widget variants in row 9.

## Copy notes for RD-11

- Existing keys win over mockup wording where the meaning is the same (rows 3,
  4, 6c).
- New proposals: "No regions found", "Loading map…", "Check your connection and
  refresh.".
- `liveActivity.stale` currently holds "Updating…" (a checking message under a
  stale-sounding key); RD-10 and RD-11 separate checking from stale.
