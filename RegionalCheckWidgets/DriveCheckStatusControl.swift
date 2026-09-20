import AppIntents
import DriveCheckKit
import SwiftUI
import WidgetKit

struct DriveCheckStatusControl: ControlWidget {
    /// The app reloads this control by kind; keep `WidgetReloader.statusControlKind` identical.
    static let kind = "DriveCheckStatusControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenDriveCheckIntent()) {
                Label {
                    Text(statusLabel)
                } icon: {
                    Image(systemName: statusSymbol)
                }
            }
        }
        .displayName("control.status.title")
    }

    private var statusSymbol: String {
        ControlStatusValueBuilder.value(from: .shared).phase.symbolName
    }

    private var statusLabel: String {
        ControlStatusValueBuilder.value(from: .shared).regionTitle
    }
}

struct OpenDriveCheckIntent: AppIntent {
    static let title: LocalizedStringResource = "control.open.title"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
