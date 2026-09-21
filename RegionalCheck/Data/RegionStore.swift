import DriveCheckKit
import Foundation

struct RegionStore {
    static let shared = RegionStore()

    private let sharedStore: SharedStore

    init(sharedStore: SharedStore = .shared) {
        self.sharedStore = sharedStore
        sharedStore.migrateLegacyRegionIfNeeded()
        sharedStore.removeRetiredSecondaryRegion()
    }

    func load() -> AlertRegion? {
        sharedStore.loadRegion()
    }

    func save(_ region: AlertRegion) {
        sharedStore.saveRegion(region)
    }
}
