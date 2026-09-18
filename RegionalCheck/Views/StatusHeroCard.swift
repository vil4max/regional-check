import SwiftUI

/// RD-5: full-form status titles ("No Alert", "Air Raid Alert", "No Current Data", "Checking…";
/// owner ruling R3, `docs/tasks/redesign.md` §6.1 state table). Reuses existing, already-translated
/// catalog keys rather than inventing new copy: `"All Clear"` → "No Alert" and `"Checking…"` are
/// the Status tab's own keys (`StatusController.StatusState.title`, not owned by RD-5); the alarm
/// and stale full forms reuse the CarPlay tab's `driver.status.full.alarm` / `.no_current_data.title`
/// keys, which already carry the exact English/ru/uk text this state table asks for.
extension Theme.RedesignStatusAccent {
    var fullTitle: String {
        switch self {
        case .clear:
            String(localized: "All Clear")
        case .alert:
            String(localized: "driver.status.full.alarm")
        case .stale:
            String(localized: "driver.status.no_current_data.title")
        case .checking:
            String(localized: "Checking…")
        }
    }
}

/// RD-5: the hero's meta line, one per state (`docs/tasks/redesign.md` §6.1 state table):
/// "{Automatic|Manual} · Updated HH:mm" for clear/alert, "Last known: {status} · HH:mm" for stale,
/// "{Automatic|Manual} · Locating" for checking. Pure so `HomeViewModelTests` can cover every
/// combination without a live view; reuses `driver.status.mode.*`/`mode_updated` (existing) and
/// the two new `status.meta.*` keys this task adds.
enum StatusMetaLine {
    static func text(
        accent: Theme.RedesignStatusAccent,
        followsLocation: Bool,
        checkedAt: Date?,
        lastKnownTitle: String?
    ) -> String {
        let mode = String(localized: followsLocation ? "driver.status.mode.automatic" : "driver.status.mode.manual")
        switch accent {
        case .clear, .alert:
            let time = checkedAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? ""
            return String(format: String(localized: "driver.status.mode_updated"), mode, time)
        case .checking:
            return "\(mode) · \(String(localized: "status.meta.locating"))"
        case .stale:
            let time = checkedAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? ""
            let known = lastKnownTitle ?? String(localized: "Unavailable")
            return String(format: String(localized: "status.meta.last_known"), known, time)
        }
    }
}

/// RD-5: the Status hero — `StatusHeroGraphic` (tick ring, disc, status symbol) plus the full-form
/// title, region row, and meta line (`docs/tasks/redesign.md` §6.1; geometry-and-tokens.md §3). AX5
/// shrinks the ring/disc/symbol before any text here truncates (states.md row 8) — handled inside
/// `StatusHeroGraphic`, which also drives the cold-start overlay's hand-off frame, so the two never
/// need to be kept in sync by hand.
struct StatusHeroCard: View {
    let accent: Theme.RedesignStatusAccent
    let symbolName: String
    let isAlertActive: Bool
    let isChecking: Bool
    let regionTitle: String
    let metaText: String

    @Environment(\.coldStartHeroFocus) private var coldStartHeroFocus

    private var accentColor: Color {
        Theme.RedesignColors.statusAccent(for: accent)
    }

    var body: some View {
        VStack(spacing: Theme.RedesignHeroSizes.titleSpacing) {
            StatusHeroGraphic(
                accent: accent,
                symbolName: symbolName,
                isAlertActive: isAlertActive,
                isChecking: isChecking
            )

            Text(accent.fullTitle)
                .font(Theme.RedesignTypography.statusTitle)
                .tracking(Theme.RedesignTypography.statusTitleTracking)
                .foregroundStyle(accentColor)
                .contentTransition(.interpolate)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.footnote)
                    Text(regionTitle)
                        .font(Theme.RedesignTypography.regionName)
                        .lineLimit(2)
                }
                .foregroundStyle(Theme.RedesignColors.textPrimary)

                Text(metaText)
                    .font(Theme.RedesignTypography.tabularTime(.subheadline))
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        // Matches redesign.md §11: "hero reads '{status}, {region}, updated {time}'".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(accent.fullTitle), \(regionTitle), \(metaText)"))
        .modifier(ColdStartHeroFocusTarget(binding: coldStartHeroFocus))
    }
}

#if DEBUG
    // Checking and stale aren't reachable through `AppContainer.fixture()` (see the note on
    // `StatusView`'s previews), so they're previewed here at the component level with literal
    // values instead of a live `StatusController`.
    #Preview("Hero checking") {
        StatusHeroCard(
            accent: .checking,
            symbolName: "arrow.triangle.2.circlepath",
            isAlertActive: false,
            isChecking: true,
            regionTitle: "Kyiv Oblast",
            metaText: StatusMetaLine.text(accent: .checking, followsLocation: true, checkedAt: nil, lastKnownTitle: nil)
        )
        .padding()
        // `maxWidth`/`maxHeight` before the background, not after: `.background(_)` alone only
        // paints the card's own padded bounds, leaving the rest of the snapshot's device-sized
        // canvas to whatever the host window defaults to — which the app's own
        // `.preferredColorScheme(.dark)` (RegionalCheckApp.swift) can now change out from under
        // an ambient-canvas baseline.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.RedesignColors.background)
    }

    #Preview("Hero stale") {
        StatusHeroCard(
            accent: .stale,
            symbolName: "clock",
            isAlertActive: false,
            isChecking: false,
            regionTitle: "Kyiv Oblast",
            metaText: StatusMetaLine.text(
                accent: .stale,
                followsLocation: true,
                checkedAt: Date(timeIntervalSince1970: 1_789_555_260),
                lastKnownTitle: "No Alert"
            )
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.RedesignColors.background)
    }
#endif
