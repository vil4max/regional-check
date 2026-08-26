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
            case let .runStarted(runID, regionID):
                "Run \(short(runID)) started region=\(regionID)"
            case .contextBuilt:
                "context built"
            case let .modelRequested(runID, step):
                "Run \(short(runID)) model turn=\(step)"
            case let .toolRequested(runID, name):
                "Run \(short(runID)) tool requested=\(name)"
            case let .toolSucceeded(runID, name):
                "Run \(short(runID)) tool ok=\(name)"
            case let .toolFailed(runID, name, reason):
                "Run \(short(runID)) tool failed=\(name) reason=\(reason)"
            case let .finalResponseValidated(runID):
                "Run \(short(runID)) final validated"
            case let .runCompleted(runID, modelTurns, toolCalls):
                "Run \(short(runID)) completed turns=\(modelTurns) tools=\(toolCalls)"
            case let .frameworkRunCompleted(runID, toolCallCount):
                "Run \(short(runID)) framework-completed tools=\(toolCallCount)"
            case let .runFailed(runID, reason):
                "Run \(short(runID)) failed reason=\(reason)"
            case let .fallbackUsed(reason):
                "fallback used reason=\(reason)"
            }
        }

        private static func short(_ id: UUID) -> String {
            String(id.uuidString.prefix(4))
        }
    }
#endif
