import Foundation

/// REQ-LAUNCH-002/003: a cached status resolves synchronously (`StatusController.init()` loads it
/// before `ColdStartOverlay` ever runs), so it must never wait on `awaitStatusSettled` — even
/// though a refresh started concurrently by `MainTabViewModel.appear()` can already have set
/// `isLoading = true` by the time the overlay checks, which made `awaitStatusSettled` treat a
/// perfectly good cached status as "not yet settled" and block on that unrelated network
/// round-trip. Only a genuinely unknown status (no cache at all) needs `awaitStatusSettled` to
/// bound how long the overlay can wait.
enum ColdStartSettling {
    static func awaitIfNeeded(hasCachedStatus: Bool, awaitStatusSettled: () async -> Void) async {
        guard !hasCachedStatus else { return }
        await awaitStatusSettled()
    }
}
