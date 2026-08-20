import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct UbillingRetryTests {
    @Test
    func retriesTransientURLErrorOnce() async throws {
        let url = try #require(URL(string: "https://ubilling.net.ua/aerialalerts/"))
        let okResponse = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ))
        let json = Data(
            """
            {
              "source":"test",
              "cachedat":"2026-01-01 00:00:00",
              "states":{"м. Київ":{"alertnow":false,"changed":"2026-01-01 00:00:00"}}
            }
            """.utf8
        )
        let client = SequencingHTTPClient(results: [
            .failure(URLError(.timedOut)),
            .success((json, okResponse))
        ])
        let slept = SleepRecorder()
        let provider = UbillingProvider(
            httpClient: client,
            now: { Date(timeIntervalSince1970: 1) },
            sleep: { await slept.record($0) }
        )

        let snapshot = try await provider.fetchAlerts()
        #expect(snapshot.status(for: .kyivCity) == .quiet)
        #expect(client.requestCount == 2)
        #expect(await slept.values == [.seconds(2)])
    }

    @Test
    func rateLimitedUsesRetryAfterSeconds() async throws {
        let url = try #require(URL(string: "https://ubilling.net.ua/aerialalerts/"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "45"]
        ))
        let client = MockHTTPClient(data: Data(), response: response)
        let now = Date(timeIntervalSince1970: 1000)
        let provider = UbillingProvider(httpClient: client, now: { now }, sleep: { _ in })

        do {
            _ = try await provider.fetchAlerts()
            Issue.record("Expected rateLimited")
        } catch let UbillingError.rateLimited(retryAfter) {
            #expect(retryAfter == now.addingTimeInterval(45))
        } catch {
            Issue.record("Unexpected \(error)")
        }
    }

    @Test
    func retryAfterParserFallsBackToExponentialBackoff() {
        let now = Date(timeIntervalSince1970: 500)
        let first = RetryAfterParser.deadline(header: nil, now: now, attempt: 1)
        let second = RetryAfterParser.deadline(header: nil, now: now, attempt: 2)
        #expect(first == now.addingTimeInterval(30))
        #expect(second == now.addingTimeInterval(60))
        let capped = RetryAfterParser.deadline(header: nil, now: now, attempt: 10)
        #expect(capped == now.addingTimeInterval(300))
    }

    @Test
    @MainActor
    func scheduledRefreshSkipsDuringRateLimitWindow() async {
        let box = RateLimitThenOKProvider(
            retryAfter: Date(timeIntervalSince1970: 2000)
        )
        var now = Date(timeIntervalSince1970: 1000)
        let controller = StatusController(
            region: .kyivCity,
            provider: box,
            now: { now }
        )

        await controller.refresh()
        #expect(controller.state == .error)
        #expect(box.count == 1)

        now = Date(timeIntervalSince1970: 1500)
        await controller.refresh(isScheduled: true)
        #expect(box.count == 1)

        now = Date(timeIntervalSince1970: 2100)
        await controller.refresh(isScheduled: true)
        #expect(box.count == 2)
        #expect(controller.state.phase == .quiet)
    }
}

private actor SleepRecorder {
    private(set) var values: [Duration] = []

    func record(_ duration: Duration) {
        values.append(duration)
    }
}

@MainActor
private final class RateLimitThenOKProvider: StatusProviding {
    private let retryAfter: Date
    private(set) var count = 0

    init(retryAfter: Date) {
        self.retryAfter = retryAfter
    }

    func fetchAlerts() async throws -> AlertsSnapshot {
        count += 1
        if count == 1 {
            throw UbillingError.rateLimited(retryAfter: retryAfter)
        }
        return AlertsSnapshot(
            source: "t",
            serverCachedAt: Date(timeIntervalSince1970: 10),
            fetchedAt: Date(timeIntervalSince1970: 11),
            statuses: [.kyivCity: .quiet]
        )
    }
}
