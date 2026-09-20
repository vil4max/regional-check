import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct RegionListViewModelTests {
    @Test
    func exposesPartitionedRegionsAndStatuses() {
        let snapshot = AlertsSnapshot(
            source: "test",
            serverCachedAt: nil,
            fetchedAt: Date(),
            statuses: [.lviv: .alarm, .kyivCity: .quiet]
        )
        let viewModel = makeViewModel(snapshot: snapshot)

        #expect(viewModel.alarmRegions == [.lviv])
        #expect(viewModel.otherRegions.contains(.kyivCity))
        #expect(viewModel.alarmRegions.count + viewModel.otherRegions.count == AlertRegion.allCases.count)
        #expect(viewModel.status(for: .lviv) == .alarm)
        #expect(viewModel.status(for: .kyivCity) == .quiet)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func withoutASnapshotEveryRegionIsListedAsPending() {
        let viewModel = makeViewModel(snapshot: nil)

        #expect(viewModel.isLoading)
        #expect(viewModel.alarmRegions.isEmpty)
        #expect(viewModel.otherRegions.count == AlertRegion.allCases.count)
    }

    @Test
    func currentRegionFollowsTheSourceAndIsNamedForVoiceOver() {
        let source = CurrentRegionStub(selectedRegion: .kyivCity)
        let viewModel = makeViewModel(snapshot: nil, source: source)
        let currentWord = String(localized: "regions.current")

        #expect(viewModel.currentRegion == .kyivCity)
        #expect(viewModel.accessibilityLabel(for: .kyivCity).contains(currentWord))
        #expect(!viewModel.accessibilityLabel(for: .lviv).contains(currentWord))

        source.selectedRegion = .lviv

        #expect(viewModel.currentRegion == .lviv)
        #expect(viewModel.accessibilityLabel(for: .lviv).contains(currentWord))
    }

    private func makeViewModel(
        snapshot: AlertsSnapshot?,
        source: CurrentRegionStub = CurrentRegionStub(selectedRegion: .kyivCity)
    ) -> RegionListViewModel {
        RegionListViewModel(
            statusSource: RegionStatusStub(lastSnapshot: snapshot),
            currentRegionSource: source
        )
    }
}

@MainActor
private final class RegionStatusStub: RegionStatusSource {
    let lastSnapshot: AlertsSnapshot?

    init(lastSnapshot: AlertsSnapshot?) {
        self.lastSnapshot = lastSnapshot
    }
}

@MainActor
private final class CurrentRegionStub: CurrentRegionSource {
    var selectedRegion: AlertRegion

    init(selectedRegion: AlertRegion) {
        self.selectedRegion = selectedRegion
    }
}
