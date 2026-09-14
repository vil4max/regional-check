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
        switch freshness {
        case .expired:
            "widget.status.noConnection"
        case .fresh, .aging:
            switch phase {
            case .idle: "widget.status.noData"
            case .error: "Region Unavailable"
            case .quiet, .alarm: phase.titleKey
            }
        }
    }

    public var symbolName: String {
        switch freshness {
        case .expired:
            "antenna.radiowaves.left.and.right.slash"
        case .fresh, .aging:
            phase == .idle ? "questionmark.circle.fill" : phase.symbolName
        }
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

    public init(
        phase: DriveCheckActivityPhase,
        regionTitle: String,
        checkedAt: Date?,
        nextUpdateAt: Date? = nil,
        isStale: Bool,
        sourceLabel: String? = nil
    ) {
        self.init(
            phase: phase,
            regionTitle: regionTitle,
            checkedAt: checkedAt,
            nextUpdateAt: nextUpdateAt,
            freshness: isStale ? .aging : .fresh,
            sourceLabel: sourceLabel
        )
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

    public static func expectedInterval(for phase: DriveCheckActivityPhase) -> TimeInterval {
        phase == .alarm ? alarmReloadInterval : defaultReloadInterval
    }

    public static func nextUpdateDate(
        from baseDate: Date,
        phase: DriveCheckActivityPhase
    ) -> Date {
        baseDate.addingTimeInterval(expectedInterval(for: phase))
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

    public static func presentation(
        store: SharedStore,
        region: AlertRegion? = nil,
        now: Date = Date(),
        staleThreshold: TimeInterval
    ) -> WidgetStatusPresentation {
        presentation(
            store: store,
            region: region,
            now: now,
            agingThreshold: staleThreshold,
            expiredThreshold: defaultExpiredThreshold
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
            return Timeline(entries: [WidgetStatusTimelineEntry(date: now, presentation: current)], policy: .never)
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

        // The cache changes only when the app or a refresh intent writes it and requests a reload.
        // Precomputing aging and expired entries ensures the widget updates visually on schedule
        // without burning WidgetKit's strict daily reload budget (~40-70 reloads/day).
        return Timeline(entries: entries, policy: .never)
    }

    public static func timeline(
        store: SharedStore,
        region: AlertRegion? = nil,
        now: Date = Date(),
        staleThreshold: TimeInterval
    ) -> Timeline<WidgetStatusTimelineEntry> {
        timeline(
            store: store,
            region: region,
            now: now,
            agingThreshold: staleThreshold,
            expiredThreshold: defaultExpiredThreshold
        )
    }
}
