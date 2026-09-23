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

        /// `-FoldTilt <degrees>`: a fixture screenshot phase holds Home at this tilt, because the
        /// simulator has no motion to tilt it with.
        static var foldTiltDegrees: Double? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-FoldTilt") else { return nil }
            let valueIndex = arguments.index(after: index)
            guard arguments.indices.contains(valueIndex) else { return nil }
            return Double(arguments[valueIndex])
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
