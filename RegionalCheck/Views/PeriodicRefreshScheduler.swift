import Foundation

/// The scheduled status refresh every surface shares (REQ-REFRESH-002): one loop however many
/// clients ask for it, which sleeps the policy interval before each scheduled refresh. A Low Power
/// Mode change restarts it, so the new interval applies at once rather than after the current,
/// possibly five-minute, sleep. The sleep and the notification center are injected so a test can
/// drive the loop without waiting for real time.
@MainActor
final class PeriodicRefreshScheduler {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    private let sleep: Sleep
    private let notificationCenter: NotificationCenter
    private var clients = 0
    private var loop: Task<Void, Never>?
    private var powerStateObserver: NSObjectProtocol?
    private var nextInterval: (@MainActor () -> Duration?)?
    private var refresh: (@MainActor () async -> Void)?
    private(set) var lastInterval: Duration?

    init(
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) },
        notificationCenter: NotificationCenter = .default
    ) {
        self.sleep = sleep
        self.notificationCenter = notificationCenter
    }

    var isRunning: Bool {
        loop != nil
    }

    /// `nextInterval` is asked before every sleep, so each turn follows the current environment;
    /// `nil` means its owner is gone and ends the loop. Only the first client's closures are kept.
    func begin(
        nextInterval: @escaping @MainActor () -> Duration?,
        refresh: @escaping @MainActor () async -> Void
    ) {
        clients += 1
        guard loop == nil else { return }
        self.nextInterval = nextInterval
        self.refresh = refresh
        observePowerState()
        start()
    }

    func end() {
        clients = max(0, clients - 1)
        guard clients == 0 else { return }
        stop()
        if let powerStateObserver {
            notificationCenter.removeObserver(powerStateObserver)
            self.powerStateObserver = nil
        }
    }

    private func start() {
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let interval = nextInterval?() else { return }
                lastInterval = interval
                try? await sleep(interval)
                guard !Task.isCancelled else { return }
                await refresh?()
            }
        }
    }

    private func stop() {
        loop?.cancel()
        loop = nil
    }

    private func observePowerState() {
        guard powerStateObserver == nil else { return }
        powerStateObserver = notificationCenter.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.clients > 0 else { return }
                self.stop()
                self.start()
            }
        }
    }
}
