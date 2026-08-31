import SwiftUI

struct StatusDetailsView: View {
    let viewModel: StatusDetailsViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            switch viewModel.presentationState {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView()
                    .tint(Theme.Colors.onFillSecondary)
                    .accessibilityLabel(Text("status.explanation.loading"))
            case let .result(rows):
                VStack(spacing: Theme.Spacing.sm) {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(rows, id: \.self) { row in
                                Text(row)
                                    .font(Theme.Typography.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Theme.Colors.onFillSecondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
                .padding(.horizontal, Theme.Spacing.xl)
            case .error:
                VStack(spacing: Theme.Spacing.sm) {
                    Text("status.explanation.error")
                        .font(Theme.Typography.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
        }
        .onChange(of: viewModel.currentInput, initial: true) {
            viewModel.synchronizeWithCurrentContext()
        }
        .onAppear {
            viewModel.activate()
        }
    }
}

struct StatusExplanationView: View {
    let viewModel: StatusExplanationViewModel
    let statusTitle: String
    var showsRequestAction = true

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
                if showsRequestAction, viewModel.canRequestExplanation {
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
