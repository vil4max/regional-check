import Foundation

struct RegionStore {
    static let shared = RegionStore(userDefaults: .standard)

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func load() -> AlertRegion? {
        if let data = userDefaults.data(forKey: Keys.v1Key) {
            if let region = try? JSONDecoder().decode(AlertRegion.self, from: data) {
                return region
            }
            if let legacy = try? JSONDecoder().decode(LegacyRecord.self, from: data) {
                let region = legacy.asRegion
                save(region)
                return region
            }
        }

        if userDefaults.string(forKey: Keys.legacyKind) == "kyivCity" {
            let region = AlertRegion.kyivCity
            save(region)
            clearLegacyKeys()
            return region
        }

        if let name = userDefaults.string(forKey: Keys.legacyOblastName), !name.isEmpty {
            let region = AlertRegion(kind: .oblast(name: name))
            save(region)
            clearLegacyKeys()
            return region
        }

        return nil
    }

    func save(_ region: AlertRegion) {
        guard let data = try? JSONEncoder().encode(region) else { return }
        userDefaults.set(data, forKey: Keys.v1Key)
        clearLegacyKeys()
    }

    private func clearLegacyKeys() {
        userDefaults.removeObject(forKey: Keys.legacyKind)
        userDefaults.removeObject(forKey: Keys.legacyOblastName)
    }

    private enum Keys {
        static let v1Key = "selected_region_v1"
        static let legacyKind = "selected_region_kind"
        static let legacyOblastName = "selected_oblast_name"
    }

    private struct LegacyRecord: Decodable {
        enum Kind: Decodable {
            case kyivCity
            case region(name: String)
        }

        let kind: Kind

        var asRegion: AlertRegion {
            switch kind {
            case .kyivCity:
                return .kyivCity
            case .region(let name):
                return AlertRegion(kind: .oblast(name: name))
            }
        }
    }
}
