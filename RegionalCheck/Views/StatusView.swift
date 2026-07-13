import SwiftUI

struct StatusView: View {
    var controller: StatusController

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: controller.state.symbolName)
                    .font(Theme.Typography.symbol)
                    .foregroundStyle(Theme.Colors.onFill)
                    .accessibilityHidden(true)

                Text(controller.state.title)
                    .font(Theme.Typography.stateTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.onFill)
                    .padding(.horizontal, Theme.Spacing.md)

                Text(controller.regionTitle)
                    .font(Theme.Typography.regionTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.onFillSecondary)
                    .padding(.horizontal, Theme.Spacing.md)

                if let detail = controller.state.detailText {
                    Text(detail)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                }
            }
            .padding(Theme.Spacing.xl)
        }
    }

    private var backgroundColor: Color {
        switch controller.state {
        case .alarm:
            return Theme.Colors.attention
        case .quiet:
            return Theme.Colors.normal
        case .idle:
            return Theme.Colors.checking
        case .error:
            return Theme.Colors.unavailable
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
