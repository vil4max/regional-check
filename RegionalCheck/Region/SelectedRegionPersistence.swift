import Foundation
import RegionalCheckDomain

struct SelectedRegionPersistence {
    static let shared = SelectedRegionPersistence(userDefaults: .standard)

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func load() -> Record? {
        if let data = userDefaults.data(forKey: Keys.v1Key),
           let record = try? JSONDecoder().decode(Record.self, from: data)
        {
            return record
        }

        if let migrated = migrateFromLegacyIfPossible() {
            save(migrated)
            return migrated
        }

        return nil
    }

    func save(_ record: Record) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        userDefaults.set(data, forKey: Keys.v1Key)
    }

    private func migrateFromLegacyIfPossible() -> Record? {
        if let raw = userDefaults.string(forKey: Keys.legacyKind),
           raw == "kyivCity"
        {
            return Record(kind: .kyivCity, title: "Kyiv")
        }

        if let name = userDefaults.string(forKey: Keys.legacyOblastName), !name.isEmpty {
            return Record(kind: .region(name: name), title: name)
        }

        return nil
    }

    private enum Keys {
        static let v1Key = "selected_region_v1"
        static let legacyKind = "selected_region_kind"
        static let legacyOblastName = "selected_oblast_name"
    }

    struct Record: Codable, Sendable, Equatable {
        let kind: Kind
        let title: String

        enum Kind: Codable, Sendable, Equatable {
            case kyivCity
            case region(name: String)
        }

        var region: AlertRegion {
            switch kind {
            case .kyivCity:
                return .kyivCity
            case .region(let name):
                return AlertRegion(kind: .oblast(name: name))
            }
        }
    }
}

