import SwiftUI

/// RD-5 restyled this to the redesign's Summary card typography (left-aligned body text, RD-2
/// tokens). The nearby-alerts warning line (REQ-SURF-005) stays embedded in `rows` rather than
/// rendered as its own amber line: `StatusDetailsViewModel.swift` (the rows/`PresentationState`
/// contract) isn't in RD-5's owned files, only this view and `StatusDetailsProvider.swift`'s
/// nearby-rule guard are — splitting the warning out cleanly would mean changing that contract.
/// Flagged in the RD-5 report as a follow-up for whichever task next touches the ViewModel.
struct StatusDetailsView: View {
    let viewModel: StatusDetailsViewModel

    var body: some View {
        VStack(spacing: Theme.RedesignSpacing.screenInset / 2) {
            switch viewModel.presentationState {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView()
                    .tint(Theme.RedesignColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(Text("status.explanation.loading"))
            case let .result(rows):
                VStack(alignment: .leading, spacing: Theme.RedesignCardSizes.innerGap) {
                    ForEach(rows, id: \.self) { row in
                        Text(row)
                            .font(Theme.RedesignTypography.body)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(Theme.RedesignColors.textBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            case .error:
                Text("status.explanation.error")
                    .font(Theme.RedesignTypography.body)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .transition(.opacity)
        .onChange(of: viewModel.currentInput, initial: true) {
            viewModel.synchronizeWithCurrentContext()
        }
        .onAppear {
            viewModel.activate()
        }
    }
}
