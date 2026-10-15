import DriveCheckKit

enum StatusStateResolver {
    static func resolve(snapshot: AlertsSnapshot, region: AlertRegion) -> StatusState {
        switch snapshot.status(for: region) {
        case .alarm:
            .alarm(lastCheckedAt: snapshot.checkedAt)
        case .quiet:
            .quiet(lastCheckedAt: snapshot.checkedAt)
        case nil:
            .regionUnavailable
        }
    }
}
