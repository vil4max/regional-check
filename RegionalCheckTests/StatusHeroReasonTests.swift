import Foundation
@testable import RegionalCheck
import Testing

/// STATUS-reason AC-4 and AC-5: where the reason is spoken, and when the list row replaces the map.
struct StatusHeroReasonTests {
    @Test("STATUS-reason AC-5 VoiceOver reads the status, the region, the reason, then the update time")
    func voiceOverOrder() {
        let spoken = StatusHeroCard.accessibilityText(
            title: "Stay Alert", region: "Kyiv", reason: "Alert nearby: Kyiv Oblast", meta: "Updated 12:38")
        #expect(spoken == "Stay Alert, Kyiv, Alert nearby: Kyiv Oblast, Updated 12:38")
    }

    @Test("STATUS-reason AC-5 without a reason VoiceOver leaves no empty slot")
    func voiceOverWithoutReason() {
        let spoken = StatusHeroCard.accessibilityText(
            title: "No Alert", region: "Lviv", reason: nil, meta: "Updated 12:38")
        #expect(spoken == "No Alert, Lviv, Updated 12:38")
        let empty = StatusHeroCard.accessibilityText(
            title: "No Alert", region: "Lviv", reason: "", meta: "Updated 12:38")
        #expect(empty == spoken)
    }

    @Test("STATUS-reason AC-4 the region list row shows only while no map is shown to open the list")
    func listRowOnlyWithoutAMap() {
        #expect(StatusRegionListRow.isShown(mapIsShown: true) == false)
        #expect(StatusRegionListRow.isShown(mapIsShown: false) == true)
    }
}
