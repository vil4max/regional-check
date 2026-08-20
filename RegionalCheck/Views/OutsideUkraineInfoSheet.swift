import SwiftUI

struct OutsideUkraineInfoSheet: View {
    var onDismiss: () -> Void

    private enum Metrics {
        static let sheetHeight: CGFloat = 420
        static let bottomInset: CGFloat = 16
        static let buttonHeight: CGFloat = 52
        static let mapZoom: CGFloat = 1.18
        static let blurRadius: CGFloat = 3
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Theme.Colors.dashboard

                Image("OutsideUkraineMap")
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .scaleEffect(Metrics.mapZoom)
                    .frame(width: width, height: height)
                    .clipped()
                    .blur(radius: Metrics.blurRadius, opaque: true)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                LinearGradient(
                    colors: [
                        Theme.Colors.dashboard.opacity(0.42),
                        Theme.Colors.dashboard.opacity(0.06),
                        Theme.Colors.dashboard.opacity(0.38)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("outsideUkraine.title")
                            .font(Theme.Typography.regionTitle)
                            .foregroundStyle(Theme.Colors.onFill)

                        Text("outsideUkraine.body")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.onFillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.lg)

                    Spacer(minLength: 0)

                    Button(action: onDismiss) {
                        Text("Got It")
                            .font(Theme.Typography.refreshLabel)
                            .foregroundStyle(Theme.Colors.onFill)
                            .frame(maxWidth: .infinity)
                            .frame(height: Metrics.buttonHeight)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(HapticButtonStyle())
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Metrics.bottomInset)
                }
                .frame(width: width, height: height)
            }
            .frame(width: width, height: height)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.sheetHeight)
        .presentationDetents([.height(Metrics.sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.dashboard)
        .presentationSizing(.page)
    }
}
