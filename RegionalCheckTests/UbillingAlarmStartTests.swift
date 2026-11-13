import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// REQ-SURF-014: the alarm's start is the feed's `changed` for a region in alarm, read as Kyiv
/// time. For a clear region `changed` only repeats `cachedat`, so it is never read as an all-clear.
struct UbillingAlarmStartTests {
    @Test("REQ-SURF-014 a region in alarm starts at its changed time; a clear one has no time")
    func alarmStartComesFromChanged() async throws {
        let json = """
            {"source":"test","cachedat":"2026-11-13 08:54:47","states":{
            "Київська область":{"alertnow":true,"changed":"2026-11-13 08:29:04"},
            "Львівська область":{"alertnow":false,"changed":"2026-11-13 08:54:47"},
            "Харківська область":{"alertnow":true}}}
            """
        let response = try #require(
            HTTPURLResponse(
                url: UbillingProvider.endpoint, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]))
        let provider = UbillingProvider(httpClient: MockHTTPClient(data: Data(json.utf8), response: response))

        let snapshot = try await provider.fetchAlerts()

        // 08:29:04 in Kyiv is 06:29:04 UTC in November (EET, UTC+2).
        let expected = try #require(
            Calendar(identifier: .gregorian).date(
                from: DateComponents(
                    timeZone: TimeZone(identifier: "UTC"), year: 2026, month: 11, day: 13, hour: 6, minute: 29,
                    second: 4)))
        #expect(snapshot.alarmStart(for: .kyivOblast) == expected)
        #expect(snapshot.alarmStart(for: .lviv) == nil)
        #expect(snapshot.alarmStart(for: .kharkiv) == nil)
    }

    @Test("REQ-SURF-014 a snapshot saved before 3.4 still decodes, with no starts")
    func oldSavedSnapshotDecodes() throws {
        let saved = """
            {"source":"test","fetchedAt":0,"statuses":["kyivOblast","alarm"]}
            """
        let snapshot = try JSONDecoder().decode(AlertsSnapshot.self, from: Data(saved.utf8))
        #expect(snapshot.status(for: .kyivOblast) == .alarm)
        #expect(snapshot.alarmStart(for: .kyivOblast) == nil)
    }
}
