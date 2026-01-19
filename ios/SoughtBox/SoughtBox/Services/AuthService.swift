import Foundation

actor AuthService {
    static let shared = AuthService()

    private init() {}

    struct SignUpRequest: Encodable {
        let email: String
        let password: String
        let name: String
    }

    struct LoginRequest: Encodable {
        let email: String
        let password: String
    }

    struct CreateHouseholdRequest: Encodable {
        let name: String
    }

    struct AcceptInviteRequest: Encodable {
        let token: String
    }

    struct SendInviteRequest: Encodable {
        let email: String
    }

    func signUp(email: String, password: String, name: String) async throws -> AuthResponse {
        let response: AuthResponse = try await APIClient.shared.post(
            "/auth/signup",
            body: SignUpRequest(email: email, password: password, name: name),
            authenticated: false
        )
        saveTokens(response)
        return response
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await APIClient.shared.post(
            "/auth/login",
            body: LoginRequest(email: email, password: password),
            authenticated: false
        )
        saveTokens(response)
        return response
    }

    func getMe() async throws -> MeResponse {
        try await APIClient.shared.get("/auth/me")
    }

    func createHousehold(name: String) async throws -> HouseholdResponse {
        let response: HouseholdResponse = try await APIClient.shared.post(
            "/auth/household",
            body: CreateHouseholdRequest(name: name)
        )
        KeychainService.save(response.accessToken, for: .accessToken)
        return response
    }

    func sendInvite(email: String) async throws -> InviteResponse {
        try await APIClient.shared.post(
            "/auth/invite",
            body: SendInviteRequest(email: email)
        )
    }

    func acceptInvite(token: String) async throws -> HouseholdResponse {
        let response: HouseholdResponse = try await APIClient.shared.post(
            "/auth/invite/accept",
            body: AcceptInviteRequest(token: token)
        )
        KeychainService.save(response.accessToken, for: .accessToken)
        return response
    }

    func logout() {
        KeychainService.clearAll()
    }

    func isLoggedIn() -> Bool {
        KeychainService.get(.accessToken) != nil
    }

    private func saveTokens(_ response: AuthResponse) {
        KeychainService.save(response.accessToken, for: .accessToken)
        KeychainService.save(response.refreshToken, for: .refreshToken)
    }
}
