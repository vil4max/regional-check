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
        var failsRequests = false
        private var running: [Handle] = []
        private var nextID = 1

        /// An activity a previous process requested and left on screen.
        @discardableResult
        func addSurvivor() -> Int {
            makeHandle().id
        }

        func runningActivities() -> [any LiveActivityHandle] {
            running
        }

        func request(_ content: DriveCheckActivityContent) throws -> any LiveActivityHandle {
            guard !failsRequests else { throw RequestFailure() }
            let handle = makeHandle()
            calls.append(.request(id: handle.id, state: content.state, staleDate: content.staleDate))
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
                running.removeAll { $0.id == id }
            }
        }

        @MainActor
        final class Handle: LiveActivityHandle {
            let id: Int
            private weak var host: FixtureLiveActivityHost?

            fileprivate init(id: Int, host: FixtureLiveActivityHost) {
                self.id = id
                self.host = host
            }

            func update(_ content: DriveCheckActivityContent) async {
                host?.record(.update(id: id, state: content.state, staleDate: content.staleDate))
            }

            func end(_ content: DriveCheckActivityContent?, dismissal: ActivityUIDismissalPolicy) async {
                host?.record(.end(id: id, state: content?.state, dismissal: dismissal))
            }
        }
    }
#endif
