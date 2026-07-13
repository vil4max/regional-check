import Foundation
import RegionalCheckDomain
import os

public enum UbillingProviderError: Error, Equatable, LocalizedError {
    case missingRegionKey(String)
    case unexpectedResponse(statusCode: Int?, contentType: String?, bodyPrefix: String)

    public var errorDescription: String? {
        switch self {
        case .missingRegionKey(let key):
            return "Service error: missing region data."
        case .unexpectedResponse(let statusCode, _, _):
            switch statusCode {
            case .some(429):
                return "Service is rate limiting requests. Please try again in a minute."
            case .some(let code) where (500...599).contains(code):
                return "Service is temporarily unavailable. Please try again later."
            default:
                return "Service returned an unexpected response. Please try again."
            }
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .missingRegionKey:
            return nil
        case .unexpectedResponse(let statusCode, _, _):
            if statusCode == 429 {
                return "Wait a bit and tap Refresh again."
            }
            return nil
        }
    }
}

public struct UbillingAirAlertProvider: AirAlertProviding {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "RegionalCheckData")

    private let httpClient: any HTTPClient
    private let now: @Sendable () -> Date

    public init(httpClient: any HTTPClient = URLSession.shared, now: @escaping @Sendable () -> Date = Date.init) {
        self.httpClient = httpClient
        self.now = now
    }

    public func fetchStatus(region: AlertRegion) async throws -> AlertStatusSnapshot {
        let snapshot = try await fetchSnapshot()

        let regionKey = ubillingKey(for: region)
        guard let state = snapshot.states[regionKey] else {
            throw UbillingProviderError.missingRegionKey(regionKey)
        }

        return AlertStatusSnapshot(
            region: region,
            status: state.alertnow ? .alarm : .quiet,
            checkedAt: now(),
            source: snapshot.source
        )
    }

    public func fetchAllOblastStatuses() async throws -> [AlertStatusSnapshot] {
        let snapshot = try await fetchSnapshot()
        let checkedAt = now()

        return snapshot.states.map { key, value in
            AlertStatusSnapshot(
                region: AlertRegion(kind: .oblast(name: key)),
                status: value.alertnow ? .alarm : .quiet,
                checkedAt: checkedAt,
                source: snapshot.source
            )
        }
    }

    private func fetchSnapshot(source: String? = nil) async throws -> UbillingSnapshotDTO {
        var components = URLComponents(string: "https://ubilling.net.ua/aerialalerts/")!
        if let source {
            components.queryItems = [URLQueryItem(name: "source", value: source)]
        }

        let url = components.url!
        let (data, response) = try await httpClient.data(from: url)

        if let http = response as? HTTPURLResponse {
            let statusCode = http.statusCode
            let contentType = http.value(forHTTPHeaderField: "Content-Type")

            if !(200...299).contains(statusCode) {
                let prefix = Self.bodyPrefix(data)
                if statusCode == 429 {
                    Self.log.error("Ubilling HTTP 429 contentType=\(contentType ?? "nil", privacy: .public)")
                } else {
                    Self.log.error("Ubilling HTTP \(statusCode) contentType=\(contentType ?? "nil", privacy: .public)")
#if DEBUG
                    Self.log.debug("Ubilling bodyPrefix=\(prefix, privacy: .public)")
#endif
                }
                throw UbillingProviderError.unexpectedResponse(statusCode: statusCode, contentType: contentType, bodyPrefix: prefix)
            }

            if let contentType, !contentType.localizedCaseInsensitiveContains("application/json") {
                let prefix = Self.bodyPrefix(data)
                Self.log.error("Ubilling non-JSON contentType=\(contentType, privacy: .public)")
#if DEBUG
                Self.log.debug("Ubilling bodyPrefix=\(prefix, privacy: .public)")
#endif
                throw UbillingProviderError.unexpectedResponse(statusCode: statusCode, contentType: contentType, bodyPrefix: prefix)
            }
        }

        do {
            return try JSONDecoder().decode(UbillingSnapshotDTO.self, from: data)
        } catch {
            let prefix = Self.bodyPrefix(data)
            Self.log.error("Ubilling decode failed: \(String(describing: error), privacy: .public)")
#if DEBUG
            Self.log.debug("Ubilling bodyPrefix=\(prefix, privacy: .public)")
#endif
            throw UbillingProviderError.unexpectedResponse(
                statusCode: (response as? HTTPURLResponse)?.statusCode,
                contentType: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type"),
                bodyPrefix: prefix
            )
        }
    }

    private func ubillingKey(for region: AlertRegion) -> String {
        switch region.kind {
        case .kyivCity:
            return "м. Київ"
        case .oblast(let name):
            return name
        }
    }

    private static func bodyPrefix(_ data: Data, maxBytes: Int = 240) -> String {
        guard !data.isEmpty else { return "<empty>" }
        let slice = data.prefix(maxBytes)
        return String(data: slice, encoding: .utf8) ?? "<non-utf8 \(slice.count) bytes>"
    }
}

