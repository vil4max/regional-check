import Foundation

public struct ControlStatusValue: Equatable, Sendable {
    public let phase: DriveCheckActivityPhase
    public let regionTitle: String
    /// The widget's glyph and traffic-light accent, so the control shows "Stay Alert" exactly
    /// when the widget does (REQ-SURF-010).
    public let symbolName: String
    public let accent: WidgetPresentationAccent
    /// The status word, so the control does not carry its status only in icon and tint.
    public let statusTitleKey: String

    public init(
        phase: DriveCheckActivityPhase,
        regionTitle: String,
        symbolName: String,
        accent: WidgetPresentationAccent,
        statusTitleKey: String
    ) {
        self.phase = phase
        self.regionTitle = regionTitle
        self.symbolName = symbolName
        self.accent = accent
        self.statusTitleKey = statusTitleKey
    }
}

public enum ControlStatusValueBuilder {
    /// The status control's WidgetKit kind: declared by the widget extension and reloaded by
    /// the app, which cannot import the extension.
    public static let controlKind = "DriveCheckStatusControl"

    public static func value(from store: SharedStore, now: Date = Date()) -> ControlStatusValue {
        let presentation = WidgetTimelineBuilder.presentation(store: store, now: now)
        return ControlStatusValue(
            phase: presentation.phase,
            regionTitle: presentation.regionTitle,
            symbolName: presentation.glyphName,
            accent: presentation.accent,
            statusTitleKey: presentation.status.compactTitleKey
        )
    }
}
