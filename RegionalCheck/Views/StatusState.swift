import Foundation

/// The status a surface renders, with the wording and symbol each phase shows.
///
/// Its own file because it is a value type with a display contract of its own — views, CarPlay and
/// the widgets read it without going through `StatusController`, which owns only how it is reached.
enum StatusState: Equatable {
    enum Phase: Equatable {
        case idle
        case quiet
        case alarm
        case error
        case regionUnavailable
    }

    case idle
    case quiet(lastCheckedAt: Date)
    case alarm(lastCheckedAt: Date)
    case error
    case regionUnavailable

    var phase: Phase {
        switch self {
        case .idle:
            .idle
        case .quiet:
            .quiet
        case .alarm:
            .alarm
        case .error:
            .error
        case .regionUnavailable:
            .regionUnavailable
        }
    }

    var title: String {
        switch self {
        case .alarm:
            String(localized: "Alert Active")
        case .quiet:
            String(localized: "All Clear")
        case .idle:
            String(localized: "Checking…")
        case .error:
            String(localized: "Unavailable")
        case .regionUnavailable:
            String(localized: "Region Unavailable")
        }
    }

    var symbolName: String {
        switch self {
        case .alarm:
            "exclamationmark.circle.fill"
        case .quiet:
            "checkmark.circle.fill"
        case .idle:
            "arrow.triangle.2.circlepath"
        case .error, .regionUnavailable:
            "questionmark.circle.fill"
        }
    }

    var explanation: String {
        explanation(locale: .current)
    }

    func explanation(locale: Locale) -> String {
        let key: String.LocalizationValue = switch self {
        case .quiet:
            "status.explanation.quiet"
        case .alarm:
            "status.explanation.loud"
        case .idle:
            "status.explanation.updating"
        case .error:
            "status.explanation.unknown"
        case .regionUnavailable:
            "status.explanation.region_unavailable"
        }
        return String(localized: key, bundle: AppLocalization.bundle(for: locale), locale: locale)
    }

    var detailText: String? {
        switch self {
        case let .alarm(lastCheckedAt), let .quiet(lastCheckedAt):
            String(format: String(localized: "Updated: %@"), lastCheckedAt.formatted(date: .omitted, time: .shortened))
        case .error:
            String(localized: "Tap Refresh to try again")
        case .regionUnavailable:
            String(localized: "status.detail.region_unavailable")
        case .idle:
            nil
        }
    }

    var checkedAt: Date? {
        switch self {
        case let .alarm(lastCheckedAt), let .quiet(lastCheckedAt):
            lastCheckedAt
        case .idle, .error, .regionUnavailable:
            nil
        }
    }
}
