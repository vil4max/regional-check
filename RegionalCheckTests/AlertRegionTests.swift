import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct AlertRegionTests {
    @Test("REQ-REGION-001 the catalog matches the live fixture's API keys")
    func allCases_matchLiveFixtureApiKeys() throws {
        let data = try TestFixtures.aerialAlertsFixtureData()
        let response = try JSONDecoder().decode(Fixture.self, from: data)
        let fixtureKeys = Set(response.states.keys)
        let apiKeys = Set(AlertRegion.allCases.map(\.apiKey))
        #expect(apiKeys == fixtureKeys)
        #expect(AlertRegion.allCases.count == 25)
    }

    @Test("REQ-REGION-001 every catalog API key is unique and non-empty")
    func apiKeys_areUniqueAndNonEmpty() {
        let keys = AlertRegion.allCases.map(\.apiKey)
        #expect(keys.allSatisfy { !$0.isEmpty })
        #expect(Set(keys).count == keys.count)
    }

    @Test
    func titles_areNonEmpty() {
        for region in AlertRegion.allCases {
            #expect(region.title.isEmpty == false)
        }
    }

    @Test("REQ-REGION-001 a known API key resolves to its region")
    func fromApiKey_resolvesKnownKeys() {
        #expect(AlertRegion.from(apiKey: "м. Київ") == .kyivCity)
        #expect(AlertRegion.from(apiKey: "Чернігівська область") == .chernihiv)
        #expect(AlertRegion.from(apiKey: "unknown") == nil)
    }

    @Test("REQ-REGION-002 the legacy stored selection migrates to the current model")
    func regionStore_migratesLegacyKyivAndOblast() throws {
        let suite = "AlertRegion.migration.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let kyivLegacy = Data(#"{"kind":{"kyivCity":{}}}"#.utf8)
        defaults.set(kyivLegacy, forKey: "selected_region_v1")
        let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults, legacyDefaults: defaults))
        #expect(store.load() == .kyivCity)
        #expect(defaults.data(forKey: "selected_region_v1") == nil)
        #expect(defaults.data(forKey: SharedStoreKeys.region) != nil)

        defaults.removePersistentDomain(forName: suite)
        let oblastLegacy = Data(#"{"kind":{"oblast":{"name":"Харківська область"}}}"#.utf8)
        defaults.set(oblastLegacy, forKey: "selected_region_v1")
        let store2 = RegionStore(sharedStore: SharedStore(userDefaults: defaults, legacyDefaults: defaults))
        #expect(store2.load() == .kharkiv)
    }

    private struct Fixture: Decodable {
        let states: [String: FixtureRegion]
    }

    private struct FixtureRegion: Decodable {
        let alertnow: Bool
    }
}
