import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct ErrorBody: Decodable {
    let error: String
}

/// Talks to the Flask backend. Every call adds the sign-in token automatically.
final class API {
    static let shared = API()

    /// Set once at launch (SkillSwapApp): returns the current Firebase ID token (or the dev token).
    var tokenProvider: (() async throws -> String)?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await send(method: "GET", path: path, query: query, body: nil, contentType: nil, timeout: 30)
    }

    func post<T: Decodable>(_ path: String, body: [String: Any] = [:], timeout: TimeInterval = 30) async throws -> T {
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await send(method: "POST", path: path, query: [:], body: data, contentType: "application/json", timeout: timeout)
    }

    func put<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await send(method: "PUT", path: path, query: [:], body: data, contentType: "application/json", timeout: 30)
    }

    /// Sends a PDF as a multipart form (field name "file").
    func upload<T: Decodable>(_ path: String, fileData: Data, fileName: String, mime: String) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mime)\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return try await send(method: "POST", path: path, query: [:], body: body,
                              contentType: "multipart/form-data; boundary=\(boundary)", timeout: 120)
    }

    private func send<T: Decodable>(method: String, path: String, query: [String: String], body: Data?,
                                    contentType: String?, timeout: TimeInterval) async throws -> T {
        let base = AppConfig.shared.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var comps = URLComponents(string: base + path) else {
            throw APIError(message: "The server address in Settings is not valid.")
        }
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps.url else {
            throw APIError(message: "The server address in Settings is not valid.")
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        if let provider = tokenProvider {
            let token = try await provider()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw APIError(message: friendly(error, base: base))
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "The server sent an unexpected answer.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(ErrorBody.self, from: data))?.error
            throw APIError(message: message ?? "Server error (\(http.statusCode)).")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError(message: "The app could not read the server's answer: \(error)")
        }
    }

    private func friendly(_ error: URLError, base: String) -> String {
        switch error.code {
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed:
            return "Cannot reach the server at \(base). Is the backend running, and is this address right (Settings)?"
        case .timedOut:
            return "The server took too long to answer. The AI may be busy; please try again."
        case .appTransportSecurityRequiresSecureConnection:
            return "iOS blocked a plain http address. Add 'Allow Arbitrary Loads' in Info (see docs/03_XCODE_PROJECT.md)."
        default:
            return error.localizedDescription
        }
    }
}
