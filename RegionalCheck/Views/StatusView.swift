import SwiftUI

struct StatusView: View {
    var controller: StatusController

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: symbolName)
                    .font(Theme.Typography.symbol)
                    .foregroundStyle(Theme.Colors.onFill)
                    .accessibilityHidden(true)

                Text(stateTitle)
                    .font(Theme.Typography.stateTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.onFill)
                    .padding(.horizontal, Theme.Spacing.md)

                Text(controller.regionTitle)
                    .font(Theme.Typography.regionTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.onFillSecondary)
                    .padding(.horizontal, Theme.Spacing.md)

                if let detail = detailText {
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

    private var stateTitle: String {
        switch controller.state {
        case .alarm:
            return String(localized: "Attention")
        case .quiet:
            return String(localized: "Normal")
        case .idle:
            return String(localized: "Checking…")
        case .error:
            return String(localized: "Unable to update")
        }
    }

    private var symbolName: String {
        switch controller.state {
        case .alarm:
            return "circle.fill"
        case .quiet:
            return "checkmark.circle.fill"
        case .idle:
            return "ellipsis.circle"
        case .error:
            return "arrow.clockwise.circle"
        }
    }

    private var detailText: String? {
        switch controller.state {
        case .alarm(let lastCheckedAt, _), .quiet(let lastCheckedAt, _):
            return String(format: String(localized: "Updated: %@"), lastCheckedAt.formatted(date: .omitted, time: .shortened))
        case .error:
            return String(localized: "Tap Refresh to try again")
        case .idle:
            return nil
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
