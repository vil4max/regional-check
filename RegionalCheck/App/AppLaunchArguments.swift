import Foundation

enum AppLaunchArguments {
    #if DEBUG
        static var screenshotPhase: String? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-ScreenshotPhase") else { return nil }
            let valueIndex = arguments.index(after: index)
            guard arguments.indices.contains(valueIndex) else { return nil }
            return arguments[valueIndex]
        }

        static var showExplanationTraces: Bool {
            ProcessInfo.processInfo.arguments.contains("-ShowExplanationTraces")
        }
    #else
        static var screenshotPhase: String? {
            nil
        }

        static var showExplanationTraces: Bool {
            false
        }
    #endif
}
