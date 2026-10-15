import Foundation

public enum RetryAfterParser {
    /// The longest any 429 holds requests back (REQ-REFRESH-005), so a hostile or broken
    /// `Retry-After` cannot silence scheduled polling for hours.
    public static let maxHold: TimeInterval = 300

    public static func deadline(header: String?, now: Date, attempt: Int) -> Date {
        if let header, let requested = requestedDeadline(header: header, now: now) {
            return min(max(requested, now), now.addingTimeInterval(maxHold))
        }
        let delay = min(maxHold, 30 * pow(2.0, Double(max(0, attempt - 1))))
        return now.addingTimeInterval(delay)
    }

    private static func requestedDeadline(header: String, now: Date) -> Date? {
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = TimeInterval(trimmed) {
            return seconds.isFinite ? now.addingTimeInterval(seconds) : nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: trimmed)
    }
}

public enum TransientURLErrorPolicy {
    public static let retryDelay: Duration = .seconds(2)

    public static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed:
            true
        default:
            false
        }
    }
}
