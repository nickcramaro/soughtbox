import Foundation

actor APIClient {
    static let shared = APIClient()

    private let baseURL = Configuration.apiBaseURL
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private init() {}

    func request<T: Decodable>(
        _ method: String,
        path: String,
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = KeychainService.get(.accessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            // Try to refresh token
            if authenticated, let _ = KeychainService.get(.refreshToken) {
                try await refreshToken()
                return try await self.request(method, path: path, body: body, authenticated: authenticated)
            }
            throw APIError.unauthorized
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Request failed with status \(httpResponse.statusCode)")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func get<T: Decodable>(_ path: String, authenticated: Bool = true) async throws -> T {
        try await request("GET", path: path, authenticated: authenticated)
    }

    func post<T: Decodable>(_ path: String, body: Encodable? = nil, authenticated: Bool = true) async throws -> T {
        try await request("POST", path: path, body: body, authenticated: authenticated)
    }

    func put<T: Decodable>(_ path: String, body: Encodable? = nil) async throws -> T {
        try await request("PUT", path: path, body: body)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await request("DELETE", path: path)
    }

    private func refreshToken() async throws {
        guard let refreshToken = KeychainService.get(.refreshToken) else {
            throw APIError.unauthorized
        }

        struct RefreshRequest: Encodable {
            let refreshToken: String
        }

        struct RefreshResponse: Decodable {
            let accessToken: String
            let refreshToken: String
        }

        let response: RefreshResponse = try await post(
            "/auth/refresh",
            body: RefreshRequest(refreshToken: refreshToken),
            authenticated: false
        )

        KeychainService.save(response.accessToken, for: .accessToken)
        KeychainService.save(response.refreshToken, for: .refreshToken)
    }
}

private struct ErrorResponse: Decodable {
    let error: String
}
