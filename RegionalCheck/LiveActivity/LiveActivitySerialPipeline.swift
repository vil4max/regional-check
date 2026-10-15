import Foundation

@MainActor
final class LiveActivitySerialPipeline {
    private var chain: Task<Void, Never>?

    func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = chain
        chain = Task { @MainActor in
            await previous?.value
            await work()
        }
    }

    func drain() async {
        await chain?.value
    }
}
