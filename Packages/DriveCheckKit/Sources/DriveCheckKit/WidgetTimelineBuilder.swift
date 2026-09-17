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
    public let sourceLabel: String?

    public var isStale: Bool {
        freshness != .fresh
    }

    public var titleKey: String {
        // Expired means "data is old", never "status unknown".
        // Last-known quiet/alarm is always preserved; only idle (no snapshot ever)
        // shows noData.
        switch phase {
        case .idle: "widget.status.noData"
        case .error: "Region Unavailable"
        case .quiet, .alarm: phase.titleKey
        }
    }

    public var symbolName: String {
        phase == .idle ? "questionmark.circle.fill" : phase.symbolName
    }

    public init(
        phase: DriveCheckActivityPhase,
        regionTitle: String,
        checkedAt: Date?,
        nextUpdateAt: Date? = nil,
        freshness: WidgetFreshnessTier = .fresh,
        sourceLabel: String? = nil
    ) {
        self.phase = phase
        self.regionTitle = regionTitle
        self.checkedAt = checkedAt
        self.nextUpdateAt = nextUpdateAt
        self.freshness = freshness
        self.sourceLabel = sourceLabel
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
    public static let defaultStaleThreshold: TimeInterval = defaultAgingThreshold
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
        let sourceLabel = store.loadIsPro() ? snapshot.source : nil
        return WidgetStatusPresentation(
            phase: phase,
            regionTitle: selected.title,
            checkedAt: checkedAt,
            nextUpdateAt: nextUpdateAt,
            freshness: tier,
            sourceLabel: sourceLabel
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
                sourceLabel: current.sourceLabel
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
                sourceLabel: current.sourceLabel
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
