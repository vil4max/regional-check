import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct CountrySummaryValidationTests {
    private typealias Provider = FoundationModelsStatusDetailsProvider

    @Test(arguments: [
        ("en", "All 25 regions of Ukraine are clear."),
        ("ru", "Во всех 25 областях Украины нет тревоги."),
        ("uk", "У всіх 25 областях України немає тривоги."),
    ])
    func allClearSummaryNamingUkraineIsAccepted(_ language: String, _ summary: String) throws {
        let input = try StatusDetailsTestSupport.makeInput(localeIdentifier: language, rawSource: "feed")

        try Provider.validate(countrySummary: summary, for: input)
    }

    @Test
    func ukrainianAlertsSummaryIsAccepted() throws {
        let input = try StatusDetailsTestSupport.makeInput(
            localeIdentifier: "uk", rawSource: "feed", alarms: [.zakarpattia, .lviv]
        )

        try Provider.validate(countrySummary: "Тривога у 2 з 25 областей України.", for: input)
    }

    @Test(arguments: [
        "Alerts in 2 of 25 regions of Ukraine.",
        "Alerts in two of 25 regions of Ukraine, 2 active.",
    ])
    func alertsSummaryWithExactCountsIsAccepted(_ summary: String) throws {
        let input = try StatusDetailsTestSupport.makeInput(
            localeIdentifier: "en", rawSource: "feed", alarms: [.zakarpattia, .lviv]
        )

        try Provider.validate(countrySummary: summary, for: input)
    }

    @Test
    func summaryStatingTheNearbyCountIsAccepted() throws {
        let input = StatusDetailsTestSupport.makeInput(
            localeIdentifier: "en",
            rawSource: "feed",
            alarms: [.kyivOblast, .zakarpattia, .lviv, .odesa, .kharkiv]
        )

        try Provider.validate(
            countrySummary: "Be careful: 1 nearby region, Kyiv Oblast. Alerts in 5 of 25 regions of Ukraine.",
            for: input
        )
    }

    @Test(arguments: [
        "Alerts in 5 of 25 regions of Ukraine.",
        "Alerts in 12 of 25 regions of Ukraine.",
        "Alerts in 2 of 250 regions of Ukraine.",
    ])
    func alertsSummaryWithWrongCountIsRejected(_ summary: String) throws {
        let input = try StatusDetailsTestSupport.makeInput(
            localeIdentifier: "en", rawSource: "feed", alarms: [.zakarpattia, .lviv]
        )

        #expect(throws: ExplanationRunError.self) {
            try Provider.validate(countrySummary: summary, for: input)
        }
    }
}
