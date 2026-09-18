import SwiftUI
import UIKit

/// RD-6: the full-screen "Alert map" cover (`docs/tasks/redesign.md` §6.4; `states.md` rows
/// 6a–6c). Loads on this view's own appear (when empty) and on "Refresh map" only — never on the
/// row's appear, never polling (REQ-REFRESH-001). A failure never shows a previous image: a stale
/// picture presented as current is the failure mode the brief calls out, so the content switch
/// below has no branch that falls back to `imageData` while `loadFailed` is true.
struct AlertMapFullScreenView: View {
    let viewModel: MapViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var dragOffset: CGFloat = 0

    /// `.fullScreenCover` has no built-in swipe-to-dismiss (unlike `.sheet`); the brief requires
    /// it (owner rulings R2, Q11), so this tracks a downward drag and dismisses past the threshold.
    private static let dismissDragThreshold: CGFloat = 120

    var body: some View {
        VStack(spacing: 0) {
            navigationRow
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Theme.RedesignSpacing.screenInset)
                .padding(.bottom, Theme.RedesignSpacing.screenInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.RedesignColors.background)
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    if value.translation.height > Self.dismissDragThreshold {
                        dismiss()
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            viewModel.setVariant(variant(for: colorScheme))
            // `HostProcess.isUnitTesting` (existing app-wide convention) also gates this: without
            // it, a preview frozen at `loadingPreview`/`failedPreview` races this real `refresh()`
            // call, and — for `failedPreview`, whose fixture network succeeds by default — loses,
            // capturing a loaded image under the failed-state snapshot instead.
            if viewModel.imageData == nil, !HostProcess.isUnitTesting {
                viewModel.refresh()
            }
        }
        .onChange(of: colorScheme) { _, newScheme in
            viewModel.setVariant(variant(for: newScheme))
        }
    }

    private var navigationRow: some View {
        HStack {
            navButton(systemImage: "xmark", accessibilityLabel: Text("Close"), action: { dismiss() })

            Spacer()

            Text("map.fullscreen.title")
                .font(Theme.RedesignTypography.navTitle)
                .foregroundStyle(Theme.RedesignColors.textPrimary)

            Spacer()

            Button {
                viewModel.refresh()
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Theme.RedesignColors.textPrimary)
                        .frame(
                            width: Theme.RedesignControlSizes.navButton,
                            height: Theme.RedesignControlSizes.navButton
                        )
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.RedesignColors.textPrimary)
                        .frame(
                            width: Theme.RedesignControlSizes.navButton,
                            height: Theme.RedesignControlSizes.navButton
                        )
                        .redesignGlassSurface(in: Circle())
                        .overlay(Circle().strokeBorder(Theme.RedesignColors.buttonStroke, lineWidth: 1))
                }
            }
            .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
            .disabled(viewModel.isLoading)
            .accessibilityLabel(Text("map.fullscreen.refresh"))
        }
        .padding(.horizontal, Theme.RedesignSpacing.screenInset)
        .padding(.top, Theme.Spacing.sm)
    }

    private func navButton(systemImage: String, accessibilityLabel: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.RedesignColors.textPrimary)
                .frame(width: Theme.RedesignControlSizes.navButton, height: Theme.RedesignControlSizes.navButton)
                .redesignGlassSurface(in: Circle())
                .overlay(Circle().strokeBorder(Theme.RedesignColors.buttonStroke, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.loadFailed {
            failedState
        } else if let uiImage = decodedImage {
            loadedState(uiImage)
        } else {
            loadingState
        }
    }

    private func loadedState(_ uiImage: UIImage) -> some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .accessibilityLabel(Text(viewModel.accessibilityLabel))

            if let caption = viewModel.fullscreenCaption {
                Text(caption)
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                    .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
                    .padding(.vertical, Theme.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [
                                Theme.RedesignColors.background.opacity(0),
                                Theme.RedesignColors.background.opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
        )
    }

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ProgressView()
                .tint(Theme.RedesignColors.textSecondary)
            Text("map.fullscreen.loading")
                .font(Theme.RedesignTypography.body)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Theme.RedesignColors.surface,
            in: RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
        )
    }

    private var failedState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(Theme.RedesignColors.textSecondary)
            Text("map.error")
                .font(Theme.RedesignTypography.body.weight(.semibold))
                .foregroundStyle(Theme.RedesignColors.textPrimary)
            Text("map.fullscreen.error.hint")
                .font(Theme.RedesignTypography.caption)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Theme.RedesignColors.surface,
            in: RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
        )
    }

    private var decodedImage: UIImage? {
        viewModel.imageData.flatMap(UIImage.init(data:))
    }

    private func variant(for scheme: ColorScheme) -> MapImageVariant {
        scheme == .dark ? .night : .day
    }
}

#if DEBUG
    #Preview("Map fullscreen loaded") {
        let network = FixtureNetwork(alarmRegions: [.kharkiv, .sumy])
        let container = AppContainer.fixture(network: network)
        AlertMapFullScreenView(viewModel: .preloaded(
            imageData: FixtureNetwork.previewMapImage,
            loadedAt: AppContainer.fixtureNow,
            statusSource: container.status,
            httpClient: network,
            variant: .night
        ))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.RedesignColors.background)
    }

    #Preview("Map fullscreen loading") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(network: network)
        AlertMapFullScreenView(viewModel: .loadingPreview(statusSource: container.status, httpClient: network))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.RedesignColors.background)
    }

    #Preview("Map fullscreen failed") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(network: network)
        AlertMapFullScreenView(viewModel: .failedPreview(statusSource: container.status, httpClient: network))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.RedesignColors.background)
    }
#endif
