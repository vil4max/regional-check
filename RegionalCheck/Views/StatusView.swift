import DriveCheckKit
import SwiftUI

struct StatusView: View {
    var controller: StatusController
    var isPro = false
    var sourceLabel: String?
    var showsLocationAccessDenied = false
    var secondaryRegionTitle: String?
    var statusDetailsViewModel: StatusDetailsViewModel?
    /// Dev-only trace sink; always nil outside DEBUG builds.
    var debugExplanationTraces: ExplanationTraceStore?
    var onRefresh: () -> Void = {}
    var onShowInfo: (() -> Void)?
    var onShowPaywall: (() -> Void)?
    var onOpenLocationSettings: (() -> Void)?

    @State private var showsDebugTraces = false

    @State private var pulseBright = false

    var body: some View {
        ZStack {
            Theme.Colors.statusBackdrop(for: controller.state)
                .ignoresSafeArea()
                .overlay {
                    Theme.Colors.statusAccent(for: controller.state)
                        .opacity(pulseOverlayOpacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                .animation(Theme.Motion.stateSpring, value: controller.state.phase)

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: Theme.Spacing.refreshControl)

                Spacer(minLength: Theme.Spacing.md)

                StatusHeroView(
                    state: controller.state,
                    isPro: isPro,
                    isAlertActive: isAlertActive,
                    isChecking: isChecking
                )

                instrumentDivider
                    .padding(.top, Theme.Spacing.lg)

                StatusRegionHeaderView(
                    regionTitle: controller.regionTitle,
                    checkedAt: controller.state.checkedAt
                )

                if isPro, let secondary = secondaryRegionTitle {
                    Text(secondary)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                        .padding(.horizontal, Theme.Spacing.xl)
                }

                instrumentDivider

                statusDetailsSection
                    .frame(maxHeight: 240)
                    .padding(.top, Theme.Spacing.md)

                StatusFooterMessagesView(
                    controller: controller,
                    sourceLabel: sourceLabel,
                    showsLocationAccessDenied: showsLocationAccessDenied,
                    onOpenLocationSettings: onOpenLocationSettings
                )
                .animation(nil, value: controller.state.phase)

                Spacer(minLength: Theme.Spacing.lg)

                StatusRefreshButtonView(
                    isLoading: controller.isLoading,
                    onRefresh: onRefresh
                )

                Spacer(minLength: Theme.Spacing.lg)
            }

            VStack {
                StatusToolbar(
                    isPro: isPro,
                    onShowPaywall: onShowPaywall,
                    onShowInfo: onShowInfo,
                    debugExplanationTraces: debugExplanationTraces,
                    showsDebugTraces: $showsDebugTraces
                )
                Spacer()
            }
        }
        .sensoryFeedback(trigger: controller.state.phase) { _, new in
            switch new {
            case .alarm:
                .warning
            case .quiet:
                .impact(flexibility: .soft, intensity: 0.7)
            case .error, .regionUnavailable:
                .error
            case .idle:
                nil
            }
        }
        .onAppear {
            syncPulse()
        }
        #if DEBUG
        .sheet(isPresented: $showsDebugTraces) {
                if let debugExplanationTraces {
                    ExplanationTraceSheet(store: debugExplanationTraces)
                }
            }
        #endif
            .onChange(of: controller.state.phase) { _, _ in
                syncPulse()
            }
    }

    private var instrumentDivider: some View {
        Rectangle()
            .fill(Theme.Colors.separator)
            .frame(height: 1)
            .padding(.horizontal, Theme.Spacing.xl)
    }

    @ViewBuilder
    private var statusDetailsSection: some View {
        if let statusDetailsViewModel {
            StatusDetailsView(viewModel: statusDetailsViewModel)
        }
    }

    private var isAlertActive: Bool {
        if case .alarm = controller.state {
            return true
        }
        return false
    }

    private var isChecking: Bool {
        if case .idle = controller.state {
            return true
        }
        return false
    }

    private var pulseOverlayOpacity: Double {
        guard isAlertActive else { return 0 }
        return pulseBright ? 0.18 : 0.04
    }

    private func syncPulse() {
        if isAlertActive {
            pulseBright = false
            withAnimation(Theme.Motion.loudPulse) {
                pulseBright = true
            }
        } else {
            withAnimation(Theme.Motion.quietFade) {
                pulseBright = false
            }
        }
    }
}

private struct StatusHeroView: View {
    let state: StatusState
    let isPro: Bool
    let isAlertActive: Bool
    let isChecking: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: state.symbolName)
                .font(Theme.Typography.symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.Colors.statusAccent(for: state))
                .shadow(
                    color: Theme.Shadows.glow,
                    radius: Theme.Shadows.glowRadius,
                    y: Theme.Shadows.glowY
                )
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: state.symbolName)
                .symbolEffect(.pulse, options: .repeating, isActive: isAlertActive)
                .symbolEffect(.rotate, options: .repeating, isActive: isChecking)
                .accessibilityHidden(true)

            Text(state.title)
                .font(Theme.Typography.stateTitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Colors.statusAccent(for: state))
                .shadow(
                    color: Theme.Shadows.soft,
                    radius: Theme.Shadows.softRadius,
                    y: Theme.Shadows.softY
                )
                .contentTransition(.interpolate)
                .padding(.horizontal, Theme.Spacing.md)

            if isPro {
                Text("Pro")
                    .font(Theme.Typography.refreshLabel)
                    .foregroundStyle(Theme.Colors.onboarding)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .accessibilityLabel(Text("subscription.badge.pro"))
            }
        }
    }
}

private struct StatusRegionHeaderView: View {
    let regionTitle: String
    let checkedAt: Date?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(regionTitle)
                .font(Theme.Typography.regionTitle)
                .foregroundStyle(Theme.Colors.onFill)
                .lineLimit(2)

            Spacer(minLength: Theme.Spacing.sm)

            if let checkedAt {
                Text(checkedAt.formatted(date: .omitted, time: .shortened))
                    .font(Theme.Typography.caption.monospacedDigit())
                    .foregroundStyle(Theme.Colors.onFillSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
        .accessibilityElement(children: .combine)
    }
}

private struct StatusFooterMessagesView: View {
    let controller: StatusController
    let sourceLabel: String?
    let showsLocationAccessDenied: Bool
    let onOpenLocationSettings: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if controller.isDataStale {
                Text("status.stale")
                    .font(Theme.Typography.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.staleData)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.sm)
            }

            if controller.state.phase == .error, let previous = controller.lastKnownState {
                VStack(spacing: Theme.Spacing.sm) {
                    Text(String(localized: "driver.last_status") + " " + previous.title)
                    if let detail = previous.detailText {
                        Text(detail)
                    }
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.staleData)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            }

            if let sourceLabel {
                Text("\(String(localized: "status.source.label")) \(sourceLabel)")
                    .font(Theme.Typography.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.onFillSecondary)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.sm)
            }

            if let detail = controller.state.detailText,
               controller.state.phase == .error || controller.state.phase == .regionUnavailable {
                Text(detail)
                    .font(Theme.Typography.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.onFillSecondary)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.sm)
            }

            if showsLocationAccessDenied {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("location.access.denied")
                        .font(Theme.Typography.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                    Text("location.access.pick_region")
                        .font(Theme.Typography.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                    if let onOpenLocationSettings {
                        Button("location.access.open_settings", action: onOpenLocationSettings)
                            .font(Theme.Typography.refreshLabel)
                            .foregroundStyle(Theme.Colors.onboarding)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.md)
            }
        }
    }
}

private struct StatusRefreshButtonView: View {
    let isLoading: Bool
    let onRefresh: () -> Void

    var body: some View {
        Button(action: onRefresh) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(Theme.Colors.onFill)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text("Refresh")
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.Colors.onFill)
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: Theme.Spacing.refreshControl)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(
                color: Theme.Shadows.elevated,
                radius: Theme.Shadows.elevatedRadius,
                y: Theme.Shadows.elevatedY
            )
        }
        .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
        .disabled(isLoading)
        .accessibilityLabel(Text("Refresh"))
    }
}

#Preview {
    StatusView(
        controller: StatusController(
            region: .kyivCity,
            provider: PreviewProvider(),
            persistence: SharedStore.shared,
            widgetReloader: LiveWidgetReloader()
        ),
        isPro: true,
        sourceLabel: "Alert feed"
    )
}

private struct PreviewProvider: StatusProviding {
    func fetchAlerts() async throws -> AlertsSnapshot {
        AlertsSnapshot(
            source: "preview",
            serverCachedAt: Date(),
            fetchedAt: Date(),
            statuses: Dictionary(uniqueKeysWithValues: AlertRegion.allCases.map { ($0, .quiet) })
        )
    }
}
