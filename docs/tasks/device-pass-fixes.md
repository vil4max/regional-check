# Build 108 device acceptance repairs

Assignee: Codex
State: done
Evidence: superseded by later 3.0.0 builds; the open items below were carried by those rounds, and 3.0.0 shipped (`v3.0.0` on `82c8d0b`).
Requested by: owner, repair four reported device defects and prepare the next TestFlight build.
Base: 0d0b615; tested candidate: d71d967 / tf-3.0.0-1 / build 108.
Owned files: status freshness and summary projection; location authorization; phone navigation and Regions layout; affected tests, baselines and release evidence.

- [x] Reproduce failed-refresh freshness disagreement and fix consistent presentation/recovery.
- [x] Preserve system location authorization when updates fail and on foreground re-entry.
- [x] Remove the empty large-title space from Regions; capture the initial and search states.
- [x] Restore native glass tab navigation per owner feedback; preserve Refresh and Search actions.
- [ ] Complete candidate verification/review and record its result on the board.
- [ ] Complete physical-device interaction and CarPlay acceptance on the delivered build.
- [ ] Publish a verified candidate and request the next TestFlight build; confirm delivery.

The owner authorized fixes and the next TestFlight build. Build 108 has not passed device acceptance. The reported network failure's exact cause has not yet been established; cached data must not be presented as a confirmed current result after a failed refresh. App Review submission remains pending device acceptance.

## Focused regression evidence

The new failed-launch-refresh test failed before the repair (7 tests executed; one assertion failure). That red runner stalled in finalization and was terminated after reporting the complete suite result. A narrower method filter earlier selected no tests and is not acceptance evidence.

After repair, the lifecycle and location recovery suites completed successfully: 8 tests, 0 failures. Logs are retained under the shared `device-pass-fixes` artifact directory. The summary now receives refresh failure and shows only the stale warning for unverified cached data; model enhancement is skipped for that state. System permission is re-read at foreground entry and after location errors. Device network failure root cause remains unknown.

Native TabView and the single Regions navigation title compile. Live simulator captures confirm the title layout, Russian search state and native tab appearance. Refresh and Search use the native bottom accessory. This owner-requested native navigation supersedes the earlier custom-bar visual choice. Removed obsolete tab appearance overrides so selection follows the system. Actual tap/navigation and physical-device acceptance remain pending. The full Runtime gate passed after repairing the stale-summary test expectations; the final candidate gate follows baseline and build-number updates. Board item: PVTI_lAHOABVlTc4BjyQKzg7uwew.

## Candidate scope and remaining acceptance

Marketing version remains 3.0.0 because it has not shipped; local build increases to 2. Xcode Cloud assigns the delivered build number separately. The next candidate must be identified by its verified source commit and annotated TestFlight tag. No App Review submission is authorized by this repair.

The first device report proves contradictory freshness presentation; it does not identify the network error. This repair must not be described as proof that the original device network failure is resolved. Retest launch, manual Refresh, return from Settings, Regions search/cancel and tab switching on the delivered build, followed by CarPlay acceptance.

## Visual verification boundary

The 30-test snapshot run passed 28 cases; the two About failures only changed the displayed build number from 1 to 2, so their baselines were updated. The final assertion and candidate gate results belong to the board and commit validation record. Main tabs preview capture omits the selected native tab content even though the live simulator capture displays it. That baseline alone is not native tab acceptance evidence. Live screenshots establish static layout; they do not establish tap, search-cancel, scrolling or CarPlay behavior.
