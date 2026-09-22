import Foundation

/// The Siri and Shortcuts answer to "what is the alert status" (REQ-SURF-011).
public enum AlertStatusAnswerBuilder {
    public struct Answer: Equatable, Sendable {
        /// Spoken when Siri has no screen to show the result on (CarPlay, AirPods).
        public let full: String
        /// Spoken and shown alongside the on-screen result.
        public let supporting: String

        public init(full: String, supporting: String) {
            self.full = full
            self.supporting = supporting
        }
    }

    /// Siri gives up on an intent after about ten seconds, so a slow provider must leave time to
    /// answer from the cache.
    public static let fetchBudget: Duration = .seconds(4)

    /// The REQ-REFRESH-010 floor: a snapshot fetched this recently is served without a request.
    public static let fetchFloor: TimeInterval = 10

    /// The longest a stored HTTP 429 deadline holds the intent back: the cap of the app's own
    /// escalating backoff (`RetryAfterParser`).
    public static let maxRateLimitHold: TimeInterval = 300

    /// REQ-REFRESH-002 base intervals the stale rule (REQ-REFRESH-006) doubles. The intent cannot
    /// see Low Power Mode or the network path, so it applies the normal quiet and alarm intervals.
    static let quietInterval: TimeInterval = 60
    static let alarmInterval: TimeInterval = 30

    /// The language the Kit's strings resolve to, so the spoken age never switches language
    /// mid-sentence on a device whose own language the app does not carry.
    public static var answerLocale: Locale {
        Locale(identifier: Bundle.module.preferredLocalizations.first ?? "en")
    }

    /// One provider request within `budget`, persisted to the App Group on success; otherwise the
    /// cached snapshot, which may be `nil` when the app has never fetched.
    public static func currentSnapshot(
        store: SharedStore,
        provider: any StatusProviding,
        now: Date = Date(),
        budget: Duration = fetchBudget
    ) async -> AlertsSnapshot? {
        let cached = store.loadSnapshot()
        // A fetch dated in the future means the clock moved back; it must not hold the floor shut.
        if let cached, (0 ..< fetchFloor).contains(now.timeIntervalSince(cached.fetchedAt)) {
            return cached
        }
        // A Shortcuts automation can repeat this intent unattended, so a 429 window holds it back
        // just like a scheduled refresh.
        // A deadline further out than the longest backoff the app applies itself (a hostile
        // Retry-After, or a clock that has since moved back) must not silence Siri indefinitely.
        if let until = store.loadRateLimitedUntil(), (0 ..< maxRateLimitHold).contains(until.timeIntervalSince(now)) {
            return cached
        }
        switch await fetch(from: provider, within: budget) {
        case let .fetched(fresh):
            // The app may have stored a newer snapshot during the fetch; keep it. One dated further
            // ahead than a fetch can take is left over from a clock that moved back, and is replaced.
            if let stored = store.loadSnapshot(),
               (0 ..< fetchFloor).contains(stored.fetchedAt.timeIntervalSince(fresh.fetchedAt)),
               stored.fetchedAt > fresh.fetchedAt
            {
                return stored
            }
            store.saveSnapshot(fresh)
            return fresh
        case let .rateLimited(until):
            store.saveRateLimitedUntil(until)
            return cached
        case .failed:
            return cached
        }
    }

    public static func answer(
        for region: AlertRegion,
        snapshot: AlertsSnapshot?,
        now: Date = Date(),
        locale: Locale = answerLocale
    ) -> Answer {
        let regionTitle = region.title
        guard let snapshot else {
            let status = String(localized: "driver.status.no_current_data.title", bundle: .module)
            return answer(regionTitle: regionTitle, status: status, age: nil)
        }
        let regionStatus = snapshot.status(for: region)
        let interval = regionStatus == .alarm ? alarmInterval : quietInterval
        let isStale = now.timeIntervalSince(snapshot.checkedAt) > interval * 2
        let statusKey: String.LocalizationValue = switch regionStatus {
        case .alarm: "Alert Active"
        // Stale neighbours are as old as the region itself, so only fresh data turns yellow.
        case .quiet where !isStale && NearbyRegionPolicy.isSurrounded(region, snapshot: snapshot):
            "status.caution.title"
        case .quiet: "All Clear"
        case nil: "Region Unavailable"
        }
        let age = isStale ? relativeAge(of: snapshot.checkedAt, now: now, locale: locale) : nil
        return answer(regionTitle: regionTitle, status: String(localized: statusKey, bundle: .module), age: age)
    }

    private static func answer(regionTitle: String, status: String, age: String?) -> Answer {
        var full = String(format: String(localized: "intent.answer.spoken", bundle: .module), regionTitle, status)
        var supporting = String(
            format: String(localized: "intent.answer.dialog", bundle: .module),
            regionTitle,
            status
        )
        if let age {
            full += " " + String(format: String(localized: "intent.answer.age.spoken", bundle: .module), age)
            supporting += "\n" + String(format: String(localized: "intent.answer.age.dialog", bundle: .module), age)
        }
        return Answer(full: full, supporting: supporting)
    }

    private static func relativeAge(of date: Date, now: Date, locale: Locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// Races the request against the budget; the loser is cancelled, so a timed-out request does
    /// not outlive the answer.
    private enum FetchOutcome: Sendable {
        case fetched(AlertsSnapshot)
        case rateLimited(until: Date)
        case failed
    }

    private static func fetch(from provider: any StatusProviding, within budget: Duration) async -> FetchOutcome {
        await withTaskGroup(of: FetchOutcome.self) { group in
            group.addTask {
                do {
                    return try await .fetched(provider.fetchAlerts())
                } catch let UbillingError.rateLimited(retryAfter) {
                    return .rateLimited(until: retryAfter)
                } catch {
                    return .failed
                }
            }
            group.addTask {
                try? await Task.sleep(for: budget)
                return .failed
            }
            let first = await group.next() ?? .failed
            group.cancelAll()
            return first
        }
    }
}
