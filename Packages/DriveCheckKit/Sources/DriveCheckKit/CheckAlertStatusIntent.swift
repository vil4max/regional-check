import AppIntents
import Foundation

public struct CheckAlertStatusIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.check.title"

    @Parameter(title: "intent.region.parameter")
    public var region: AlertRegion?

    public init() {}

    public init(region: AlertRegion?) {
        self.region = region
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = SharedStore.shared
        let selected = region ?? store.loadRegion() ?? .kyivCity
        let snapshot = await AlertStatusAnswerBuilder.currentSnapshot(store: store, provider: UbillingProvider())
        let answer = AlertStatusAnswerBuilder.answer(for: selected, snapshot: snapshot)
        return .result(dialog: IntentDialog(
            full: LocalizedStringResource(stringLiteral: answer.full),
            supporting: LocalizedStringResource(stringLiteral: answer.supporting)
        ))
    }
}
