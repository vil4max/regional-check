import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct StatusExplanationContextBuilderTests {
    private let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeInput(
        status: StatusState,
        source: String = "feed"
    ) -> StatusExplanationInput {
        let snapshot = AlertsSnapshot(
            source: source,
            serverCachedAt: checkedAt,
            fetchedAt: checkedAt,
            statuses: [.kyivCity: .quiet, .kharkiv: .alarm]
        )
        return StatusExplanationInput(snapshot: snapshot, region: .kyivCity, status: status)
    }

    @Test
    func buildsProjection_withExactlyTheRequiredFacts() throws {
        let builder = StatusExplanationContextBuilder()
        let context = try #require(builder.makeContext(from: makeInput(status: .quiet(lastCheckedAt: checkedAt))))
        // Full-value equality proves the projection contains exactly these five
        // fields and nothing else leaked from application state.
        #expect(context == StatusExplanationContext(
            regionID: "kyivCity",
            regionTitle: AlertRegion.kyivCity.title,
            phase: .quiet,
            source: "feed",
            checkedAt: checkedAt
        ))
    }

    @Test(arguments: [
        (StatusState.Phase.quiet, StatusExplanationContext.Phase.quiet),
        (StatusState.Phase.alarm, StatusExplanationContext.Phase.alarm)
    ])
    func mapsResolvedPhasesOnly(phase: StatusState.Phase, expected: StatusExplanationContext.Phase) throws {
        let builder = StatusExplanationContextBuilder()
        let state: StatusState = phase == .quiet
            ? .quiet(lastCheckedAt: checkedAt)
            : .alarm(lastCheckedAt: checkedAt)
        let context = try #require(builder.makeContext(from: makeInput(status: state)))
        #expect(context.phase == expected)
    }

    @Test(arguments: [
        StatusState.idle,
        StatusState.error,
        StatusState.regionUnavailable
    ])
    func rejectsUnresolvedStates(state: StatusState) {
        let builder = StatusExplanationContextBuilder()
        #expect(builder.makeContext(from: makeInput(status: state)) == nil)
    }

    @Test
    func fallsBackToSnapshotCheckedAt_whenStatusHasNoTimestamp() throws {
        let builder = StatusExplanationContextBuilder()
        // quiet/alarm always carry a timestamp today; this pins the deterministic
        // fallback order if that ever changes.
        let snapshot = AlertsSnapshot(
            source: "feed",
            serverCachedAt: checkedAt.addingTimeInterval(-30),
            fetchedAt: checkedAt,
            statuses: [.kyivCity: .quiet]
        )
        let input = StatusExplanationInput(
            snapshot: snapshot,
            region: .kyivCity,
            status: .quiet(lastCheckedAt: checkedAt)
        )
        let context = try #require(builder.makeContext(from: input))
        #expect(context.checkedAt == checkedAt)
    }
}
