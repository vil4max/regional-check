import DriveCheckKit
import SwiftUI

/// RD-6: the "Alert map" row in the Status grouped list (`docs/tasks/redesign.md` §6.1 item 4,
/// §6.4; `states.md` rows 6a–6c) — map icon, label, image age, chevron. Replaces the old always-
/// visible `MapCardView` card: the row itself never loads or polls (REQ-REFRESH-001, MAP-1/MAP-2
/// rules unchanged), it only opens `AlertMapFullScreenView`, which loads on its own appear and on
/// "Refresh map" only.
struct AlertMapRow: View {
    let viewModel: MapViewModel

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: Theme.RedesignCardSizes.innerGap) {
                Image(systemName: "map")
                    .foregroundStyle(Theme.RedesignColors.textSecondary)

                Text("map.fullscreen.title")
                    .font(Theme.RedesignTypography.body.weight(.semibold))
                    .foregroundStyle(Theme.RedesignColors.textPrimary)

                Spacer(minLength: Theme.RedesignCardSizes.innerGap)

                if let ageText = viewModel.ageText {
                    Text(ageText)
                        .font(Theme.RedesignTypography.caption)
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
            }
            .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
            .frame(minHeight: Theme.RedesignRowSizes.grouped)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the alert map"))
        .fullScreenCover(isPresented: $isPresented) {
            AlertMapFullScreenView(viewModel: viewModel)
        }
    }
}

#if DEBUG
    #Preview("Alert map row") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(network: network)
        return VStack {
            AlertMapRow(viewModel: .preloaded(
                imageData: FixtureNetwork.previewMapImage,
                loadedAt: AppContainer.fixtureNow,
                statusSource: container.status,
                httpClient: network,
                variant: .night
            ))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.RedesignColors.background)
    }
#endif
