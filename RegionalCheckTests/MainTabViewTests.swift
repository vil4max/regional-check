import Foundation
@testable import RegionalCheck
import Testing

struct MainTabViewTests {
    @Test
    func tabTitleKeys_resolveInEnglish() {
        #expect(String(localized: "tab.status") == "Status")
        #expect(String(localized: "tab.regions") == "Regions")
        #expect(String(localized: "status.details.action") == "Details")
    }
}
