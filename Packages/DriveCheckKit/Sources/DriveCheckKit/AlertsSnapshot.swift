import Foundation

public struct AlertsSnapshot: Equatable, Sendable, Codable {
    public let source: String
    public let serverCachedAt: Date?
    public let fetchedAt: Date
    public let statuses: [AlertRegion: AlertStatus]
    /// When each region in alarm started, from the feed's `changed` (REQ-SURF-014). Optional so a
    /// snapshot saved before 3.4 still decodes; the feed has no all-clear time, so clear regions
    /// have none.
    public let alarmStartedAt: [AlertRegion: Date]?

    public init(
        source: String,
        serverCachedAt: Date?,
        fetchedAt: Date,
        statuses: [AlertRegion: AlertStatus],
        alarmStartedAt: [AlertRegion: Date]? = nil
    ) {
        self.source = source
        self.serverCachedAt = serverCachedAt
        self.fetchedAt = fetchedAt
        self.statuses = statuses
        self.alarmStartedAt = alarmStartedAt
    }

    public func status(for region: AlertRegion) -> AlertStatus? {
        statuses[region]
    }

    /// When the region's current alarm started, only while the snapshot shows it in alarm.
    public func alarmStart(for region: AlertRegion) -> Date? {
        statuses[region] == .alarm ? alarmStartedAt?[region] : nil
    }

    public var checkedAt: Date {
        serverCachedAt ?? fetchedAt
    }
}
