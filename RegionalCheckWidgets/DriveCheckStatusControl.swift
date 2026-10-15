import AppIntents
import DriveCheckKit
import SwiftUI
import WidgetKit

struct DriveCheckStatusControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: ControlStatusValueBuilder.controlKind) {
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
