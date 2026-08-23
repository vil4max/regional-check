import SwiftUI

struct StatusExplanationView: View {
    let viewModel: StatusExplanationViewModel
    let statusTitle: String

    var body: some View {
        Group {
            switch viewModel.presentationState {
            case .loading:
                ProgressView()
                    .tint(Theme.Colors.onFillSecondary)
                    .accessibilityLabel(Text("status.explanation.loading"))
            case let .result(text):
                Text(text)
                    .font(Theme.Typography.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.onFillSecondary)
                    .padding(.horizontal, Theme.Spacing.xl)
            case .error:
                VStack(spacing: Theme.Spacing.sm) {
                    Text("status.explanation.error")
                        .font(Theme.Typography.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                    Button("status.explanation.retry") {
                        viewModel.retryExplanation()
                    }
                    .font(Theme.Typography.refreshLabel)
                    .foregroundStyle(Theme.Colors.onboarding)
                }
                .padding(.horizontal, Theme.Spacing.xl)
            case .idle:
                if viewModel.canRequestExplanation {
                    Button("status.explanation.action") {
                        viewModel.requestExplanation()
                    }
                    .font(Theme.Typography.refreshLabel)
                    .foregroundStyle(Theme.Colors.onboarding)
                    .disabled(!viewModel.canRequestExplanation)
                    .accessibilityHint(Text(statusTitle))
                }
            }
        }
        .onChange(of: viewModel.currentInput, initial: true) {
            viewModel.synchronizeWithCurrentContext()
        }
    }
}
