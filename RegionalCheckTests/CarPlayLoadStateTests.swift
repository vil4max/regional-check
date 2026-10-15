import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// Freshness of a `CarPlaySnapshot` for the CarPlay screen. The title mapping is covered by
/// `CarPlayTemplateBuilderTests`.
@MainActor
struct CarPlayLoadStateTests {
    private static let now = Date(timeIntervalSince1970: 1_789_555_260)
    private static let freshness = CarPlayFreshness(now: now, refreshIntervalSeconds: 60)

    private func snapshot(ageSeconds: TimeInterval) -> CarPlaySnapshot {
        let checkedAt = Self.now.addingTimeInterval(-ageSeconds)
        return CarPlaySnapshot(
            state: .quiet(lastCheckedAt: checkedAt),
            regionTitle: AlertRegion.kyivCity.title,
            checkedAt: checkedAt
        )
    }

    @Test
    func freshnessUsesSnapshotAgeAgainstTwiceTheBaseInterval() {
        #expect(Self.freshness.isFresh(snapshot(ageSeconds: 60)))
        #expect(Self.freshness.isFresh(snapshot(ageSeconds: 120)))
        #expect(!Self.freshness.isFresh(snapshot(ageSeconds: 121)))
    }
}
