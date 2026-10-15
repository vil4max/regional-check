import SwiftUI

// Development-only inspection of explanation agent runs. Reachable exclusively
// through the -ShowExplanationTraces launch argument; release builds never see it.
#if DEBUG
    struct ExplanationTraceSheet: View {
        let store: ExplanationTraceStore
        @State private var stored: [StoredTraceEvent] = []

        var body: some View {
            NavigationStack {
                List(stored, id: \.sequence) { stored in
                    Text(Self.line(for: stored.event))
                        .font(.caption.monospaced())
                }
                .navigationTitle("AI Explanation Traces")
                .task {
                    stored = await store.storedEvents()
                }
            }
        }

        private static func line(for event: ExplanationTraceEvent) -> String {
            switch event {
            case let .finalResponseValidated(runID):
                "Run \(short(runID)) final validated"
            case let .fallbackUsed(reason):
                "fallback used reason=\(reason)"
            case let .countryRunStarted(runID):
                "Country run \(short(runID)) started"
            case let .countryCompleted(runID, modelTurns, toolCalls):
                "Country run \(short(runID)) completed turns=\(modelTurns) tools=\(toolCalls)"
            case let .countryFailed(runID, reason):
                "Country run \(short(runID)) failed reason=\(reason)"
            }
        }

        private static func short(_ id: UUID) -> String {
            String(id.uuidString.prefix(4))
        }
    }
#endif
