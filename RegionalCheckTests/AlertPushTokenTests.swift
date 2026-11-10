import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// The Live Activity record on the server (ALERT-push AC-2, AC-9): sent while Live Activities are
/// allowed, whatever the notice switch, and forgotten when they are not.
@MainActor
struct AlertPushTokenTests {
    @Test("ALERT-push AC-2 the start token and region are sent only while Live Activities are allowed")
    func startTokenNeedsLiveActivitiesAllowed() async {
        let rig = LiveActivityRig(region: .kharkiv)

        rig.registrar.startTokenDidChange(Data([0x01]))
        await rig.registrar.idle()
        #expect(rig.client.puts.isEmpty)

        rig.registrar.liveActivitiesAllowedDidChange(true)
        await rig.registrar.idle()
        #expect(rig.client.puts == [rig.record(start: "01", activity: nil)])
    }

    @Test("ALERT-push AC-9 the running activity's update token reaches the server, and a new one replaces it")
    func activityTokenIsSentAndReplaced() async {
        let rig = LiveActivityRig(region: .kharkiv)
        rig.registrar.liveActivitiesAllowedDidChange(true)
        rig.registrar.startTokenDidChange(Data([0x01]))

        rig.registrar.activityTokenDidChange(Data([0xAA]))
        rig.registrar.activityTokenDidChange(Data([0xBB]))
        await rig.registrar.idle()

        // Tokens that arrive before a sync runs collapse into the newest one.
        #expect(rig.client.puts.last == rig.record(start: "01", activity: "bb"))
    }

    @Test("ALERT-push AC-2 a new start token replaces the old record, which is deleted")
    func newStartTokenDeletesTheOld() async {
        let rig = LiveActivityRig(region: .kharkiv)
        rig.registrar.liveActivitiesAllowedDidChange(true)
        rig.registrar.startTokenDidChange(Data([0x01]))
        await rig.registrar.idle()

        rig.registrar.startTokenDidChange(Data([0x02]))
        await rig.registrar.idle()

        #expect(rig.client.puts.last?.startToken == "02")
        #expect(rig.client.deletes == ["01"])
    }

    @Test("ALERT-push AC-2 turning Live Activities off deletes the record; on again sends it again")
    func disallowingDeletes() async {
        let rig = LiveActivityRig(region: .kharkiv)
        rig.registrar.liveActivitiesAllowedDidChange(true)
        rig.registrar.startTokenDidChange(Data([0x01]))
        await rig.registrar.idle()

        rig.registrar.liveActivitiesAllowedDidChange(false)
        await rig.registrar.idle()
        #expect(rig.client.deletes == ["01"])

        rig.registrar.liveActivitiesAllowedDidChange(true)
        await rig.registrar.idle()
        #expect(rig.client.puts.count == 2)
    }

    @Test("ALERT-push AC-2 the Kyiv fallback is never sent as the region")
    func fallbackRegionIsNotSent() async {
        let rig = LiveActivityRig(region: nil)
        rig.registrar.liveActivitiesAllowedDidChange(true)
        rig.registrar.startTokenDidChange(Data([0x01]))
        await rig.registrar.idle()

        #expect(rig.client.puts.isEmpty)
    }

    @Test("ALERT-push AC-1 REQ-PUSH-003 a delete that failed offline is retried on the next foreground")
    func failedDeleteIsRetriedOnForeground() async {
        let rig = LiveActivityRig(region: .kharkiv)
        rig.registrar.liveActivitiesAllowedDidChange(true)
        rig.registrar.startTokenDidChange(Data([0x01]))
        await rig.registrar.idle()

        rig.client.isOffline = true
        rig.registrar.liveActivitiesAllowedDidChange(false)
        await rig.registrar.idle()
        #expect(rig.client.deletes.isEmpty)

        rig.client.isOffline = false
        await rig.registrar.sceneDidBecomeActive()
        #expect(rig.client.deletes == ["01"])
    }

    @Test("ALERT-push AC-9 REQ-PUSH-003 a token PUT that failed offline is retried on the next foreground")
    func failedPutIsRetriedOnForeground() async {
        let rig = LiveActivityRig(region: .kharkiv)
        rig.client.isOffline = true
        rig.registrar.liveActivitiesAllowedDidChange(true)
        rig.registrar.startTokenDidChange(Data([0x01]))
        rig.registrar.activityTokenDidChange(Data([0xAB]))
        await rig.registrar.idle()

        rig.client.isOffline = false
        await rig.registrar.sceneDidBecomeActive()
        #expect(rig.client.puts == [rig.record(start: "01", activity: "ab")])
    }
}

@MainActor
final class LiveActivityRig {
    let regions: FakePushRegions
    let client = FakeLiveActivityPushClient()
    let registrar: LiveActivityPushRegistrar

    init(region: AlertRegion?) {
        regions = FakePushRegions(region: region)
        let suite = "vil4max.RegionalCheck.liveActivityPush.\(UUID().uuidString)"
        registrar = LiveActivityPushRegistrar(
            regions: regions,
            client: client,
            defaults: UserDefaults(suiteName: suite) ?? .standard,
            locale: { Locale(identifier: "uk_UA") },
            environment: .sandbox
        )
    }

    func record(start: String, activity: String?) -> LiveActivityPushRecord {
        LiveActivityPushRecord(
            startToken: start, region: "kharkiv", env: "sandbox", lang: "uk", activityToken: activity)
    }
}

final class FakeLiveActivityPushClient: LiveActivityPushSending, @unchecked Sendable {
    private(set) var puts: [LiveActivityPushRecord] = []
    private(set) var deletes: [String] = []
    var isOffline = false

    func put(_ record: LiveActivityPushRecord) async throws {
        guard !isOffline else { throw URLError(.notConnectedToInternet) }
        puts.append(record)
    }

    func delete(startToken: String) async throws {
        guard !isOffline else { throw URLError(.notConnectedToInternet) }
        deletes.append(startToken)
    }
}
