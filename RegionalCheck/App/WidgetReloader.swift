import WidgetKit

struct LiveWidgetReloader: WidgetReloading {
    private let reloadTimelines: @Sendable () -> Void
    private let reloadControls: @Sendable () -> Void

    init(
        reloadTimelines: @escaping @Sendable () -> Void = { WidgetReloader.reloadAllTimelines() },
        reloadControls: @escaping @Sendable () -> Void = { WidgetReloader.reloadStatusControl() }
    ) {
        self.reloadTimelines = reloadTimelines
        self.reloadControls = reloadControls
    }

    /// Controls are not part of any widget timeline: WidgetKit re-reads a control's template only
    /// when asked, so every timeline reload must ask for it too or the control keeps the old
    /// region and glyph.
    func reloadAllTimelines() {
        reloadTimelines()
        reloadControls()
    }
}

enum WidgetReloader {
    /// Must match `DriveCheckStatusControl.kind` in the widget extension, which this target
    /// cannot import.
    static let statusControlKind = "DriveCheckStatusControl"

    static func reloadAllTimelines() {
        guard !HostProcess.isUnitTesting else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// `ControlCenter.reloadControls(ofKind:)` — iOS 18.0+, below this app's deployment target.
    static func reloadStatusControl() {
        guard !HostProcess.isUnitTesting else { return }
        ControlCenter.shared.reloadControls(ofKind: statusControlKind)
    }
}
