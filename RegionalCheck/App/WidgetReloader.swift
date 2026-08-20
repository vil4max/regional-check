import WidgetKit

struct LiveWidgetReloader: WidgetReloading {
    func reloadAllTimelines() {
        WidgetReloader.reloadAllTimelines()
    }
}

enum WidgetReloader {
    static func reloadAllTimelines() {
        guard !HostProcess.isUnitTesting else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
