import Foundation

struct RegionStore {
    static let shared = RegionStore(userDefaults: .standard)

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func load() -> AlertRegion? {
        guard let data = userDefaults.data(forKey: Keys.v1Key) else { return nil }
        return try? JSONDecoder().decode(AlertRegion.self, from: data)
    }

    func save(_ region: AlertRegion) {
        guard let data = try? JSONEncoder().encode(region) else { return }
        userDefaults.set(data, forKey: Keys.v1Key)
    }

    private enum Keys {
        static let v1Key = "selected_region_v1"
    }
}
