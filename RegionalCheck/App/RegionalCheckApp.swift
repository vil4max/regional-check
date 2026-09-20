import DriveCheckKit
import SwiftUI

@main
struct RegionalCheckApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private var container: AppContainer {
        appDelegate.container
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if HostProcess.isUnitTesting {
                    // Test host stays inert so coverage and side effects belong to the tests.
                    Color.clear
                } else {
                    appContent
                }
            }
            // Owner ruling R6: dark-only. Nothing else in the app forces an appearance, so
            // `.glassEffect()` otherwise follows the device's own Light/Dark Appearance setting —
            // a user on Light gets light glass bars over the app's dark-only token colors.
            .preferredColorScheme(.dark)
        }
    }

    private var appContent: some View {
        rootContent
            .task {
                await container.subscription.start()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    container.location.refreshAuthorization()
                    container.liveActivity.beginPhoneForegroundSession()
                    container.syncLiveActivityContent()
                case .background:
                    container.liveActivity.endPhoneForegroundSession()
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
            .environment(container)
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
            if let phase = AppLaunchArguments.screenshotPhase {
                screenshotRoot(phase: phase)
            } else {
                ColdStartRootView()
            }
        #else
            ColdStartRootView()
        #endif
    }

    #if DEBUG
        @ViewBuilder
        private func screenshotRoot(phase: String) -> some View {
            switch phase {
            case "launch":
                LaunchScreenCaptureView()
            case "onboarding":
                OnboardingView(onContinue: {})
            case "details":
                MainTabView(initialTab: .details)
            case "region-list":
                MainTabView(initialStatusPath: [.regionList])
            default:
                MainTabView()
            }
        }
    #endif
}

#if DEBUG
    private struct LaunchScreenCaptureView: View {
        var body: some View {
            ZStack {
                Color("LaunchBackground")
                    .ignoresSafeArea()
                Image("LaunchScreen")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            .accessibilityHidden(true)
        }
    }
#endif

extension StatusState.Phase {
    var activityPhase: DriveCheckActivityPhase {
        switch self {
        case .idle:
            .idle
        case .quiet:
            .quiet
        case .alarm:
            .alarm
        case .error, .regionUnavailable:
            .error
        }
    }
}
