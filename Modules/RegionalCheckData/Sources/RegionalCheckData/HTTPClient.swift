import Foundation

public protocol HTTPClient: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

