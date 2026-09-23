import AppIntents
import DriveCheckKit
import SwiftUI
import WidgetKit

struct DriveCheckStatusControl: ControlWidget {
    /// The app reloads this control by kind; keep `WidgetReloader.statusControlKind` identical.
    static let kind = "DriveCheckStatusControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            let value = ControlStatusValueBuilder.value(from: .shared)
            ControlWidgetButton(action: OpenDriveCheckIntent()) {
                Label {
                    Text(value.regionTitle)
                } icon: {
                    Image(systemName: value.symbolName)
                }
            }
            .tint(DriveCheckWidgetTokens.iconColor(accent: value.accent))
        }
        .displayName("control.status.title")
    }
}

struct OpenDriveCheckIntent: AppIntent {
    static let title: LocalizedStringResource = "control.open.title"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
