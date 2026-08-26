import Foundation

enum OnboardingPurpose: Equatable {
    case firstLaunch
    case about

    var ctaTitleKey: String {
        switch self {
        case .firstLaunch:
            "Get Started"
        case .about:
            "Got It"
        }
    }
}

enum AppLaunchArguments {
    #if DEBUG
        static var screenshotPhase: String? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-ScreenshotPhase") else { return nil }
            let valueIndex = arguments.index(after: index)
            guard arguments.indices.contains(valueIndex) else { return nil }
            return arguments[valueIndex]
        }

        static var showsPaywallOnLaunch: Bool {
            ProcessInfo.processInfo.arguments.contains("-ShowPaywall")
        }

        static var showExplanationTraces: Bool {
            ProcessInfo.processInfo.arguments.contains("-ShowExplanationTraces")
        }
    #else
        static var screenshotPhase: String? {
            nil
        }

        static var showsPaywallOnLaunch: Bool {
            false
        }

        static var showExplanationTraces: Bool {
            false
        }
    #endif
}
