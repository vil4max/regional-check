# Native pull-to-refresh repair

Assignee: Codex
State: done
Evidence: pull-to-refresh landed (9d2d256) and shipped in 3.0.0; the open item below was done by later TestFlight rounds.
Requested by: owner, remove the unintended Status refresh accessory, move refresh to pull-to-refresh, and publish the next TestFlight round.
Base: 65a6d77 / tf-3.0.0-2.
Owned files: Status/Home/Main tab refresh UI, affected snapshots, build metadata and release evidence.

- [x] Remove the Status Refresh bottom accessory.
- [x] Connect the Status scroll view to the existing refresh workflow through native pull-to-refresh.
- [x] Refresh on Status appearance and retain cached phases when a request fails.
- [x] Verify the Status and Regions tab states and affected snapshots.
- [x] Run final verification and defect-first review.
- [ ] Merge to main, remove the task branch/worktree, push and tag the next TestFlight round.

The Regions Search accessory remains because it is the existing entry point for activating search. The Status refresh operation still uses `HomeViewModel.refresh()`, including Live Activity synchronization after the request completes.

Owner clarification: a cached clear or alert phase survives app re-entry and refresh failure. `No Current Data` is shown only after a failed request when no snapshot exists. Stale styling may communicate age or a failed refresh without replacing the cached phase title. SwiftUI refreshes when Status appears and whenever its scene becomes active again.

Focused verification passed 33 tests across cached launch, app scenarios and Home ViewModel behavior. The Main tabs and both About snapshots passed with the Refresh accessory absent and build number 3 visible in About.

Final verification: `just verify` passed on 2026-09-19. Defect-first review found no remaining correctness, concurrency, crash, API misuse, security, edge-case, or performance defects in the task diff.
