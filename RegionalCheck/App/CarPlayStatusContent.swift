import Foundation

/// Content the Status tab's data rows would show, reduced to what a test can compare without
/// a live CarPlay connection: `CPInterfaceController` has no public initializer, so nothing
/// that needs one is reachable from `CarPlayConnectionTests`. Not read by `CarPlaySceneDelegate`
/// or `CarPlayTemplateBuilder`; this is `CarPlayConnectionTests`' own model of the row-selection
/// rule (cap generated rows at three, fall back to `state.explanation` while details are loading),
/// kept here because it has no dependency on the delegate it shares a file history with.
@MainActor
struct CarPlayStatusContent: Equatable {
    let title: String
    let regionTitle: String
    let regionDetail: String?
    let detailRows: [String]
    let usesStatusDetails: Bool

    static func make(
        state: StatusState,
        regionTitle: String,
        detailsState: StatusDetailsViewModel.PresentationState
    ) -> CarPlayStatusContent {
        let rows: [String]
        let usesStatusDetails: Bool
        if case let .result(resultRows) = detailsState {
            rows = Array(resultRows.prefix(3))
            usesStatusDetails = true
        } else {
            rows = [state.explanation]
            usesStatusDetails = false
        }
        return CarPlayStatusContent(
            title: state.title,
            regionTitle: regionTitle,
            regionDetail: state.detailText,
            detailRows: rows,
            usesStatusDetails: usesStatusDetails
        )
    }
}
