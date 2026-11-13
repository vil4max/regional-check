import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

/// MAP-sync: the inline map follows the status it sits under. A loaded map reloads when an
/// accepted snapshot changes the set of regions in alarm, never shows an image of another set,
/// and every map request bypasses the local HTTP cache.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct MapViewModelSyncTests {
    private let kyiv = TestSnapshots.alarms([.kyivCity])
    private let kyivAndOblast = TestSnapshots.alarms([.kyivCity, .kyivOblast])

    @Test("REQ-PROVIDER-002 MAP-sync AC-1 a status that changes the alarm set reloads the loaded map once")
    func alarmSetChangeReloadsOnce() async throws {
        let rig = try SyncRig(snapshot: kyiv, images: [0x01, 0x02, 0x03])

        rig.model.appear()
        await rig.drain()
        #expect(rig.client.requestCount == 1)

        rig.status.snapshot = kyivAndOblast
        rig.model.statusDidChange()
        await rig.drain()
        #expect(rig.client.requestCount == 2)
        #expect(rig.model.visibleImageData == Data([0x02]))
        // The new trigger keeps the polite order: settle, then the delay, then the request.
        #expect(rig.events.suffix(3) == ["settle", "delay", "request"])

        // A new snapshot with the same set (only the check time moves) adds no request.
        rig.status.snapshot = TestSnapshots.alarms([.kyivOblast, .kyivCity])
        rig.model.statusDidChange()
        await rig.drain()
        #expect(rig.client.requestCount == 2)
        #expect(rig.model.visibleImageData == Data([0x02]))
    }

    @Test("REQ-PROVIDER-002 MAP-sync AC-1 a map loaded before any snapshot reloads once the first one arrives")
    func firstSnapshotAfterAnImageReloads() async throws {
        let rig = try SyncRig(snapshot: nil, images: [0x01, 0x02])

        rig.model.appear()
        await rig.drain()
        #expect(rig.model.visibleImageData == Data([0x01]))

        rig.status.snapshot = kyiv
        rig.model.statusDidChange()
        await rig.drain()
        #expect(rig.client.requestCount == 2)
        #expect(rig.model.visibleImageData == Data([0x02]))
    }

    @Test("REQ-PROVIDER-002 MAP-sync AC-1 an alarm-set change sends nothing outside a live loaded session")
    func alarmSetChangeOutsideALoadedSessionIsSilent() async throws {
        // Never loaded: a CarPlay-only launch polls without the phone card ever appearing.
        let neverLoaded = try SyncRig(snapshot: kyiv, images: [0x01])
        neverLoaded.status.snapshot = kyivAndOblast
        neverLoaded.model.statusDidChange()
        await neverLoaded.drain()
        #expect(neverLoaded.client.requestCount == 0)

        // Session ended: the phone went to the background while CarPlay keeps polling.
        let backgrounded = try SyncRig(snapshot: kyiv, images: [0x01, 0x02])
        backgrounded.model.appear()
        await backgrounded.drain()
        backgrounded.model.endForegroundSession()
        backgrounded.status.snapshot = kyivAndOblast
        backgrounded.model.statusDidChange()
        await backgrounded.drain()
        #expect(backgrounded.client.requestCount == 1)

        // Failed: only a pull or a new session retries a hidden map.
        let failed = try SyncRig(snapshot: kyiv, results: [.failure(statusCode: 500)])
        failed.model.appear()
        await failed.drain()
        #expect(failed.model.loadFailed)
        failed.status.snapshot = kyivAndOblast
        failed.model.statusDidChange()
        await failed.drain()
        #expect(failed.client.requestCount == 1)
    }

}

/// MAP-sync AC-2: the pull reloads the map only behind a status request of its own.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct MapViewModelPullSyncTests {
    private let kyiv = TestSnapshots.alarms([.kyivCity])
    private let kyivAndOblast = TestSnapshots.alarms([.kyivCity, .kyivOblast])

    @Test("REQ-PROVIDER-002 MAP-sync AC-2 a pull reloads a loaded map only after its own status request")
    func pullReloadsALoadedMapAfterAFetchedStatus() async throws {
        let rig = try SyncRig(snapshot: kyiv, images: [0x01, 0x02])
        rig.model.appear()
        await rig.drain()

        // Held by the REQ-REFRESH-010 floor, failed or rate-limited: no status left, so no map.
        rig.model.refreshFromPull(statusWasFetched: false)
        await rig.drain()
        #expect(rig.client.requestCount == 1)

        rig.model.refreshFromPull(statusWasFetched: true)
        // Same set: the image stays on screen until the new one lands.
        #expect(rig.model.visibleImageData == Data([0x01]))
        await rig.drain()
        #expect(rig.client.requestCount == 2)
        #expect(rig.model.visibleImageData == Data([0x02]))
        #expect(rig.events.suffix(3) == ["settle", "delay", "request"])
    }

    @Test("REQ-PROVIDER-002 MAP-sync AC-2 a pull retries a failed map and leaves a never-loaded one")
    func pullRetriesAFailedMapAndSkipsANeverLoadedOne() async throws {
        for fetched in [false, true] {
            let rig = try SyncRig(snapshot: kyiv, results: [.failure(statusCode: 500), .image(0x02)])
            rig.model.appear()
            await rig.drain()
            rig.model.refreshFromPull(statusWasFetched: fetched)
            await rig.drain()
            #expect(rig.client.requestCount == 2, "fetched: \(fetched)")
            #expect(rig.model.visibleImageData == Data([0x02]), "fetched: \(fetched)")
        }

        let neverLoaded = try SyncRig(snapshot: kyiv, images: [0x01])
        neverLoaded.model.refreshFromPull(statusWasFetched: true)
        await neverLoaded.drain()
        #expect(neverLoaded.client.requestCount == 0)
    }

    @Test("REQ-PROVIDER-002 MAP-sync AC-2 a pull that also changes the alarm set sends one map request")
    func pullThatChangesTheSetSendsOneRequest() async throws {
        for pullFirst in [true, false] {
            let rig = try SyncRig(snapshot: kyiv, images: [0x01, 0x02, 0x03])
            rig.model.appear()
            await rig.drain()

            rig.status.snapshot = kyivAndOblast
            if pullFirst {
                rig.model.refreshFromPull(statusWasFetched: true)
                rig.model.statusDidChange()
            } else {
                rig.model.statusDidChange()
                rig.model.refreshFromPull(statusWasFetched: true)
            }
            #expect(rig.model.visibleImageData == nil, "pull first: \(pullFirst)")
            await rig.drain()
            #expect(rig.client.requestCount == 2, "pull first: \(pullFirst)")
            #expect(rig.model.visibleImageData == Data([0x02]), "pull first: \(pullFirst)")
        }
    }

}

extension MapViewModelSyncTests {
    @Test("MAP-sync AC-3 the card never shows an image of another alarm set")
    func noImageOfAnotherSet() async throws {
        let rig = try SyncRig(snapshot: kyiv, results: [.image(0x01), .failure(statusCode: 500)])
        rig.model.appear()
        await rig.drain()
        #expect(rig.model.visibleImageData == Data([0x01]))

        // The status moves before any observer or task has run: the old picture is already gone.
        rig.status.snapshot = kyivAndOblast
        #expect(rig.model.visibleImageData == nil)

        rig.model.statusDidChange()
        #expect(rig.model.visibleImageData == nil)
        await rig.drain()
        #expect(rig.model.loadFailed)
        #expect(rig.model.visibleImageData == nil)
    }

    @Test("MAP-sync AC-6 VoiceOver names the alarm set of the image on screen")
    func labelMatchesTheShownImage() async throws {
        let rig = try SyncRig(snapshot: kyiv, images: [0x01, 0x02])
        rig.model.appear()
        await rig.drain()
        #expect(rig.model.visibleImageData == Data([0x01]))
        #expect(rig.model.accessibilityLabel == mapAccessibilityLabel(snapshot: kyiv))

        // Between the status change and the new image no image is shown, so no label is paired
        // with a picture of the other set.
        rig.status.snapshot = kyivAndOblast
        #expect(rig.model.visibleImageData == nil)

        rig.model.statusDidChange()
        await rig.drain()
        #expect(rig.model.visibleImageData == Data([0x02]))
        #expect(rig.model.accessibilityLabel == mapAccessibilityLabel(snapshot: kyivAndOblast))
        #expect(rig.model.accessibilityLabel != mapAccessibilityLabel(snapshot: kyiv))
    }

    @Test("MAP-sync AC-7 the map caption gives the load time only under a shown map")
    func captionGivesTheLoadTime() async throws {
        let loadedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let status = SyncStatusStub(snapshot: kyiv)
        let client = SyncGatedHTTPClient()
        let model = MapViewModel(statusSource: status, httpClient: client, now: { loadedAt }, sleep: { _ in })
        let time = loadedAt.formatted(date: .omitted, time: .shortened)

        // Loading: no caption, the line is only reserved.
        model.appear()
        try #require(await eventually { client.requestCount == 1 })
        #expect(model.updatedCaption == nil)

        try client.finish(request: 1, byte: 0x01)
        try #require(await eventually { model.visibleImageData != nil })
        #expect(model.updatedCaption == "Map updated \(time)")

        // The status moved to another set: the image is hidden, and so is its time.
        status.snapshot = kyivAndOblast
        #expect(model.updatedCaption == nil)
    }

    @Test("MAP-sync AC-7 a failed map has no caption")
    func failedMapHasNoCaption() async throws {
        let rig = try SyncRig(snapshot: kyiv, results: [.failure(statusCode: 500)])
        rig.model.appear()
        await rig.drain()
        #expect(rig.model.loadFailed)
        #expect(rig.model.updatedCaption == nil)
    }

    @Test("MAP-sync AC-4 the map request bypasses the local cache")
    func mapRequestBypassesTheCache() async throws {
        let rig = try SyncRig(snapshot: kyiv, images: [0x01, 0x02, 0x03])
        rig.model.appear()
        await rig.drain()
        rig.status.snapshot = kyivAndOblast
        rig.model.statusDidChange()
        await rig.drain()
        rig.model.refreshFromPull(statusWasFetched: true)
        await rig.drain()

        #expect(rig.client.cachePolicies == Array(repeating: .reloadIgnoringLocalCacheData, count: 3))
    }

    @Test("MAP-sync AC-5 a status change while the delay runs adds no second request")
    func changeDuringTheDelayKeepsOneRequest() async throws {
        let rig = try SyncRig(snapshot: kyiv, images: [0x01, 0x02])
        rig.status.blockUntilResolved()

        rig.model.appear()
        rig.status.snapshot = kyivAndOblast
        rig.model.statusDidChange()
        rig.status.resolveSettled()
        await rig.drain()

        #expect(rig.client.requestCount == 1)
        #expect(rig.model.visibleImageData == Data([0x01]))
    }

    @Test("MAP-sync AC-5 a status change after the request left supersedes it")
    func changeAfterTheRequestSupersedesIt() async throws {
        let client = SyncGatedHTTPClient()
        let status = SyncStatusStub(snapshot: kyiv)
        let model = MapViewModel(statusSource: status, httpClient: client, sleep: { _ in })

        model.appear()
        try #require(await eventually { client.requestCount == 1 })
        status.snapshot = kyivAndOblast
        model.statusDidChange()
        try #require(await eventually { client.requestCount == 2 })
        // The newer request lands first; the older one arrives late and must not overwrite it.
        try client.finish(request: 2, byte: 0x02)
        try #require(await eventually { model.imageData == Data([0x02]) })
        try client.finish(request: 1, byte: 0x01)
        // Gives the older generation's task its turns to (wrongly) apply the late reply.
        for _ in 0..<20 { await Task.yield() }

        #expect(model.imageData == Data([0x02]))
        #expect(model.visibleImageData == Data([0x02]))
    }
}
