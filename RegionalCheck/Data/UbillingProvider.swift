import Foundation
import os

enum UbillingError: Error, Equatable {
    case missingRegionKey(String)
    case unexpectedResponse(statusCode: Int?, contentType: String?, bodyPrefix: String)
}

struct UbillingProvider: StatusProviding {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "Data")

    private let httpClient: any HTTPClient
    private let now: @Sendable () -> Date

    init(httpClient: any HTTPClient = URLSession.shared, now: @escaping @Sendable () -> Date = { Date() }) {
        self.httpClient = httpClient
        self.now = now
    }

    func fetchStatus(region: AlertRegion) async throws -> AlertStatusSnapshot {
        let response = try await fetchResponse()
        let regionKey = ubillingKey(for: region)
        guard let state = response.states[regionKey] else {
            throw UbillingError.missingRegionKey(regionKey)
        }

        return AlertStatusSnapshot(
            region: region,
            status: state.alertnow ? .alarm : .quiet,
            checkedAt: now(),
            source: response.source
        )
    }

    private func fetchResponse() async throws -> Response {
        let url = URL(string: "https://ubilling.net.ua/aerialalerts/")!
        let (data, response) = try await httpClient.data(from: url)

        if let http = response as? HTTPURLResponse {
            let statusCode = http.statusCode
            let contentType = http.value(forHTTPHeaderField: "Content-Type")

            if !(200...299).contains(statusCode) {
                let prefix = Self.bodyPrefix(data)
                Self.log.error("Ubilling HTTP \(statusCode) contentType=\(contentType ?? "nil", privacy: .public)")
                throw UbillingError.unexpectedResponse(statusCode: statusCode, contentType: contentType, bodyPrefix: prefix)
            }

            if let contentType, !contentType.localizedCaseInsensitiveContains("application/json") {
                let prefix = Self.bodyPrefix(data)
                Self.log.error("Ubilling non-JSON contentType=\(contentType, privacy: .public)")
                throw UbillingError.unexpectedResponse(statusCode: statusCode, contentType: contentType, bodyPrefix: prefix)
            }
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            let prefix = Self.bodyPrefix(data)
            Self.log.error("Ubilling decode failed: \(String(describing: error), privacy: .public)")
            throw UbillingError.unexpectedResponse(
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

    private struct Response: Decodable {
        struct Region: Decodable {
            let alertnow: Bool
        }

        let source: String
        let states: [String: Region]
    }
}
