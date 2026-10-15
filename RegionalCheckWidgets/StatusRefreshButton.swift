import AppIntents
import SwiftUI

/// The round refresh button of the widget and the Live Activity, which differ only in the intent
/// they run and the glyph colour. 44 pt is the minimum touch target (HIG).
struct StatusRefreshButton<Intent: AppIntent>: View {
    let intent: Intent
    let color: Color

    var body: some View {
        Button(intent: intent) {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.10), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
