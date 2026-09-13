import Foundation
import WidgetKit

public struct WidgetStatusPresentation: Equatable, Sendable {
    public let phase: DriveCheckActivityPhase
    public let regionTitle: String
    public let checkedAt: Date?
    public let isStale: Bool
    public let sourceLabel: String?

    public var titleKey: String {
        if isStale {
            return "widget.status.stale"
        }
        switch phase {
        case .idle: return "widget.status.noData"
        case .error: return "Region Unavailable"
        case .quiet, .alarm: return phase.titleKey
        }
    }

    public var symbolName: String {
        if isStale {
            return "clock.badge.exclamationmark"
        }
        return phase == .idle ? "questionmark.circle.fill" : phase.symbolName
    }

    public init(
        phase: DriveCheckActivityPhase,
        regionTitle: String,
        checkedAt: Date?,
        isStale: Bool,
        sourceLabel: String? = nil
    ) {
        self.phase = phase
        self.regionTitle = regionTitle
        self.checkedAt = checkedAt
        self.isStale = isStale
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
    public static let defaultStaleThreshold: TimeInterval = 120

    public static func presentation(
        store: SharedStore,
        region: AlertRegion? = nil,
        now: Date = Date(),
        staleThreshold: TimeInterval = defaultStaleThreshold
    ) -> WidgetStatusPresentation {
        let selected = region ?? store.loadRegion() ?? .kyivCity
        guard let snapshot = store.loadSnapshot() else {
            return WidgetStatusPresentation(
                phase: .idle,
                regionTitle: selected.title,
                checkedAt: nil,
                isStale: false
            )
        }
        let checkedAt = snapshot.checkedAt
        let isStale = now.timeIntervalSince(checkedAt) >= staleThreshold
        let phase: DriveCheckActivityPhase = switch snapshot.status(for: selected) {
        case .alarm: .alarm
        case .quiet: .quiet
        case nil: .error
        }
        let sourceLabel = store.loadIsPro() ? snapshot.source : nil
        return WidgetStatusPresentation(
            phase: phase,
            regionTitle: selected.title,
            checkedAt: checkedAt,
            isStale: isStale,
            sourceLabel: sourceLabel
        )
    }

    public static func timeline(
        store: SharedStore,
        region: AlertRegion? = nil,
        now: Date = Date(),
        staleThreshold: TimeInterval = defaultStaleThreshold
    ) -> Timeline<WidgetStatusTimelineEntry> {
        let current = presentation(store: store, region: region, now: now, staleThreshold: staleThreshold)
        var entries = [WidgetStatusTimelineEntry(date: now, presentation: current)]
        if let checkedAt = current.checkedAt, !current.isStale {
            let stale = WidgetStatusPresentation(
                phase: current.phase,
                regionTitle: current.regionTitle,
                checkedAt: checkedAt,
                isStale: true,
                sourceLabel: current.sourceLabel
            )
            entries.append(WidgetStatusTimelineEntry(
                date: checkedAt.addingTimeInterval(staleThreshold),
                presentation: stale
            ))
        }
        // The cache changes only when the app or a refresh intent writes it and requests a reload.
        // Precompute expiry so marking data stale doesn't require another provider invocation.
        return Timeline(entries: entries, policy: .never)
    }
}
