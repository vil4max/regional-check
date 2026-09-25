@testable import RegionalCheck
import Testing

/// The Status title bar paints nothing behind the title. The edge effect itself is drawn by the
/// system at run time, so the device or simulator check covers what the user sees; this pins the
/// view's decision.
struct StatusTitleBarTests {
    @Test("REQ-SURF-012 the Status scroll view hides its top scroll edge effect")
    @MainActor
    func statusHidesTopScrollEdgeEffect() {
        #expect(StatusView.hidesTopScrollEdgeEffect)
    }
}
