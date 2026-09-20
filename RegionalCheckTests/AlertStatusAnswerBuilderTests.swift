import DriveCheckKit
import Foundation
import Testing

struct AlertStatusAnswerBuilderTests {
    @Test("REQ-SURF-007 the Siri answer carries the source and the checked time without an entitlement")
    func answerWithoutEntitlementIncludesSourceAndTime() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveSnapshot(
                AlertsSnapshot(
                    source: "Mørk Skog",
                    serverCachedAt: Date(timeIntervalSince1970: 1000),
                    fetchedAt: Date(timeIntervalSince1970: 1000),
                    statuses: [.kyivCity: .alarm]
                )
            )
            let answer = TestLocale.english {
                AlertStatusAnswerBuilder.answer(for: .kyivCity, store: store)
            }
            #expect(answer.dialog.contains("Kyiv"))
            // REQ-SURF-001: resolved Kit wording, not the raw key.
            #expect(answer.dialog.contains("— Alert\n"))
            #expect(answer.dialog.contains("Mørk Skog"))
        }
    }

    @Test
    func answerWithStoredEntitlementIncludesSourceAndTime() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveIsPro(true)
            store.saveSnapshot(
                AlertsSnapshot(
                    source: "Mørk Skog",
                    serverCachedAt: Date(timeIntervalSince1970: 1_720_000_000),
                    fetchedAt: Date(timeIntervalSince1970: 1_720_000_000),
                    statuses: [.kyivCity: .quiet]
                )
            )
            let answer = TestLocale.english {
                AlertStatusAnswerBuilder.answer(for: .kyivCity, store: store)
            }
            #expect(answer.dialog.contains("Kyiv"))
            #expect(answer.dialog.contains("— No Alert\n"))
            #expect(answer.dialog.contains("Mørk Skog"))
        }
    }
}
