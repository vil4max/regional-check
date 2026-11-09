import DriveCheckKit
import Foundation

/// What the server learns about a device that opted in to the all-clear push (REQ-PUSH-006): the
/// token APNs gave this install, the region, the APNs environment and the language of the text.
/// Nothing else is sent, and the server adds only the time it last heard from the device.
struct PushRegistration: Codable, Equatable, Sendable {
    let token: String
    let region: String
    let env: String
    let lang: String

    enum Environment: String {
        case production
        case sandbox

        static var current: Environment {
            #if DEBUG
                .sandbox
            #else
                .production
            #endif
        }
    }

    /// The server's text is English, Ukrainian or Russian; any other language gets English.
    static func language(for locale: Locale) -> String {
        let code = locale.language.languageCode?.identifier
        return ["en", "uk", "ru"].contains(code) ? code ?? "en" : "en"
    }

    static func tokenString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

protocol PushRegistrationSending: Sendable {
    func put(_ registration: PushRegistration) async throws
    func delete(token: String) async throws
}

/// The registration endpoint of drivecheck-api (`PUT` and `DELETE /v1/push/registration`).
struct URLSessionPushRegistrationClient: PushRegistrationSending {
    static let defaultBaseURL = URL(filePath: "/")

    var baseURL: URL = URL(string: "https://drivecheck.vil4max.com") ?? defaultBaseURL
    var session: URLSession = .shared

    func put(_ registration: PushRegistration) async throws {
        try await send(method: "PUT", body: registration)
    }

    func delete(token: String) async throws {
        try await send(method: "DELETE", body: ["token": token])
    }

    private func send(method: String, body: some Encodable) async throws {
        var request = URLRequest(url: baseURL.appending(path: "v1/push/registration"))
        request.httpMethod = method
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
