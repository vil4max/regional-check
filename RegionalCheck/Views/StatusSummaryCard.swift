import DriveCheckKit
import SwiftUI

/// RD-5: the Status tab's Summary card (`docs/tasks/redesign.md` §6.1 item 3) — header, AI
/// details text (unchanged `StatusDetailsView`), an optional nearby-alerts warning line (embedded
/// in the details text; see the file header on `StatusDetailsView.swift` for why it isn't split
/// into its own amber line), a divider, then a segment bar and affected list built straight from
/// `StatusController`'s snapshot so "25" is never hard-coded (`AlertRegion.allCases`). No separate
/// country-summary *sentence* here: `StatusDetailsProvider`'s existing rows (rendered above by
/// `StatusDetailsView`) already include one (`StatusDetailsLocalization.countryLine`), and that
/// provider isn't RD-5's to restructure — a second copy of the same sentence read twice.
/// `StatusCountrySummary.summaryText` stays as a pure, tested helper for whoever next needs it.
struct StatusSummaryCard: View {
    let isPro: Bool
    let sourceLabel: String?
    let statusDetailsViewModel: StatusDetailsViewModel?
    let snapshot: AlertsSnapshot?
    let accent: Theme.RedesignStatusAccent

    /// The header is unconditional, so without this the Unavailable state (details idle, no
    /// snapshot) is a card holding only the word "SUMMARY". Loading and error count as content:
    /// they render, and hiding them would make the card blink away during every request.
    /// `nonisolated` because `View` is main-actor isolated and this is a pure function of values.
    nonisolated static func hasContent(
        details: StatusDetailsViewModel.PresentationState?,
        hasSnapshot: Bool
    ) -> Bool {
        if hasSnapshot {
            return true
        }
        switch details {
        case .none, .idle:
            return false
        case let .result(rows):
            return !rows.isEmpty
        case .loading, .error:
            return true
        }
    }

    /// An empty body contributes no child to `StatusView`'s stack, so no doubled spacing is left
    /// behind. The details lifecycle is driven by `StatusView`, not by this card being mounted.
    var body: some View {
        if Self.hasContent(details: statusDetailsViewModel?.presentationState, hasSnapshot: snapshot != nil) {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Theme.RedesignCardSizes.innerGap) {
            header

            if let statusDetailsViewModel {
                StatusDetailsView(viewModel: statusDetailsViewModel)
            }

            if snapshot != nil {
                Rectangle()
                    .fill(Theme.RedesignColors.separator)
                    .frame(height: 1)
                countrySection
            }
        }
        .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
        .padding(.vertical, Theme.RedesignCardSizes.paddingVertical)
        .background(
            Theme.RedesignColors.surface,
            in: RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.summaryRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.summaryRadius, style: .continuous)
                .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 6) {
                // Sparkles marks the AI-generated summary; Pro-only, matching states.md row 2
                // ("Status, Pro off": no PRO chip, no Source label — the sparkle follows the same rule).
                if isPro {
                    Image(systemName: "sparkles")
                }
                Text("Summary")
                    .textCase(.uppercase)
            }
            .font(Theme.RedesignTypography.sectionHeader)
            .tracking(Theme.RedesignTypography.sectionHeaderTracking)
            .foregroundStyle(Theme.RedesignColors.textSecondary)

            Spacer(minLength: Theme.RedesignSpacing.screenInset)

            if isPro, let sourceLabel {
                Text("\(String(localized: "status.source.label")) \(sourceLabel)")
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var countrySection: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: Theme.RedesignCardSizes.innerGap) {
                RedesignSegmentBar(snapshot: snapshot, accent: accent)

                let affected = StatusCountrySummary.affectedRegionTitles(snapshot)
                if !affected.isEmpty {
                    Text(affected.joined(separator: ", "))
                        .font(Theme.RedesignTypography.caption)
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

/// Pure so `HomeViewModelTests` can cover "count from snapshot" (RD-5 brief) without a live view.
/// Never hard-codes 25 — always `AlertRegion.allCases.count`.
enum StatusCountrySummary {
    /// Reuses the app's existing full-sentence country summary keys (`country.summary.*`) instead
    /// of the mockup's compact "Alerts in N of 25 · Ukraine" two-column text, which has no catalog
    /// key yet — "existing keys win" (states.md copy notes).
    static func summaryText(for snapshot: AlertsSnapshot) -> String {
        let total = Int64(AlertRegion.allCases.count)
        let alertCount = Int64(snapshot.statuses.values.filter { $0 == .alarm }.count)
        if alertCount == 0 {
            return String(format: String(localized: "country.summary.all_clear"), total)
        }
        return String(format: String(localized: "country.summary.alerts_active"), alertCount, total)
    }

    static func affectedRegionTitles(_ snapshot: AlertsSnapshot) -> [String] {
        AlertRegion.allCases.filter { snapshot.status(for: $0) == .alarm }.map(\.title)
    }
}

/// 25 segments (never hard-coded — `AlertRegion.allCases`), red = alert, green 55% = clear, grey =
/// no data; all at lower opacity while stale (`docs/tasks/redesign.md` §6.1 state table).
private struct RedesignSegmentBar: View {
    let snapshot: AlertsSnapshot
    let accent: Theme.RedesignStatusAccent

    var body: some View {
        HStack(spacing: Theme.RedesignSegmentBarSizes.gap) {
            ForEach(AlertRegion.allCases, id: \.self) { region in
                Capsule()
                    .fill(color(for: snapshot.status(for: region)))
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.RedesignSegmentBarSizes.height)
            }
        }
        // The country line and affected list above already carry this in text form.
        .accessibilityHidden(true)
    }

    private func color(for status: AlertStatus?) -> Color {
        let base: Color = switch status {
        case .alarm: Theme.RedesignColors.statusAlert
        case .quiet: Theme.RedesignColors.statusClear.opacity(0.55)
        case nil: Theme.RedesignColors.textTertiary.opacity(0.4)
        }
        return accent == .stale ? base.opacity(0.6) : base
    }
}
