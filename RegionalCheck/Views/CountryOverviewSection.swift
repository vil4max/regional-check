import DriveCheckKit
import SwiftUI

/// Secondary country-level affordance on the Status screen.
/// Deliberately the simplest interaction for slice 3: action → compact rows →
/// dismiss. Loading never blocks the primary regional status above it.
struct CountryOverviewSection: View {
    let viewModel: CountrySummaryViewModel
    var showsRequestAction = true

    @State private var isDismissed = false

    var body: some View {
        content
            .onChange(of: viewModel.currentInput, initial: true) {
                viewModel.synchronizeWithCurrentContext()
                isDismissed = false
            }
            .onDisappear {
                viewModel.cancelActiveRequest()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.presentationState {
        case .idle:
            if showsRequestAction, viewModel.canRequestSummary, !isDismissed {
                Button("country.overview.action") {
                    isDismissed = false
                    viewModel.requestSummary()
                }
                .font(Theme.Typography.refreshLabel)
                .foregroundStyle(Theme.Colors.onFillSecondary)
            }
        case .loading:
            VStack(spacing: Theme.Spacing.sm) {
                ProgressView()
                    .tint(Theme.Colors.onFillSecondary)
                dismissButton
            }
        case let .result(rows):
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    Text(row)
                        .font(index == 0 ? Theme.Typography.refreshLabel : Theme.Typography.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(index == 0 ? Theme.Colors.onFill : Theme.Colors.onFillSecondary)
                }
                dismissButton
            }
            .padding(.horizontal, Theme.Spacing.xl)
        case .error:
            VStack(spacing: Theme.Spacing.sm) {
                Text("country.overview.error")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.onFillSecondary)
                Button("status.explanation.retry") {
                    viewModel.retrySummary()
                }
                .font(Theme.Typography.refreshLabel)
                .foregroundStyle(Theme.Colors.onboarding)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }

    private var dismissButton: some View {
        Button("country.overview.dismiss") {
            viewModel.dismissSummary()
            isDismissed = true
        }
        .font(Theme.Typography.caption)
        .foregroundStyle(Theme.Colors.onFillSecondary)
    }
}
