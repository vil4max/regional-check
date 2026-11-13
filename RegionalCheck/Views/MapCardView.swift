import DriveCheckKit
import SwiftUI

/// The inline alert map on the Status tab (ADR 0015), drawn by the app from the snapshot the status
/// above it shows (MAP-native): it changes in the same render as the status and sends no request.
/// Without a snapshot the outlines show in the no-data fill; there is no loading or failure state.
///
/// The whole card is one tap target that opens the region list (owner: «Как сейчас: список»);
/// VoiceOver reads it as one button named by the regions under alert.
struct AlertMapCard: View {
    let snapshot: AlertsSnapshot?
    let currentRegion: AlertRegion
    /// The status's own staleness: the map dims with it (owner: «Приглушить»).
    var isStale = false
    /// `nil` renders the card inert, with no button trait — a preview or a host with no list.
    var onOpenRegionList: (() -> Void)?

    /// Counts taps that open the list, so each one plays the press haptic.
    @State private var openCount = 0

    /// The map's margin inside the card, as a share of the card's width, so the outline clears
    /// the rounded corners at every width.
    nonisolated static let inset: CGFloat = 0.035

    /// The card's width over height: the outlines' aspect plus the margin on every side. Layout
    /// (REQ-SURF-013) reads this constant, never the outline data.
    nonisolated static let aspectRatio: CGFloat = {
        let mapHeightPerWidth = (1 - 2 * inset) / UkraineOutlines.aspectRatio
        return 1 / (mapHeightPerWidth + 2 * inset)
    }()

    nonisolated static func accessibilityText(snapshot: AlertsSnapshot?) -> String {
        mapAccessibilityLabel(snapshot: snapshot)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
    }

    var body: some View {
        Canvas { context, size in
            Self.draw(
                in: &context, size: size, snapshot: snapshot, currentRegion: currentRegion, isStale: isStale)
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .background(Theme.RedesignColors.surface)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1))
        .contentShape(shape)
        .onTapGesture {
            guard let onOpenRegionList else { return }
            openCount += 1
            onOpenRegionList()
        }
        .sensoryFeedback(Theme.Haptics.button, trigger: openCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Self.accessibilityText(snapshot: snapshot)))
        .opensRegionList(onOpenRegionList)
    }
}

extension AlertMapCard {
    /// Fills every unit, then outlines the current region on top. Kyiv city and Sevastopol come
    /// last in the data, so they paint over the units that enclose them.
    fileprivate static func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        snapshot: AlertsSnapshot?,
        currentRegion: AlertRegion,
        isStale: Bool
    ) {
        guard let outlines = UkraineOutlines.shared else { return }
        let margin = size.width * inset
        let scale = size.width - 2 * margin
        context.opacity = AlertMapFill.opacity(isStale: isStale)
        for outline in outlines.outlines {
            let path = path(outline, scale: scale, margin: margin)
            let fill = AlertMapFill.fill(for: outline.unit, snapshot: snapshot)
            context.fill(path, with: .color(color(for: fill)), style: FillStyle(eoFill: true))
            context.stroke(path, with: .color(Theme.RedesignColors.background), lineWidth: 0.75)
        }
        if let current = outlines.outline(for: .region(currentRegion)) {
            context.stroke(
                path(current, scale: scale, margin: margin),
                with: .color(Theme.RedesignColors.textPrimary),
                style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
    }

    private static func path(_ outline: MapOutline, scale: CGFloat, margin: CGFloat) -> Path {
        var path = Path()
        for ring in outline.rings {
            path.addLines(ring.map { CGPoint(x: margin + $0.x * scale, y: margin + $0.y * scale) })
            path.closeSubpath()
        }
        return path
    }

    /// The status palette, calm (owner: «Спокойные цвета статуса»): alarm in the status alert
    /// colour, quiet and no data muted so the alarm reads first.
    private static func color(for fill: AlertMapFill) -> Color {
        switch fill {
        case .alarm: Theme.RedesignColors.statusAlert
        case .quiet: Theme.RedesignColors.statusClear.opacity(0.42)
        case .noData: Theme.RedesignColors.statusNoData.opacity(0.22)
        }
    }
}

private extension View {
    /// VoiceOver's side of the card-wide tap: the gesture itself is invisible to it, so the card
    /// announces as a button, carries the hint, and opens the list on activation.
    @ViewBuilder
    func opensRegionList(_ action: (() -> Void)?) -> some View {
        if let action {
            accessibilityAddTraits(.isButton)
                .accessibilityHint(Text("map.card.open_regions_hint"))
                .accessibilityAction(.default, action)
        } else {
            self
        }
    }
}

#if DEBUG
    /// Not private: Prefire copies each preview body into the test target, which must see it.
    struct AlertMapCardPreviewHost: View {
        let snapshot: AlertsSnapshot?
        var region: AlertRegion = .kyivCity

        var body: some View {
            VStack {
                AlertMapCard(snapshot: snapshot, currentRegion: region)
                Spacer()
            }
            .padding(Theme.RedesignSpacing.screenInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.RedesignColors.background)
        }
    }

    #Preview("Map card") {
        AlertMapCardPreviewHost(
            snapshot: FixtureNetwork(alarmRegions: [.kyivOblast, .chernihiv, .kharkiv, .sumy])
                .snapshot(fetchedAt: FixtureNetwork.servedAt))
    }

    #Preview("Map card no data") {
        AlertMapCardPreviewHost(snapshot: nil)
    }
#endif
