#if DEBUG
    import CoreLocation
    import DriveCheckKit
    import Foundation
    import Synchronization
    import UIKit

    /// Offline, fixed-clock dependency graph for SwiftUI previews and scenario tests.
    ///
    /// Every async dependency answers immediately from memory, so a preview or a
    /// Prefire snapshot renders the same settled state on every run. Production
    /// code never reaches this file (DEBUG only).
    @MainActor
    extension AppContainer {
        static let fixtureNow = FixtureNetwork.servedAt

        static func fixture(
            region: AlertRegion = .kyivCity,
            network: FixtureNetwork = FixtureNetwork(),
            isPro: Bool = false,
            hasCachedSnapshot: Bool = true,
            defaultsSuite: String = "vil4max.RegionalCheck.fixture",
            // Hermetic default: a real `LocationManager()` reads whatever location permission
            // the current simulator happens to have granted this bundle ID (RD-8b flake).
            locationAuthorization: CLAuthorizationStatus = .notDetermined,
            locationFix: LocationFix? = nil,
            // iOS Settings' per-app Live Activities switch; hermetic, never the simulator's own.
            liveActivitiesAllowed: Bool = true,
            // The status clock only. Fixed by default; a test that needs two real fetches injects
            // one it can advance, because REQ-REFRESH-010 holds a second fetch at the same instant.
            clock: (() -> Date)? = nil
        ) -> AppContainer {
            let defaults = UserDefaults(suiteName: defaultsSuite) ?? .standard
            defaults.removePersistentDomain(forName: defaultsSuite)

            let now = fixtureNow
            let store = SharedStore(userDefaults: defaults, legacyDefaults: defaults)
            store.saveRegion(region)
            if hasCachedSnapshot {
                store.saveSnapshot(network.snapshot(fetchedAt: now))
            }

            let cache = EntitlementCache(userDefaults: defaults)
            if isPro {
                cache.save(EntitlementSnapshot(
                    productID: SubscriptionProductID.yearly.rawValue,
                    expirationDate: now.addingTimeInterval(10 * 365 * 86400),
                    isActive: true,
                    source: "fixture",
                    verifiedAt: now
                ))
            }

            let reloader = FixtureWidgetReloader()
            return AppContainer(
                provider: UbillingProvider(httpClient: network, now: { now }, sleep: { _ in }),
                location: FixtureLocationManager(authorizationStatus: locationAuthorization, lastFix: locationFix),
                regions: RegionSelection(
                    store: RegionStore(sharedStore: store),
                    geocoder: FixtureReverseGeocoder(),
                    now: { now }
                ),
                subscription: SubscriptionManager(
                    service: FixtureSubscriptionService(isPro: isPro, now: now),
                    cache: cache,
                    userDefaults: defaults,
                    entitlementPersistence: store,
                    widgetReloader: reloader
                ),
                statusPersistence: store,
                widgetReloader: reloader,
                mapHTTPClient: network,
                mapSleep: { _ in },
                statusDetailsSummarizer: DeterministicStatusDetailsProvider(),
                refreshEnvironment: FixtureRefreshEnvironment(),
                locale: { Locale(identifier: "en_US") },
                now: clock ?? { now },
                liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: liveActivitiesAllowed)
            )
        }
    }

    /// A Settings switch that never changes while the fixture runs.
    struct FixedLiveActivityPermission: LiveActivityPermissionSource {
        let areActivitiesEnabled: Bool

        func enablementUpdates() -> AsyncStream<Bool> {
            AsyncStream { $0.finish() }
        }
    }

    /// Serves both the Ubilling JSON feed and the `?map=` raster from memory.
    final class FixtureNetwork: HTTPClient {
        /// The fixed clock shared by the whole fixture: 2026-09-16 13:41 Kyiv.
        static let servedAt = Date(timeIntervalSince1970: 1_789_555_260)

        private struct State {
            var alarmRegions: Set<AlertRegion>
            var failsRequests = false
            var alertRequests = 0
            var mapRequests = 0
        }

        private let state: Mutex<State>

        init(alarmRegions: Set<AlertRegion> = [.kharkiv, .sumy, .donetsk, .zaporizhzhia]) {
            state = Mutex(State(alarmRegions: alarmRegions))
        }

        var alarmRegions: Set<AlertRegion> {
            get { state.withLock { $0.alarmRegions } }
            set { state.withLock { $0.alarmRegions = newValue } }
        }

        var failsRequests: Bool {
            get { state.withLock { $0.failsRequests } }
            set { state.withLock { $0.failsRequests = newValue } }
        }

        var alertRequestCount: Int {
            state.withLock { $0.alertRequests }
        }

        var mapRequestCount: Int {
            state.withLock { $0.mapRequests }
        }

        func snapshot(fetchedAt: Date) -> AlertsSnapshot {
            let alarms = alarmRegions
            return AlertsSnapshot(
                source: "preview",
                serverCachedAt: fetchedAt,
                fetchedAt: fetchedAt,
                statuses: Dictionary(uniqueKeysWithValues: AlertRegion.allCases.map {
                    ($0, alarms.contains($0) ? AlertStatus.alarm : .quiet)
                })
            )
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            let url = request.url ?? URL(fileURLWithPath: "/")
            let isMap = url.query?.contains("map=") == true
            let (fails, alarms) = state.withLock { state in
                if isMap {
                    state.mapRequests += 1
                } else {
                    state.alertRequests += 1
                }
                return (state.failsRequests, state.alarmRegions)
            }
            if fails {
                throw URLError(.notConnectedToInternet)
            }
            if isMap {
                return (Self.mapImage(alarms: alarms), Self.response(url, contentType: "image/png"))
            }
            return (Self.feed(alarms: alarms), Self.response(url, contentType: "application/json"))
        }

        private static func response(_ url: URL, contentType: String) -> URLResponse {
            HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": contentType])
                ?? URLResponse(url: url, mimeType: contentType, expectedContentLength: 0, textEncodingName: nil)
        }

        private static func feed(alarms: Set<AlertRegion>) -> Data {
            // Upstream stamps `cachedat` in Kyiv local time; match the fixed clock so
            // freshly served data is never stale.
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Europe/Kyiv")
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let stamp = formatter.string(from: servedAt)
            let states = AlertRegion.allCases.map { region in
                "\"\(region.apiKey)\": {\"alertnow\": \(alarms.contains(region)), \"changed\": \"\(stamp)\"}"
            }
            let body = """
            {"source": "preview", "cachedat": "\(stamp)", "states": {\(states.joined(separator: ", "))}}
            """
            return Data(body.utf8)
        }

        /// The all-clear raster, for previews that render the map card already loaded rather than
        /// racing its async load (`MapViewModel.preloaded`).
        static let previewMapImage = mapImage(alarms: [])

        /// A stylized oblast grid, so the card renders a real image without the upstream raster.
        private static func mapImage(alarms: Set<AlertRegion>) -> Data {
            let columns = 5
            let cell = CGFloat(56)
            let regions = AlertRegion.allCases
            let rows = Int((Double(regions.count) / Double(columns)).rounded(.up))
            let size = CGSize(width: CGFloat(columns) * cell, height: CGFloat(rows) * cell)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                for (index, region) in regions.enumerated() {
                    let frame = CGRect(
                        x: CGFloat(index % columns) * cell + 4,
                        y: CGFloat(index / columns) * cell + 4,
                        width: cell - 8,
                        height: cell - 8
                    )
                    let fill = alarms.contains(region)
                        ? UIColor(red: 0.88, green: 0.36, blue: 0.34, alpha: 1)
                        : UIColor(red: 0.42, green: 0.62, blue: 0.52, alpha: 1)
                    fill.setFill()
                    UIBezierPath(roundedRect: frame, cornerRadius: 8).fill()
                }
            }
            return image.pngData() ?? Data()
        }
    }

    struct FixtureWidgetReloader: WidgetReloading {
        func reloadAllTimelines() {}
    }

    struct FixtureReverseGeocoder: ReverseGeocoding {
        func reverseGeocode(coordinate _: CLLocationCoordinate2D) async throws -> GeocodedAddress? {
            nil
        }
    }

    @MainActor
    final class FixtureRefreshEnvironment: RefreshEnvironmentProviding {
        func current(isAlarmActive: Bool) -> RefreshEnvironment {
            RefreshEnvironment(
                isAlarmActive: isAlarmActive,
                isLowPowerModeEnabled: false,
                thermalState: .nominal,
                isExpensiveNetwork: false,
                isConstrainedNetwork: false
            )
        }
    }

    /// A location source with no real CoreLocation permission behind it: `authorizationStatus`
    /// and `lastFix` are exactly whatever the fixture asks for, never whatever this simulator's
    /// bundle ID happens to have been granted for real.
    @MainActor
    final class FixtureLocationManager: CarPlayLocationSource {
        var authorizationStatus: CLAuthorizationStatus
        var lastFix: LocationFix?
        var coordinateStamp = 0

        var isAuthorizationBlocked: Bool {
            LocationAuthorizationPolicy.isBlocked(authorizationStatus)
        }

        init(authorizationStatus: CLAuthorizationStatus = .notDetermined, lastFix: LocationFix? = nil) {
            self.authorizationStatus = authorizationStatus
            self.lastFix = lastFix
        }

        func beginUpdating() {}
        func endUpdating() {}
    }

    struct FixtureSubscriptionService: SubscriptionServicing {
        let isPro: Bool
        let now: Date

        private var entitlement: EntitlementVerification {
            guard isPro else { return .none }
            return .active(EntitlementSnapshot(
                productID: SubscriptionProductID.yearly.rawValue,
                expirationDate: now.addingTimeInterval(10 * 365 * 86400),
                isActive: true,
                source: "fixture",
                verifiedAt: now
            ))
        }

        func loadProducts() async throws -> [SubscriptionProduct] {
            [
                SubscriptionProduct(
                    id: SubscriptionProductID.monthly.rawValue,
                    displayName: "Drive Check Pro",
                    displayPrice: "$1.99",
                    periodDescription: "month"
                ),
                SubscriptionProduct(
                    id: SubscriptionProductID.yearly.rawValue,
                    displayName: "Drive Check Pro",
                    displayPrice: "$14.99",
                    periodDescription: "year"
                )
            ]
        }

        func purchase(productID _: String) async -> PurchaseResult {
            .cancelled
        }

        func currentEntitlement() async -> EntitlementVerification {
            entitlement
        }

        func listenForUpdates() -> AsyncStream<EntitlementVerification> {
            AsyncStream { $0.finish() }
        }

        func restore() async -> EntitlementVerification {
            entitlement
        }
    }
#endif
