import Foundation
import WidgetKit

public enum WidgetFreshnessTier: String, Codable, Hashable, Sendable {
    case fresh
    case aging
    case expired
}

public struct WidgetStatusPresentation: Equatable, Sendable {
    public let phase: DriveCheckActivityPhase
    public let regionTitle: String
    public let checkedAt: Date?
    public let nextUpdateAt: Date?
    public let freshness: WidgetFreshnessTier
    /// REQ-SURF-010: half or more of the region's neighbours, or most of the country, are under
    /// alert. It only shows while the data is fresh; see `isCaution`.
    public let isSurrounded: Bool

    public var isStale: Bool {
        freshness != .fresh
    }

    /// The yellow "Stay Alert" status, as on the app's Status hero: a fresh quiet region
    /// surrounded by alerts. Stale neighbours are as old as the region, so stale data never is.
    public var isCaution: Bool {
        phase == .quiet && isSurrounded && !isStale
    }

    public var accent: WidgetPresentationAccent {
        isCaution ? .caution : phase.presentationAccent(isStale: isStale)
    }

    public var titleKey: String {
        // Expired means "data is old", never "status unknown".
        // Last-known quiet/alarm is always preserved; idle (no snapshot ever) shows the same
        // "Checking…" wording as the Live Activity's own idle phase (RD-10 row 9).
        switch phase {
        case .idle: "Checking…"
        case .error: "Region Unavailable"
        case .quiet where isCaution: "status.caution.title"
        case .quiet, .alarm: phase.titleKey
        }
    }

    public var symbolName: String {
        if isCaution {
            return "exclamationmark.triangle.fill"
        }
        return phase == .idle ? "arrow.triangle.2.circlepath" : phase.symbolName
    }

    /// The glyph a widget or control draws: a known alarm keeps its own icon at any freshness,
    /// and old non-alarm data shows the clock (row 9), so a checkmark always means fresh No Alert.
    public var glyphName: String {
        phase != .alarm && isStale ? "clock.fill" : symbolName
    }

    public init(
        phase: DriveCheckActivityPhase,
        regionTitle: String,
        checkedAt: Date?,
        nextUpdateAt: Date? = nil,
        freshness: WidgetFreshnessTier = .fresh,
        isSurrounded: Bool = false
    ) {
        self.phase = phase
        self.regionTitle = regionTitle
        self.checkedAt = checkedAt
        self.nextUpdateAt = nextUpdateAt
        self.freshness = freshness
        self.isSurrounded = isSurrounded
    }
}

public struct WidgetStatusTimelineEntry: TimelineEntry {
    public let date: Date
    public let presentation: WidgetStatusPresentation

    public init(date: Date, presentation: WidgetStatusPresentation) {
        self.date = date
        self.presentation = presentation
    }
}

public enum WidgetTimelineBuilder {
    public static let defaultReloadInterval: TimeInterval = 60
    public static let alarmReloadInterval: TimeInterval = 30
    public static let defaultAgingThreshold: TimeInterval = 180 // 3 minutes
    public static let defaultExpiredThreshold: TimeInterval = 600 // 10 minutes
    // Best-effort widget polling. WidgetKit treats .after(date) as earliest
    // desired time, not a hard deadline, and budgets reloads (~40-70/day),
    // so these are intentionally slower than the app's 30/60s refresh.
    public static let pollIntervalQuiet: TimeInterval = 300 // 5 minutes
    public static let pollIntervalAlarm: TimeInterval = 180 // 3 minutes
    public static let pollIntervalIdle: TimeInterval = 120 // 2 minutes for first data

    public static func expectedInterval(for phase: DriveCheckActivityPhase) -> TimeInterval {
        phase == .alarm ? alarmReloadInterval : defaultReloadInterval
    }

    public static func pollInterval(for phase: DriveCheckActivityPhase) -> TimeInterval {
        switch phase {
        case .alarm: pollIntervalAlarm
        case .idle, .error: pollIntervalIdle
        case .quiet: pollIntervalQuiet
        }
    }

    public static func nextPollDate(from now: Date, phase: DriveCheckActivityPhase) -> Date {
        now.addingTimeInterval(pollInterval(for: phase))
    }

    public static func freshnessTier(
        checkedAt: Date,
        now: Date,
        agingThreshold: TimeInterval = defaultAgingThreshold,
        expiredThreshold: TimeInterval = defaultExpiredThreshold
    ) -> WidgetFreshnessTier {
        let age = now.timeIntervalSince(checkedAt)
        if age >= expiredThreshold {
            return .expired
        } else if age >= agingThreshold {
            return .aging
        } else {
            return .fresh
        }
    }

    public static func presentation(
        store: SharedStore,
        region: AlertRegion? = nil,
        now: Date = Date(),
        agingThreshold: TimeInterval = defaultAgingThreshold,
        expiredThreshold: TimeInterval = defaultExpiredThreshold
    ) -> WidgetStatusPresentation {
        let selected = region ?? store.loadRegion() ?? .kyivCity
        guard let snapshot = store.loadSnapshot() else {
            return WidgetStatusPresentation(
                phase: .idle,
                regionTitle: selected.title,
                checkedAt: nil,
                nextUpdateAt: nil,
                freshness: .fresh
            )
        }
        let checkedAt = snapshot.checkedAt
        let phase: DriveCheckActivityPhase = switch snapshot.status(for: selected) {
        case .alarm: .alarm
        case .quiet: .quiet
        case nil: .error
        }
        let tier = freshnessTier(
            checkedAt: checkedAt,
            now: now,
            agingThreshold: agingThreshold,
            expiredThreshold: expiredThreshold
        )
        let interval = expectedInterval(for: phase)
        let candidateNextUpdate = snapshot.fetchedAt.addingTimeInterval(interval)
        let nextUpdateAt = candidateNextUpdate > now ? candidateNextUpdate : nil
        return WidgetStatusPresentation(
            phase: phase,
            regionTitle: selected.title,
            checkedAt: checkedAt,
            nextUpdateAt: nextUpdateAt,
            freshness: tier,
            isSurrounded: NearbyRegionPolicy.isSurrounded(selected, snapshot: snapshot)
        )
    }

    public static func timeline(
        store: SharedStore,
        region: AlertRegion? = nil,
        now: Date = Date(),
        agingThreshold: TimeInterval = defaultAgingThreshold,
        expiredThreshold: TimeInterval = defaultExpiredThreshold
    ) -> Timeline<WidgetStatusTimelineEntry> {
        let current = presentation(
            store: store,
            region: region,
            now: now,
            agingThreshold: agingThreshold,
            expiredThreshold: expiredThreshold
        )
        guard let checkedAt = current.checkedAt else {
            // No snapshot yet: poll to get first data instead of parking in .never.
            return Timeline(
                entries: [WidgetStatusTimelineEntry(date: now, presentation: current)],
                policy: .after(nextPollDate(from: now, phase: current.phase))
            )
        }

        var entries = [WidgetStatusTimelineEntry(date: now, presentation: current)]

        let agingDate = checkedAt.addingTimeInterval(agingThreshold)
        let expiredDate = checkedAt.addingTimeInterval(expiredThreshold)

        if now < agingDate {
            let agingPresentation = WidgetStatusPresentation(
                phase: current.phase,
                regionTitle: current.regionTitle,
                checkedAt: checkedAt,
                nextUpdateAt: nil,
                freshness: .aging,
                isSurrounded: current.isSurrounded
            )
            entries.append(WidgetStatusTimelineEntry(date: agingDate, presentation: agingPresentation))
        }

        if now < expiredDate {
            let expiredPresentation = WidgetStatusPresentation(
                phase: current.phase,
                regionTitle: current.regionTitle,
                checkedAt: checkedAt,
                nextUpdateAt: nil,
                freshness: .expired,
                isSurrounded: current.isSurrounded
            )
            entries.append(WidgetStatusTimelineEntry(date: expiredDate, presentation: expiredPresentation))
        }

        // Precomputed aging/expired entries give on-schedule visual freshness
        // transitions without spending reload budget. The .after policy adds a
        // best-effort polling loop: WidgetKit re-invokes getTimeline, which
        // attempts a fetch and keeps last-known-good on failure.
        // Expired entries preserve the last-known phase (quiet/alarm) — expired
        // means "data is old", never a terminal "no connection" state.
        return Timeline(entries: entries, policy: .after(nextPollDate(from: now, phase: current.phase)))
    }
}
