#if DEBUG
    import ActivityKit
    import DriveCheckKit
    import Foundation

    /// ActivityKit replaced by memory for the fixture and tests: it records every call the
    /// controller makes and lists the activities it has not ended, like the system does.
    @MainActor
    final class FixtureLiveActivityHost: LiveActivityHosting {
        enum Call: Equatable {
            case request(id: Int, state: DriveCheckActivityAttributes.ContentState, staleDate: Date?)
            case update(id: Int, state: DriveCheckActivityAttributes.ContentState, staleDate: Date?)
            case end(id: Int, state: DriveCheckActivityAttributes.ContentState?, dismissal: ActivityUIDismissalPolicy)
        }

        struct RequestFailure: Error {}

        private(set) var calls: [Call] = []
        private var startTokenContinuation: AsyncStream<Data>.Continuation?
        private var newActivityContinuation: AsyncStream<any LiveActivityHandle>.Continuation?
        var failsRequests = false
        private var running: [Handle] = []
        private var nextID = 1

        /// An activity a previous process requested and left on screen; `hasPushToken: false` is
        /// one from a build that requested it without a push type.
        @discardableResult
        func addSurvivor(hasPushToken: Bool = true) -> Int {
            let handle = makeHandle()
            handle.hasPushToken = hasPushToken
            return handle.id
        }

        /// The system ending an activity on its own: a server `end` push, the time limit or a swipe.
        func endBySystem(_ id: Int) {
            handle(id)?.isRunning = false
            running.removeAll { $0.id == id }
        }

        func pushToStartTokens() -> AsyncStream<Data> {
            AsyncStream { startTokenContinuation = $0 }
        }

        func newActivities() -> AsyncStream<any LiveActivityHandle> {
            AsyncStream { newActivityContinuation = $0 }
        }

        /// ActivityKit handing out a new push-to-start token.
        func emitStartToken(_ token: Data) {
            startTokenContinuation?.yield(token)
        }

        /// The system starting an activity from a server push, while the app may not be running.
        /// It counts as reachable at once, as `ActivityKitLiveActivityHost` reports every activity
        /// from `activityUpdates`, although the real token arrives a moment later.
        @discardableResult
        func startByPush(checkedAt: Date?) -> Handle {
            let handle = makeHandle()
            handle.checkedAt = checkedAt
            newActivityContinuation?.yield(handle)
            return handle
        }

        func handle(_ id: Int) -> Handle? {
            running.first { $0.id == id }
        }

        func runningActivities() -> [any LiveActivityHandle] {
            running
        }

        func request(_ content: DriveCheckActivityContent) throws -> any LiveActivityHandle {
            guard !failsRequests else { throw RequestFailure() }
            let handle = makeHandle()
            handle.checkedAt = content.state.checkedAt
            calls.append(.request(id: handle.id, state: content.state, staleDate: content.staleDate))
            // ActivityKit lists an activity the app requested in `activityUpdates` too.
            newActivityContinuation?.yield(handle)
            return handle
        }

        private func makeHandle() -> Handle {
            let handle = Handle(id: nextID, host: self)
            nextID += 1
            running.append(handle)
            return handle
        }

        fileprivate func record(_ call: Call) {
            calls.append(call)
            if case .end(let id, _, _) = call {
                handle(id)?.isRunning = false
                running.removeAll { $0.id == id }
            }
        }

        @MainActor
        final class Handle: LiveActivityHandle {
            let id: Int
            var checkedAt: Date?
            fileprivate(set) var isRunning = true
            fileprivate(set) var hasPushToken = true
            private weak var host: FixtureLiveActivityHost?
            private var tokenContinuation: AsyncStream<Data>.Continuation?

            var activityID: String {
                "\(id)"
            }

            func pushTokens() -> AsyncStream<Data> {
                AsyncStream { tokenContinuation = $0 }
            }

            /// ActivityKit handing out this activity's update token.
            func emitToken(_ token: Data) {
                tokenContinuation?.yield(token)
            }

            fileprivate init(id: Int, host: FixtureLiveActivityHost) {
                self.id = id
                self.host = host
            }

            func update(_ content: DriveCheckActivityContent) async {
                checkedAt = content.state.checkedAt
                host?.record(.update(id: id, state: content.state, staleDate: content.staleDate))
            }

            func end(_ content: DriveCheckActivityContent?, dismissal: ActivityUIDismissalPolicy) async {
                host?.record(.end(id: id, state: content?.state, dismissal: dismissal))
            }
        }
    }
#endif
