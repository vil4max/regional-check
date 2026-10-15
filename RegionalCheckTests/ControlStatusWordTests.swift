import DriveCheckKit
import Foundation
import Testing

/// The Control Center control states its status as a word, not only by icon and tint.
struct ControlStatusWordTests {
    @Test("REQ-SURF-010 the control names Stay Alert, the clear and alarm words, and old data")
    func controlCarriesTheStatusWord() {
        #expect(Self.value(statuses: [.kyivCity: .quiet], age: 60).statusTitleKey == "All Clear")
        #expect(Self.value(statuses: [.kyivCity: .alarm], age: 60).statusTitleKey == "Alert Active")
        #expect(
            Self.value(statuses: [.kyivCity: .quiet, .kyivOblast: .alarm], age: 60).statusTitleKey
                == "status.caution.title")
        #expect(Self.value(statuses: [.kyivCity: .quiet], age: 3600).statusTitleKey == "widget.status.noCurrentData")
        #expect(Self.value(statuses: [.kyivCity: .alarm], age: 3600).statusTitleKey == "Alert Active")
        #expect(Self.value(statuses: [.kharkiv: .quiet], age: 60).statusTitleKey == "Region Unavailable")
    }

    private static func value(statuses: [AlertRegion: AlertStatus], age: TimeInterval) -> ControlStatusValue {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveRegion(.kyivCity)
            let checkedAt = Date(timeIntervalSince1970: 1_000_000)
            store.saveSnapshot(
                AlertsSnapshot(source: "feed", serverCachedAt: checkedAt, fetchedAt: checkedAt, statuses: statuses)
            )
            return ControlStatusValueBuilder.value(from: store, now: checkedAt.addingTimeInterval(age))
        }
    }
}
