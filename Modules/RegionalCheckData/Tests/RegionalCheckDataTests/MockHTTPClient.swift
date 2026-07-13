import Foundation
import RegionalCheckData

final class MockHTTPClient: HTTPClient {
    enum StubbedResult {
        case success(Data, URLResponse)
        case failure(any Error)
    }

    private let result: StubbedResult

    init(result: StubbedResult) {
        self.result = result
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        switch result {
        case .success(let data, let response):
            return (data, response)
        case .failure(let error):
            throw error
        }
    }
}

