import DriveCheckKit
import Foundation
import Testing

/// REQ-SURF-014: `ContentState` is a contract with the live server's pushes. ActivityKit decodes a
/// push's `content-state` with a default `JSONDecoder`, so dates are seconds since 2001-01-01.
struct ActivityContentStateTests {
    /// The keys a 3.3 server sends and a 3.3 app decodes; the new field must not rename any.
    private static let keysOf33 = ["checkedAt", "isStale", "phase", "regionTitle", "sourceLabel"]

    @Test("REQ-SURF-014 ContentState decodes the server's JSON without alertStartedAt")
    func decodesAPushWithoutTheStart() throws {
        let json = """
            {"phase":"alarm","regionTitle":"Kyiv","checkedAt":816175714,"sourceLabel":"","isStale":false}
            """
        let state = try JSONDecoder().decode(
            DriveCheckActivityAttributes.ContentState.self, from: Data(json.utf8))

        #expect(state.phase == .alarm)
        #expect(state.checkedAt == Date(timeIntervalSinceReferenceDate: 816_175_714))
        #expect(state.alertStartedAt == nil)
    }

    @Test("REQ-SURF-014 ContentState decodes the server's JSON with alertStartedAt")
    func decodesAPushWithTheStart() throws {
        let json = """
            {"phase":"alarm","regionTitle":"Kyiv","checkedAt":816175714,"sourceLabel":"",\
            "isStale":false,"alertStartedAt":816175000}
            """
        let state = try JSONDecoder().decode(
            DriveCheckActivityAttributes.ContentState.self, from: Data(json.utf8))

        #expect(state.alertStartedAt == Date(timeIntervalSinceReferenceDate: 816_175_000))
    }

    @Test("REQ-SURF-014 the app's own content keeps the 3.3 keys and adds the start only when known")
    func encodesTheSameKeysAsBefore() throws {
        var state = DriveCheckActivityAttributes.ContentState(
            phase: .alarm, regionTitle: "Kyiv", checkedAt: Date(timeIntervalSinceReferenceDate: 1),
            sourceLabel: "", isStale: false)
        #expect(try Self.keys(of: state) == Self.keysOf33)

        state.alertStartedAt = Date(timeIntervalSinceReferenceDate: 0)
        #expect(try Self.keys(of: state) == (Self.keysOf33 + ["alertStartedAt"]).sorted())
    }

    private static func keys(of state: DriveCheckActivityAttributes.ContentState) throws -> [String] {
        let data = try JSONEncoder().encode(state)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return object.keys.sorted()
    }
}
