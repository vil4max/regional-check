import RegionalCheckDomain
import os
import SwiftUI

@MainActor
public enum AlertStatusViewState: Equatable, Sendable {
    case idle
    case quiet(lastCheckedAt: Date, source: String)
    case alarm(lastCheckedAt: Date, source: String)
    case error(message: String)
}

@MainActor
public final class RegionalCheckViewModel: ObservableObject {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "RegionalCheckStatus")

    @Published public private(set) var state: AlertStatusViewState = .idle
    @Published public private(set) var regionTitle: String
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?

    private var region: AlertRegion
    private let fetchStatus: FetchAlertStatusUseCase
    private let regionTitleUseCase: RegionTitleUseCase

    public init(
        region: AlertRegion,
        fetchStatus: FetchAlertStatusUseCase,
        regionTitleUseCase: RegionTitleUseCase = .init()
    ) {
        self.region = region
        self.fetchStatus = fetchStatus
        self.regionTitleUseCase = regionTitleUseCase
        self.regionTitle = regionTitleUseCase.execute(region: region)
    }

    public func setRegion(_ region: AlertRegion) {
        self.region = region
        self.regionTitle = regionTitleUseCase.execute(region: region)
    }

    public func refresh() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let snapshot = try await fetchStatus.execute(region: region)
                switch snapshot.status {
                case .alarm:
                    state = .alarm(lastCheckedAt: snapshot.checkedAt, source: snapshot.source)
                case .quiet:
                    state = .quiet(lastCheckedAt: snapshot.checkedAt, source: snapshot.source)
                }
            } catch {
                Self.log.error("Fetch status failed: \(error.localizedDescription, privacy: .public)")
                let userMessage = String(localized: "Unable to update")
                state = .error(message: userMessage)
                errorMessage = userMessage
            }
        }
    }

    public func clearError() {
        errorMessage = nil
    }
}

public struct RegionalCheckStatusView: View {
    @ObservedObject private var viewModel: RegionalCheckViewModel

    public init(viewModel: RegionalCheckViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
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

                Text(viewModel.regionTitle)
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
        switch viewModel.state {
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
        switch viewModel.state {
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
        switch viewModel.state {
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
        switch viewModel.state {
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
    let useCase = FetchAlertStatusUseCase(provider: PreviewProvider())
    RegionalCheckStatusView(viewModel: RegionalCheckViewModel(region: .kyivCity, fetchStatus: useCase))
}

private struct PreviewProvider: AirAlertProviding {
    func fetchStatus(region: AlertRegion) async throws -> AlertStatusSnapshot {
        AlertStatusSnapshot(region: region, status: .quiet, checkedAt: Date(), source: "preview")
    }

    func fetchAllOblastStatuses() async throws -> [AlertStatusSnapshot] {
        []
    }
}
