import DriveCheckKit
import Foundation
import Observation

struct StatusExplanationInput: Equatable, Sendable {
    let snapshot: AlertsSnapshot
    let region: AlertRegion
    let status: StatusState
}

protocol StatusExplanationProviding: Sendable {
    func explanation(for input: StatusExplanationInput) async throws -> String
}

/// Deterministic local baseline. Returns the existing localized explanation for
/// the already resolved status; a future AI implementation replaces this type.
struct LocalStatusExplanationProvider: StatusExplanationProviding {
    func explanation(for input: StatusExplanationInput) async throws -> String {
        input.status.explanation
    }
}

@MainActor
protocol ExplanationStatusContext: AnyObject {
    var lastSnapshot: AlertsSnapshot? { get }
    var currentRegion: AlertRegion { get }
    var state: StatusState { get }
}

extension StatusController: ExplanationStatusContext {}

/// Owns the async user-requested status explanation presentation state.
/// Describes existing status; never decides or mutates alert state.
@MainActor
@Observable
final class StatusExplanationViewModel {
    enum PresentationState: Equatable {
        case idle
        case loading
        case result(String)
        case error
    }

    private let provider: any StatusExplanationProviding
    private let context: any ExplanationStatusContext

    private(set) var isLoading = false
    private(set) var isFailure = false
    private var deliveredResult: (input: StatusExplanationInput, text: String)?
    private var observedInput: StatusExplanationInput?
    private var activeRequestInput: StatusExplanationInput?
    private var requestTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(
        provider: any StatusExplanationProviding,
        context: any ExplanationStatusContext
    ) {
        self.provider = provider
        self.context = context
        observedInput = Self.input(from: context)
    }

    var currentInput: StatusExplanationInput? {
        Self.input(from: context)
    }

    /// The action is available only with a current snapshot and a resolved quiet/alarm state.
    var canRequestExplanation: Bool {
        guard let input = currentInput else { return false }
        return input.status.phase == .quiet || input.status.phase == .alarm
    }

    /// A delivered result is shown only while its input is still current,
    /// so snapshot, region, or status changes reset the presentation implicitly.
    var presentationState: PresentationState {
        if isLoading {
            return .loading
        }
        if isFailure {
            return .error
        }
        if let deliveredResult, deliveredResult.input == currentInput {
            return .result(deliveredResult.text)
        }
        return .idle
    }

    func requestExplanation() {
        synchronizeWithCurrentContext()
        guard !isLoading, canRequestExplanation, let input = currentInput else { return }
        startRequest(for: input)
    }

    func retryExplanation() {
        requestExplanation()
    }

    func synchronizeWithCurrentContext() {
        let input = currentInput
        guard input != observedInput else { return }
        observedInput = input
        requestGeneration += 1
        requestTask?.cancel()
        requestTask = nil
        activeRequestInput = nil
        deliveredResult = nil
        isLoading = false
        isFailure = false
    }

    private func startRequest(for input: StatusExplanationInput) {
        isLoading = true
        isFailure = false
        requestGeneration += 1
        let generation = requestGeneration
        requestTask?.cancel()
        activeRequestInput = input
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await provider.explanation(for: input)
                complete(generation: generation, input: input, result: .success(text))
            } catch is CancellationError {
                complete(generation: generation, input: input, result: .failure(CancellationError()))
            } catch {
                complete(generation: generation, input: input, result: .failure(error))
            }
        }
    }

    private func complete(
        generation: Int,
        input: StatusExplanationInput,
        result: Result<String, any Error>
    ) {
        guard generation == requestGeneration, activeRequestInput == input else { return }
        requestTask = nil
        activeRequestInput = nil
        defer { isLoading = false }
        // A late response for obsolete input must not be displayed.
        guard input == currentInput else { return }
        switch result {
        case let .success(text):
            deliveredResult = (input, text)
            isFailure = false
        case .failure:
            isFailure = true
        }
    }

    private static func input(from context: any ExplanationStatusContext) -> StatusExplanationInput? {
        guard let snapshot = context.lastSnapshot else { return nil }
        return StatusExplanationInput(snapshot: snapshot, region: context.currentRegion, status: context.state)
    }
}
