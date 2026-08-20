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
            rootContent
                .task {
                    await container.subscription.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
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
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
            if let phase = AppLaunchArguments.screenshotPhase {
                screenshotRoot(phase: phase)
            } else {
                MainTabView()
            }
        #else
            MainTabView()
        #endif
    }

    #if DEBUG
        @ViewBuilder
        private func screenshotRoot(phase: String) -> some View {
            switch phase {
            case "launch":
                LaunchScreenCaptureView()
            case "onboarding":
                OnboardingView(purpose: .firstLaunch, onContinue: {})
            case "about":
                OnboardingView(purpose: .about, onContinue: {})
            case "regions":
                MainTabView(initialTab: .regions)
            default:
                HomeView(showsOnboarding: .constant(false), showsPaywall: .constant(false))
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
