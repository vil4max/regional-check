import Foundation

public struct ControlStatusValue: Equatable, Sendable {
    public let phase: DriveCheckActivityPhase
    public let regionTitle: String
    /// The widget's glyph and traffic-light accent, so the control shows "Stay Alert" exactly
    /// when the widget does (REQ-SURF-010).
    public let symbolName: String
    public let accent: WidgetPresentationAccent

    public init(
        phase: DriveCheckActivityPhase,
        regionTitle: String,
        symbolName: String,
        accent: WidgetPresentationAccent
    ) {
        self.phase = phase
        self.regionTitle = regionTitle
        self.symbolName = symbolName
        self.accent = accent
    }
}

public enum ControlStatusValueBuilder {
    public static func value(from store: SharedStore, now: Date = Date()) -> ControlStatusValue {
        let presentation = WidgetTimelineBuilder.presentation(store: store, now: now)
        return ControlStatusValue(
            phase: presentation.phase,
            regionTitle: presentation.regionTitle,
            symbolName: presentation.symbolName,
            accent: presentation.accent
        )
    }
}
