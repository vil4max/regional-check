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
}
