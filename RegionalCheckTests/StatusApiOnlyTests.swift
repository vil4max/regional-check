import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// STATUS-api-only: the app shows only what the feed gives, and a request on old data looks like
/// checking, not like old data.
@MainActor
struct StatusApiOnlyTests {
    private static let now = Date(timeIntervalSince1970: 1_789_560_000)
    private static let old = now.addingTimeInterval(-3 * 3600)

    private static func snapshot(_ status: AlertStatus, at date: Date) -> AlertsSnapshot {
        AlertsSnapshot(source: "test", serverCachedAt: date, fetchedAt: date, statuses: [.kyivCity: status])
    }

    private static func controller(
        cached: AlertsSnapshot, provider: some StatusProviding, now: @escaping () -> Date = { Self.now }
    ) -> StatusController {
        StatusController(
            region: .kyivCity,
            provider: provider,
            environmentProvider: FixtureRefreshEnvironment(),
            persistence: CachedSnapshot(snapshot: cached),
            widgetReloader: TestWidgetReloader(),
            now: now
        )
    }

    @Test("STATUS-api-only AC-4 a request on old quiet data shows Checking, then the status")
    func oldQuietDataChecksWhileTheRequestRuns() async {
        let provider = HeldProvider(result: .success(Self.snapshot(.quiet, at: Self.now)))
        let controller = Self.controller(cached: Self.snapshot(.quiet, at: Self.old), provider: provider)
        #expect(controller.accent == .stale)

        let refresh = Task { await controller.refresh() }
        await provider.waitUntilStarted()
        #expect(controller.accent == .checking)
        #expect(controller.isCheckingOldData)
        #expect(controller.heroSymbolName == Theme.RedesignStatusAccent.checking.symbolName)
        #expect(controller.accent.fullTitle(for: controller.state) == String(localized: "Checking…"))

        provider.release()
        await refresh.value
        #expect(controller.accent == .clear)
        #expect(!controller.isCheckingOldData)
        #expect(controller.heroSymbolName == controller.presentation.symbolName)
    }

    @Test("STATUS-api-only AC-4 a failed request on old data falls back to the grey clock")
    func aFailedRequestShowsTheOldData() async {
        let provider = HeldProvider(result: .failure(URLError(.notConnectedToInternet)))
        let controller = Self.controller(cached: Self.snapshot(.quiet, at: Self.old), provider: provider)

        let refresh = Task { await controller.refresh() }
        await provider.waitUntilStarted()
        #expect(controller.accent == .checking)
        provider.release()
        await refresh.value

        #expect(controller.accent == .stale)
        #expect(controller.heroSymbolName == controller.presentation.symbolName)
    }

    @Test("STATUS-api-only AC-4 an old alarm and fresh data keep their look while a request runs")
    func alarmAndFreshDataDoNotFlicker() async {
        let alarm = HeldProvider(result: .success(Self.snapshot(.alarm, at: Self.now)))
        let oldAlarm = Self.controller(cached: Self.snapshot(.alarm, at: Self.old), provider: alarm)
        let alarmRefresh = Task { await oldAlarm.refresh() }
        await alarm.waitUntilStarted()
        #expect(oldAlarm.accent == .alert)
        #expect(!oldAlarm.isCheckingOldData)
        alarm.release()
        await alarmRefresh.value

        let quiet = HeldProvider(result: .success(Self.snapshot(.quiet, at: Self.now)))
        let fresh = Self.controller(
            cached: Self.snapshot(.quiet, at: Self.now.addingTimeInterval(-30)), provider: quiet)
        let freshRefresh = Task { await fresh.refresh() }
        await quiet.waitUntilStarted()
        #expect(fresh.accent == .clear)
        quiet.release()
        await freshRefresh.value
    }

    @Test("STATUS-api-only AC-4 after a failed request the clock stays through the next retry")
    func noCheckingFlashAfterAFailure() async {
        let provider = HeldProvider(result: .failure(URLError(.notConnectedToInternet)))
        let clock = TestClock(Self.now)
        let controller = Self.controller(
            cached: Self.snapshot(.quiet, at: Self.old), provider: provider, now: { clock.now })
        let first = Task { await controller.refresh() }
        await provider.waitUntilStarted()
        provider.release()
        await first.value

        clock.advancePastFetchFloor()
        let second = Task { await controller.refresh() }
        await provider.waitUntilStarted(count: 2)
        #expect(controller.isLoading)
        #expect(controller.accent == .stale)
        #expect(!controller.isCheckingOldData)
        provider.release()
        await second.value
    }

    @Test("STATUS-api-only AC-3 a stale alarm's meta line says it may be outdated")
    func staleAlarmSaysItMayBeOutdated() {
        let time = Self.old.formatted(date: .omitted, time: .shortened)
        let line = StatusMetaLine.text(accent: .stale, checkedAt: Self.old, mayBeOutdated: true)
        #expect(line == "Updated \(time) · May be outdated")

        // The selection: only a stale alarm says it; old quiet data and a fresh alarm do not.
        let quiet = HeldProvider(result: .failure(URLError(.timedOut)))
        #expect(Self.controller(cached: Self.snapshot(.alarm, at: Self.old), provider: quiet).metaSaysMayBeOutdated)
        #expect(!Self.controller(cached: Self.snapshot(.quiet, at: Self.old), provider: quiet).metaSaysMayBeOutdated)
        #expect(!Self.controller(cached: Self.snapshot(.alarm, at: Self.now), provider: quiet).metaSaysMayBeOutdated)
    }

    @Test("STATUS-api-only AC-3 old data reads Updated with the time, as fresh data does")
    func oldDataReadsUpdated() {
        let time = Self.old.formatted(date: .omitted, time: .shortened)
        let expected = String(format: String(localized: "status.meta.updated"), time)
        #expect(StatusMetaLine.text(accent: .stale, checkedAt: Self.old) == expected)
        #expect(StatusMetaLine.text(accent: .clear, checkedAt: Self.old) == expected)
    }

    @Test("STATUS-api-only AC-1 AC-3 no catalog keeps an app-derived all-clear or Last known")
    func catalogsDropTheRemovedWording() throws {
        let app = try StringCatalog(path: StringCatalog.mainPath)
        let widgets = try StringCatalog(path: StringCatalog.widgetsPath)
        for key in ["status.meta.last_known", "status.reason.allclear", "status.reason.allclear.time"] {
            #expect(app.values[key] == nil, "\(key)")
        }
        for key in ["liveActivity.allClearAt %@", "liveActivity.staleFooter", "widget.status.lastKnownLabel"] {
            #expect(widgets.values[key] == nil, "\(key)")
        }
        for catalog in [app, widgets] {
            for (key, values) in catalog.values {
                for value in values.values {
                    #expect(!value.contains("Last known") && !value.contains("Последнее известное"), "\(key)")
                }
            }
        }
    }
}

private struct CachedSnapshot: StatusPersisting {
    let snapshot: AlertsSnapshot
    func saveSnapshot(_: AlertsSnapshot) {}
    func loadSnapshot() -> AlertsSnapshot? { snapshot }
}

/// Holds the request open until `release()`, so a test can look at the screen mid-request.
@MainActor
private final class HeldProvider: StatusProviding {
    private let result: Result<AlertsSnapshot, any Error>
    private var started: (count: Int, continuation: CheckedContinuation<Void, Never>)?
    private var held: CheckedContinuation<Void, Never>?
    private var starts = 0

    init(result: Result<AlertsSnapshot, any Error>) {
        self.result = result
    }

    func fetchAlerts() async throws -> AlertsSnapshot {
        starts += 1
        if let started, starts >= started.count {
            started.continuation.resume()
            self.started = nil
        }
        await withCheckedContinuation { held = $0 }
        return try result.get()
    }

    /// Returns once `count` requests have started.
    func waitUntilStarted(count: Int = 1) async {
        guard starts < count else { return }
        await withCheckedContinuation { started = (count, $0) }
    }

    func release() {
        held?.resume()
        held = nil
    }
}
