import DriveCheckKit
import Foundation
import Testing

struct AlertStatusAnswerBuilderTests {
    @Test
    func freeAnswerIncludesRegionAndStatusOnly() {
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
            #expect(answer.dialog.contains("Alert Active"))
            #expect(!answer.dialog.contains("Mørk"))
        }
    }

    @Test
    func proAnswerIncludesSourceAndTime() {
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
            #expect(answer.dialog.contains("All Clear"))
            #expect(answer.dialog.contains("Mørk Skog"))
        }
    }
}
