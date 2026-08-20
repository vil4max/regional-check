import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct RegionsListOrderingTests {
    @Test
    func partitionsAlarmAndQuiet_sortedByUkrainianLocale() {
        let snapshot = AlertsSnapshot(
            source: "test",
            serverCachedAt: nil,
            fetchedAt: Date(),
            statuses: [
                .lviv: .alarm,
                .odesa: .alarm,
                .kyivCity: .quiet,
                .kharkiv: .quiet
            ]
        )

        let model = RegionsListModel(snapshot: snapshot, selected: .kyivCity)
        #expect(model.alarmRegions.map(\.apiKey) == sortedUkrainian([.lviv, .odesa]).map(\.apiKey))
        #expect(model.alarmRegions.count == 2)
        #expect(model.otherRegions.count == AlertRegion.allCases.count - 2)
        #expect(model.otherRegions.contains(.kyivCity))
        #expect(model.otherRegions.contains(.kharkiv))
        #expect(model.status(for: .kyivCity) == .quiet)
        #expect(model.status(for: .chernihiv) == nil)
    }

    @Test
    func withoutSnapshot_allRegionsArePending() {
        let model = RegionsListModel(snapshot: nil, selected: .kyivCity)
        #expect(model.alarmRegions.isEmpty)
        #expect(model.otherRegions.count == AlertRegion.allCases.count)
        #expect(model.otherRegions.allSatisfy { model.status(for: $0) == nil })
    }

    private func sortedUkrainian(_ regions: [AlertRegion]) -> [AlertRegion] {
        regions.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}
