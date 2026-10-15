import DriveCheckKit
import Foundation

extension AppContainer {
    func makeProSheetViewModel() -> ProSheetViewModel {
        ProSheetViewModel(purchases: subscription, icon: proAppearance)
    }

    static func statusDetailsViewModel(
        status: StatusController,
        summarizer: (any StatusDetailsSummarizing)?,
        traces: ExplanationTraceStore?,
        now: @escaping () -> Date,
        locale: @escaping () -> Locale
    ) -> StatusDetailsViewModel {
        StatusDetailsViewModel(
            summarizer: summarizer ?? statusDetailsSummarizer(traces: traces),
            source: status,
            now: now,
            refreshInterval: { [status] in
                RefreshPolicy.baseIntervalSeconds(for: status.refreshEnvironment())
            },
            locale: locale
        )
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
