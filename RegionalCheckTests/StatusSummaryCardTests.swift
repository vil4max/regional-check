@testable import RegionalCheck
import Testing

/// The Summary card's header is unconditional, so whether the card appears at all is decided by
/// `StatusSummaryCard.hasContent` rather than by whatever its body happens to render.
struct StatusSummaryCardTests {
    @Test("REQ-SURF-005 the Summary card is hidden when details are idle and there is no snapshot")
    func hiddenWithNothingToShow() {
        #expect(!StatusSummaryCard.hasContent(details: .idle, hasSnapshot: false))
        #expect(!StatusSummaryCard.hasContent(details: nil, hasSnapshot: false))
    }

    @Test("REQ-SURF-005 the Summary card stays whenever the details rows carrying the nearby line exist")
    func shownForDetailsRows() {
        #expect(StatusSummaryCard.hasContent(details: .result(["Nearby: Kyiv region"]), hasSnapshot: false))
    }

    @Test("REQ-SURF-005 loading and failed details keep the Summary card, so it never flickers away mid-request")
    func shownWhileLoadingOrFailed() {
        #expect(StatusSummaryCard.hasContent(details: .loading, hasSnapshot: false))
        #expect(StatusSummaryCard.hasContent(details: .error, hasSnapshot: false))
    }

    @Test("REQ-SURF-005 a snapshot alone keeps the Summary card for its segment bar")
    func shownForSnapshotAlone() {
        #expect(StatusSummaryCard.hasContent(details: .idle, hasSnapshot: true))
        #expect(StatusSummaryCard.hasContent(details: nil, hasSnapshot: true))
    }

    @Test("REQ-SURF-005 an empty details result counts as nothing to show")
    func emptyResultIsEmpty() {
        #expect(!StatusSummaryCard.hasContent(details: .result([]), hasSnapshot: false))
    }
}
