import SwiftUI

struct StatusView: View {
    var controller: StatusController
    var onRefresh: () -> Void = {}

    @State private var pulseBright = false

    var body: some View {
        ZStack {
            Theme.Colors.statusGradient(for: controller.state)
                .ignoresSafeArea()
                .overlay {
                    Color.white.opacity(pulseOverlayOpacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                .animation(Theme.Motion.stateSpring, value: controller.state.title)

            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: controller.state.symbolName)
                    .font(Theme.Typography.symbol)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.Colors.onFill)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: controller.state.symbolName)
                    .symbolEffect(.pulse, options: .repeating, isActive: isLoud)
                    .accessibilityHidden(true)

                Text(controller.state.title)
                    .font(Theme.Typography.stateTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.onFill)
                    .contentTransition(.interpolate)
                    .padding(.horizontal, Theme.Spacing.md)

                Text(controller.regionTitle)
                    .font(Theme.Typography.regionTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.onFill)
                    .padding(.horizontal, Theme.Spacing.md)

                if let detail = controller.state.detailText {
                    Text(detail)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(Theme.Typography.refreshSymbol)
                            .foregroundStyle(Theme.Colors.onFill)
                            .symbolEffect(.rotate, options: .repeating, isActive: controller.isLoading)
                            .frame(width: Theme.Spacing.refreshControl, height: Theme.Spacing.refreshControl)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(controller.isLoading)
                    .accessibilityLabel(Text("Refresh"))

                    Text("Refresh")
                        .font(Theme.Typography.refreshLabel)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                        .accessibilityHidden(true)
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .padding(Theme.Spacing.xl)
            .animation(Theme.Motion.stateSpring, value: controller.state.title)
        }
        .sensoryFeedback(trigger: controller.state) { _, new in
            switch new {
            case .alarm:
                return .warning
            case .quiet:
                return .impact(flexibility: .soft, intensity: 0.7)
            case .error:
                return .error
            case .idle:
                return nil
            }
        }
        .onAppear {
            syncPulse()
        }
        .onChange(of: controller.state.title) { _, _ in
            syncPulse()
        }
    }

    private var isLoud: Bool {
        if case .alarm = controller.state { return true }
        return false
    }

    private var pulseOverlayOpacity: Double {
        guard isLoud else { return 0 }
        return pulseBright ? 0.14 : 0.02
    }

    private func syncPulse() {
        if isLoud {
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

#Preview {
    StatusView(
        controller: StatusController(
            region: .kyivCity,
            provider: PreviewProvider()
        )
    )
}

private struct PreviewProvider: StatusProviding {
    func fetchStatus(region: AlertRegion) async throws -> AlertStatusSnapshot {
        AlertStatusSnapshot(region: region, status: .quiet, checkedAt: Date(), source: "preview")
    }
}
