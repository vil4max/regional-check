import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// Freshness and `CarPlayLoadState` → title mapping for the CarPlay screen.
@MainActor
struct CarPlayLoadStateTests {
    private static let now = Date(timeIntervalSince1970: 1_789_555_260)
    private static let freshness = CarPlayFreshness(now: now, refreshIntervalSeconds: 60)

    private func snapshot(ageSeconds: TimeInterval, alarm: Bool = false) -> CarPlaySnapshot {
        let checkedAt = Self.now.addingTimeInterval(-ageSeconds)
        return CarPlaySnapshot(
            state: alarm ? .alarm(lastCheckedAt: checkedAt) : .quiet(lastCheckedAt: checkedAt),
            regionTitle: AlertRegion.kyivCity.title,
            checkedAt: checkedAt
        )
    }

    // MARK: - Freshness

    @Test
    func freshnessUsesSnapshotAgeAgainstTwiceTheBaseInterval() {
        #expect(Self.freshness.isFresh(snapshot(ageSeconds: 60)))
        #expect(Self.freshness.isFresh(snapshot(ageSeconds: 120)))
        #expect(!Self.freshness.isFresh(snapshot(ageSeconds: 121)))
    }

    @Test
    func ageTextUsesMinutesThenHours() {
        TestLocale.english {
            #expect(Self.freshness.ageText(for: snapshot(ageSeconds: 25 * 60)) == "25 min ago")
            #expect(Self.freshness.ageText(for: snapshot(ageSeconds: 30)) == "1 min ago")
            #expect(Self.freshness.ageText(for: snapshot(ageSeconds: 3 * 3600 + 120)) == "3 h ago")
        }
    }

    // MARK: - Title mapping

    @Test
    func loadingWithFreshCacheShowsCachedStatus() {
        TestLocale.english {
            let title = CarPlayHeadline.title(
                for: .loading(cached: snapshot(ageSeconds: 60)),
                freshness: Self.freshness
            )
            #expect(title == "🟢 No Alert")
        }
    }

    @Test
    func loadingWithoutFreshCacheShowsUpdating() {
        TestLocale.english {
            #expect(CarPlayHeadline.title(for: .loading(cached: nil), freshness: Self.freshness) == "Updating…")
            let stale = CarPlayLoadState.loading(cached: snapshot(ageSeconds: 25 * 60))
            #expect(CarPlayHeadline.title(for: stale, freshness: Self.freshness) == "Updating…")
        }
    }

    @Test
    func loadedShowsCurrentStatus() {
        TestLocale.english {
            let title = CarPlayHeadline.title(
                for: .loaded(snapshot(ageSeconds: 0, alarm: true)),
                freshness: Self.freshness
            )
            #expect(title == "🚨 \(StatusState.alarm(lastCheckedAt: Self.now).title)")
        }
    }

    @Test
    func loadedWithStaleUpstreamDataShowsAgeWithoutMarker() {
        TestLocale.english {
            let title = CarPlayHeadline.title(
                for: .loaded(snapshot(ageSeconds: 25 * 60)),
                freshness: Self.freshness
            )
            #expect(title == "No Alert · 25 min ago")
        }
    }

    /// Regression: cold CarPlay launch on weak LTE showed "? No current data" above a
    /// one-minute-old cached status because the title followed the failed request.
    @Test
    func failedWithFreshCacheShowsCachedStatus() {
        TestLocale.english {
            let title = CarPlayHeadline.title(for: .failed(cached: snapshot(ageSeconds: 60)), freshness: Self.freshness)
            #expect(title == "🟢 No Alert")
        }
    }

    @Test
    func failedWithoutFreshCacheShowsNoCurrentData() {
        TestLocale.english {
            #expect(CarPlayHeadline.title(for: .failed(cached: nil), freshness: Self.freshness) == "? No current data")
            let stale = CarPlayLoadState.failed(cached: snapshot(ageSeconds: 25 * 60))
            #expect(CarPlayHeadline.title(for: stale, freshness: Self.freshness) == "? No current data")
        }
    }
}
