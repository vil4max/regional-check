import Foundation

extension AppContainer {
    func makeProSheetViewModel() -> ProSheetViewModel {
        ProSheetViewModel(purchases: subscription, icon: proAppearance)
    }

    static func statusDetailsSummarizer(
        traces: ExplanationTraceStore?
    ) -> any StatusDetailsSummarizing {
        FallbackStatusDetailsProvider(
            primary: FoundationModelsStatusDetailsProvider(trace: traces),
            fallback: DeterministicStatusDetailsProvider(),
            trace: traces
        )
    }

    static func syncLiveActivityContent(
        status: StatusController,
        liveActivity: any LiveActivityControlling
    ) {
        liveActivity.update(
            phase: status.state.phase.activityPhase,
            regionTitle: status.regionTitle,
            checkedAt: status.state.checkedAt,
            sourceLabel: StatusSourceLabel.displayName(for: status.lastSourceRaw),
            isStale: status.isDataStale
        )
    }
}
