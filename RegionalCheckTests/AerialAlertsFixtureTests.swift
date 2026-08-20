import Foundation
@testable import RegionalCheck
import Testing

struct AerialAlertsFixtureTests {
    private static let expectedRegionKeys: Set<String> = [
        "м. Київ",
        "Вінницька область",
        "Волинська область",
        "Дніпропетровська область",
        "Донецька область",
        "Житомирська область",
        "Закарпатська область",
        "Запорізька область",
        "Івано-Франківська область",
        "Київська область",
        "Кіровоградська область",
        "Луганська область",
        "Львівська область",
        "Миколаївська область",
        "Одеська область",
        "Полтавська область",
        "Рівненська область",
        "Сумська область",
        "Тернопільська область",
        "Харківська область",
        "Херсонська область",
        "Хмельницька область",
        "Черкаська область",
        "Чернівецька область",
        "Чернігівська область"
    ]

    @Test
    func fixture_decodesKnownShapeAndRegionKeys() throws {
        let data = try Self.loadFixture()
        let response = try JSONDecoder().decode(UbillingFixtureResponse.self, from: data)

        #expect(response.source.isEmpty == false)
        #expect(response.cachedat.isEmpty == false)
        #expect(Set(response.states.keys) == Self.expectedRegionKeys)
        #expect(response.states.count == 25)

        for (_, region) in response.states {
            #expect(region.changed.isEmpty == false)
        }
    }

    @Test
    func fixture_doesNotIncludeCrimeaOrSevastopol() throws {
        let data = try Self.loadFixture()
        let response = try JSONDecoder().decode(UbillingFixtureResponse.self, from: data)
        #expect(response.states["Автономна Республіка Крим"] == nil)
        #expect(response.states["м. Севастополь"] == nil)
    }

    private static func loadFixture() throws -> Data {
        try TestFixtures.aerialAlertsFixtureData()
    }
}

private struct UbillingFixtureResponse: Decodable {
    struct Region: Decodable {
        let alertnow: Bool
        let changed: String
    }

    let source: String
    let cachedat: String
    let states: [String: Region]
}
