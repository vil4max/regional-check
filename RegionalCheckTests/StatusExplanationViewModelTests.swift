import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
final class ExplanationContextMock: ExplanationStatusContext {
    var lastSnapshot: AlertsSnapshot?
    var currentRegion: AlertRegion
    var state: StatusState = .idle

    init(region: AlertRegion = .kyivCity) {
        currentRegion = region
    }
}

actor ExplanationProviderSpy: StatusExplanationProviding {
    struct StubError: Error {}

    private var receivedInputs: [StatusExplanationInput] = []
    private var pending: [CheckedContinuation<String, any Error>] = []
    private var pendingWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func explanation(for input: StatusExplanationInput) async throws -> String {
        receivedInputs.append(input)
        return try await withCheckedThrowingContinuation { continuation in
            pending.append(continuation)
            resumeSatisfiedWaiters()
        }
    }

    func resolve(_ result: Result<String, any Error>) {
        precondition(!pending.isEmpty, "Wait for a pending request before resolving it")
        let continuation = pending.removeFirst()
        continuation.resume(with: result)
    }

    func waitUntilPending(count: Int = 1) async {
        guard pending.count < count else { return }
        await withCheckedContinuation { continuation in
            pendingWaiters.append((count, continuation))
        }
    }

    func inputs() -> [StatusExplanationInput] {
        receivedInputs
    }

    func pendingCount() -> Int {
        pending.count
    }

    func requestCount() -> Int {
        receivedInputs.count
    }

    private func resumeSatisfiedWaiters() {
        let satisfied = pendingWaiters.filter { pending.count >= $0.count }
        pendingWaiters.removeAll { pending.count >= $0.count }
        for waiter in satisfied {
            waiter.continuation.resume()
        }
    }
}

@MainActor
struct StatusExplanationViewModelTests {
    private let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSnapshot(
        region: AlertRegion = .kyivCity,
        status: AlertStatus = .quiet,
        checkedAt stamp: Date? = nil
    ) -> AlertsSnapshot {
        let at = stamp ?? checkedAt
        return AlertsSnapshot(
            source: "test",
            serverCachedAt: at,
            fetchedAt: at,
            statuses: [region: status]
        )
    }

    private struct SUT {
        let viewModel: StatusExplanationViewModel
        let context: ExplanationContextMock
        let provider: ExplanationProviderSpy
    }

    private func makeSUT(
        snapshot: AlertsSnapshot? = nil,
        state: StatusState? = nil
    ) -> SUT {
        let context = ExplanationContextMock()
        if let snapshot {
            context.lastSnapshot = snapshot
        }
        if let state {
            context.state = state
        }
        let provider = ExplanationProviderSpy()
        let viewModel = StatusExplanationViewModel(provider: provider, context: context)
        return SUT(viewModel: viewModel, context: context, provider: provider)
    }

    @Test
    func actionUnavailable_withoutSnapshot() {
        let sut = makeSUT(state: .quiet(lastCheckedAt: checkedAt))
        #expect(!sut.viewModel.canRequestExplanation)
        sut.viewModel.requestExplanation()
        #expect(sut.viewModel.presentationState == .idle)
    }

    @Test
    func actionUnavailable_forNonQuietAlarmStates() async {
        for state in [StatusState.idle, .error, .regionUnavailable] {
            let sut = makeSUT(snapshot: makeSnapshot(), state: state)
            #expect(!sut.viewModel.canRequestExplanation)
            sut.viewModel.requestExplanation()
            #expect(sut.viewModel.presentationState == .idle)
            #expect(await sut.provider.requestCount() == 0)
        }
    }

    @Test(arguments: [
        (AlertStatus.quiet, StatusState.Phase.quiet),
        (AlertStatus.alarm, StatusState.Phase.alarm)
    ])
    func actionAvailable_onlyForQuietAndAlarm(alertStatus: AlertStatus, expectedPhase: StatusState.Phase) {
        let state: StatusState = alertStatus == .quiet
            ? .quiet(lastCheckedAt: checkedAt)
            : .alarm(lastCheckedAt: checkedAt)
        let sut = makeSUT(snapshot: makeSnapshot(status: alertStatus), state: state)
        #expect(sut.viewModel.canRequestExplanation)
        #expect(sut.viewModel.currentInput?.status.phase == expectedPhase)
    }

    @Test
    func request_passesCurrentImmutableInput() async throws {
        let sut = makeSUT(
            snapshot: makeSnapshot(),
            state: .quiet(lastCheckedAt: checkedAt)
        )
        let input = try #require(sut.viewModel.currentInput)
        sut.viewModel.requestExplanation()
        #expect(sut.viewModel.presentationState == .loading)
        await sut.provider.waitUntilPending()
        await sut.provider.resolve(.success("All clear"))
        await drainMainThread()
        let receivedInputs = await sut.provider.inputs()
        #expect(receivedInputs.first == input)
        #expect(receivedInputs.first?.snapshot == sut.context.lastSnapshot)
        #expect(receivedInputs.first?.region == sut.context.currentRegion)
    }

    @Test
    func successfulRequest_transitionsLoadingToResult() async {
        let sut = makeSUT(
            snapshot: makeSnapshot(),
            state: .quiet(lastCheckedAt: checkedAt)
        )
        sut.viewModel.requestExplanation()
        #expect(sut.viewModel.presentationState == .loading)
        await sut.provider.waitUntilPending()
        await sut.provider.resolve(.success("All quiet — you can drive calmly."))
        await drainMainThread()
        #expect(sut.viewModel.presentationState == .result("All quiet — you can drive calmly."))
        #expect(sut.viewModel.isFailure == false)
    }

    @Test
    func failedRequest_transitionsLoadingToError_withoutChangingStatus() async {
        let sut = makeSUT(
            snapshot: makeSnapshot(),
            state: .alarm(lastCheckedAt: checkedAt)
        )
        sut.viewModel.requestExplanation()
        await sut.provider.waitUntilPending()
        await sut.provider.resolve(.failure(ExplanationProviderSpy.StubError()))
        await drainMainThread()
        #expect(sut.viewModel.presentationState == .error)
        #expect(sut.viewModel.isFailure)
        #expect(sut.context.state == .alarm(lastCheckedAt: checkedAt))
        #expect(sut.context.lastSnapshot != nil)
    }

    @Test
    func retry_startsNewRequest_andCanSucceed() async {
        let sut = makeSUT(
            snapshot: makeSnapshot(),
            state: .quiet(lastCheckedAt: checkedAt)
        )
        sut.viewModel.requestExplanation()
        await sut.provider.waitUntilPending()
        await sut.provider.resolve(.failure(ExplanationProviderSpy.StubError()))
        await drainMainThread()
        #expect(sut.viewModel.presentationState == .error)

        sut.viewModel.retryExplanation()
        #expect(sut.viewModel.presentationState == .loading)
        await sut.provider.waitUntilPending(count: 1)
        await sut.provider.resolve(.success("Recovered"))
        await drainMainThread()
        #expect(sut.viewModel.presentationState == .result("Recovered"))
        #expect(await sut.provider.requestCount() == 2)
    }

    @Test
    func regionChange_clearsDeliveredResult() async {
        let sut = makeSUT(
            snapshot: makeSnapshot(),
            state: .quiet(lastCheckedAt: checkedAt)
        )
        sut.viewModel.requestExplanation()
        await sut.provider.waitUntilPending()
        await sut.provider.resolve(.success("Kyiv is quiet"))
        await drainMainThread()
        #expect(sut.viewModel.presentationState == .result("Kyiv is quiet"))

        sut.context.currentRegion = .kharkiv
        sut.viewModel.synchronizeWithCurrentContext()
        #expect(sut.viewModel.presentationState == .idle)

        sut.context.currentRegion = .kyivCity
        sut.viewModel.synchronizeWithCurrentContext()
        #expect(sut.viewModel.presentationState == .idle)
    }

    @Test
    func statusOrSnapshotChange_clearsDeliveredResult() async {
        let sut = makeSUT(
            snapshot: makeSnapshot(),
            state: .quiet(lastCheckedAt: checkedAt)
        )
        sut.viewModel.requestExplanation()
        await sut.provider.waitUntilPending()
        await sut.provider.resolve(.success("Quiet"))
        await drainMainThread()
        #expect(sut.viewModel.presentationState == .result("Quiet"))

        sut.context.state = .alarm(lastCheckedAt: checkedAt)
        sut.viewModel.synchronizeWithCurrentContext()
        #expect(sut.viewModel.presentationState == .idle)

        sut.context.state = .quiet(lastCheckedAt: checkedAt.addingTimeInterval(5))
        sut.viewModel.synchronizeWithCurrentContext()
        #expect(sut.viewModel.presentationState == .idle)

        sut.context.lastSnapshot = makeSnapshot(checkedAt: checkedAt.addingTimeInterval(10))
        sut.viewModel.synchronizeWithCurrentContext()
        #expect(sut.viewModel.presentationState == .idle)
    }

    @Test
    func contextChange_allowsNewRequestAndIgnoresObsoleteResult() async {
        let sut = makeSUT(
            snapshot: makeSnapshot(),
            state: .quiet(lastCheckedAt: checkedAt)
        )
        sut.viewModel.requestExplanation()
        await sut.provider.waitUntilPending()

        // Context changes while the request is in flight.
        sut.context.lastSnapshot = makeSnapshot(checkedAt: checkedAt.addingTimeInterval(60))
        sut.context.state = .alarm(lastCheckedAt: checkedAt)
        sut.viewModel.synchronizeWithCurrentContext()
        sut.viewModel.requestExplanation()
        await sut.provider.waitUntilPending(count: 2)

        #expect(await sut.provider.requestCount() == 2)
        await sut.provider.resolve(.success("Stale text"))
        await drainMainThread()
        #expect(sut.viewModel.presentationState == .loading)

        await sut.provider.resolve(.success("Current text"))
        await drainMainThread()
        #expect(sut.viewModel.presentationState == .result("Current text"))
        #expect(sut.viewModel.isFailure == false)
    }

    @Test
    func repeatedTapsWhileLoading_doNotCreateConcurrentRequests() async {
        let sut = makeSUT(
            snapshot: makeSnapshot(),
            state: .quiet(lastCheckedAt: checkedAt)
        )
        sut.viewModel.requestExplanation()
        sut.viewModel.requestExplanation()
        sut.viewModel.retryExplanation()
        await sut.provider.waitUntilPending()
        #expect(await sut.provider.requestCount() == 1)
        #expect(await sut.provider.pendingCount() == 1)
        #expect(sut.viewModel.presentationState == .loading)

        await sut.provider.resolve(.success("Once"))
        await drainMainThread()
        #expect(sut.viewModel.presentationState == .result("Once"))
    }

    private func drainMainThread() async {
        await Task.yield()
        await Task.yield()
    }
}
