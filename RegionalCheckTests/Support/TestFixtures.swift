// swiftlint:disable force_unwrapping
import DriveCheckKit
import Foundation
@testable import RegionalCheck

private final class TestBundleToken {}

enum TestFixtures {
    static let activeEntitlement = EntitlementSnapshot(
        productID: SubscriptionProductID.yearly.rawValue,
        expirationDate: Date().addingTimeInterval(86400),
        isActive: true,
        source: "storekit",
        verifiedAt: Date()
    )

    static func aerialAlertsFixtureData() throws -> Data {
        let bundle = Bundle(for: TestBundleToken.self)
        let url = bundle.url(forResource: "aerialalerts", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "aerialalerts", withExtension: "json")
        guard let url else {
            struct MissingAerialAlertsFixture: Error {}
            throw MissingAerialAlertsFixture()
        }
        return try Data(contentsOf: url)
    }

    static func statusExplanationEvalsData() throws -> Data {
        let bundle = Bundle(for: TestBundleToken.self)
        let url = bundle.url(
            forResource: "status-explanation-evals",
            withExtension: "json",
            subdirectory: "Fixtures"
        ) ?? bundle.url(forResource: "status-explanation-evals", withExtension: "json")
        guard let url else {
            struct MissingExplanationEvalFixture: Error {}
            throw MissingExplanationEvalFixture()
        }
        return try Data(contentsOf: url)
    }

    static func kyivJSON(alertnow: Bool) -> String {
        """
        {
          "source": "test",
          "cachedat": "2026-01-01 00:00:00",
          "states": {
            "м. Київ": { "alertnow": \(alertnow), "changed": "2026-01-01 00:00:00" }
          }
        }
        """
    }

    static func makeProvider(json: String, now: Date = Date()) throws -> UbillingProvider {
        let data = Data(json.utf8)
        let response = HTTPURLResponse(
            url: URL(string: "https://ubilling.net.ua/aerialalerts/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let http = MockHTTPClient(data: data, response: response)
        return UbillingProvider(httpClient: http, now: { now })
    }

    static func quietSnapshot(
        region: AlertRegion = .kyivCity,
        checkedAt: Date = Date(timeIntervalSince1970: 1)
    ) -> AlertsSnapshot {
        AlertsSnapshot(
            source: "test",
            serverCachedAt: checkedAt,
            fetchedAt: checkedAt,
            statuses: [region: .quiet]
        )
    }
}

extension StatusController {
    convenience init(
        region: AlertRegion,
        provider: any StatusProviding,
        environmentProvider: (any RefreshEnvironmentProviding)? = nil,
        jitterUnitInterval: @escaping () -> Double = { Double.random(in: 0 ... 1) },
        now: @escaping () -> Date = { Date() }
    ) {
        self.init(
            region: region,
            provider: provider,
            environmentProvider: environmentProvider,
            persistence: TestStatusPersistence(),
            widgetReloader: TestWidgetReloader(),
            jitterUnitInterval: jitterUnitInterval,
            now: now
        )
    }
}

private final class TestStatusPersistence: StatusPersisting {
    func saveRegion(_: AlertRegion) {}
    func saveSnapshot(_: AlertsSnapshot) {}
    func loadSnapshot() -> AlertsSnapshot? {
        nil
    }
}

struct TestWidgetReloader: WidgetReloading {
    func reloadAllTimelines() {}
}

struct MockStatusProvider: StatusProviding {
    var snapshot: AlertsSnapshot?
    var error: (any Error)?

    func fetchAlerts() async throws -> AlertsSnapshot {
        if let error {
            throw error
        }
        guard let snapshot else {
            struct MissingSnapshot: Error {}
            throw MissingSnapshot()
        }
        return snapshot
    }
}

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    let data: Data
    let response: URLResponse
    var error: (any Error)?
    private(set) var requestCount = 0

    init(data: Data, response: URLResponse, error: (any Error)? = nil) {
        self.data = data
        self.response = response
        self.error = error
    }

    func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        if let error {
            throw error
        }
        return (data, response)
    }
}

final class SequencingHTTPClient: HTTPClient, @unchecked Sendable {
    private var results: [Result<(Data, URLResponse), any Error>]
    private(set) var requestCount = 0

    init(results: [Result<(Data, URLResponse), any Error>]) {
        self.results = results
    }

    func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        guard !results.isEmpty else {
            throw URLError(.unknown)
        }
        return try results.removeFirst().get()
    }
}

final class FakeSubscriptionService: SubscriptionServicing, @unchecked Sendable {
    let products: [SubscriptionProduct]
    var entitlement: EntitlementVerification
    let purchaseResult: PurchaseResult
    let entitlementAfterPurchase: EntitlementSnapshot?
    var restoreEntitlement: EntitlementVerification?
    private var updateContinuation: AsyncStream<EntitlementVerification>.Continuation?

    init(
        products: [SubscriptionProduct],
        entitlement: EntitlementVerification,
        purchaseResult: PurchaseResult = .cancelled,
        entitlementAfterPurchase: EntitlementSnapshot? = nil,
        restoreEntitlement: EntitlementVerification? = nil
    ) {
        self.products = products
        self.entitlement = entitlement
        self.purchaseResult = purchaseResult
        self.entitlementAfterPurchase = entitlementAfterPurchase
        self.restoreEntitlement = restoreEntitlement
    }

    func loadProducts() async throws -> [SubscriptionProduct] {
        products
    }

    func purchase(productID _: String) async -> PurchaseResult {
        if purchaseResult == .success, let entitlementAfterPurchase {
            entitlement = .active(entitlementAfterPurchase)
        }
        return purchaseResult
    }

    func currentEntitlement() async -> EntitlementVerification {
        entitlement
    }

    func listenForUpdates() -> AsyncStream<EntitlementVerification> {
        AsyncStream { continuation in
            updateContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.updateContinuation = nil
            }
        }
    }

    func restore() async -> EntitlementVerification {
        if let restoreEntitlement {
            entitlement = restoreEntitlement
            return restoreEntitlement
        }
        return entitlement
    }

    func push(_ verification: EntitlementVerification) {
        entitlement = verification
        updateContinuation?.yield(verification)
    }
}
