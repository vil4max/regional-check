import DriveCheckKit
import Foundation
import Testing

struct RetryAfterParserTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("REQ-REFRESH-005 Retry-After as an HTTP date sets the deadline")
    func httpDateIsHonoured() {
        let deadline = RetryAfterParser.deadline(header: "Tue, 14 Nov 2023 22:15:20 GMT", now: now, attempt: 1)

        #expect(deadline == now.addingTimeInterval(120))
    }

    @Test(
        "REQ-REFRESH-005 Retry-After is capped at five minutes",
        arguments: ["86400", "1e9", "Wed, 15 Nov 2023 22:13:20 GMT"]
    )
    func longRetryAfterIsCapped(_ header: String) {
        let deadline = RetryAfterParser.deadline(header: header, now: now, attempt: 1)

        #expect(deadline == now.addingTimeInterval(RetryAfterParser.maxHold))
    }

    @Test(
        "REQ-REFRESH-005 a negative or past Retry-After means now",
        arguments: ["-30", "Mon, 13 Nov 2023 00:00:00 GMT"]
    )
    func pastRetryAfterMeansNow(_ header: String) {
        #expect(RetryAfterParser.deadline(header: header, now: now, attempt: 1) == now)
    }

    @Test("REQ-REFRESH-005 a non-finite Retry-After falls back to backoff", arguments: ["inf", "nan"])
    func nonFiniteRetryAfterFallsBack(_ header: String) {
        #expect(RetryAfterParser.deadline(header: header, now: now, attempt: 2) == now.addingTimeInterval(60))
    }
}
