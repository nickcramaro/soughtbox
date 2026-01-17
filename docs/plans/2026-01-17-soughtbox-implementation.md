# SoughtBox MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a working iOS app connected to the API, with auth, lists, and chores features.

**Architecture:** SwiftUI MVVM with async/await networking. API already built with Hono/Drizzle. Real-time sync via WebSocket.

**Tech Stack:** Swift 5.9+, SwiftUI (iOS 17+), URLSession, native WebSocket, Keychain for tokens.

---

## Phase 1: Database & API Verification

### Task 1: Set Up Local PostgreSQL

**Step 1: Create docker-compose for local dev**

Create: `docker-compose.yml`

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: soughtbox
      POSTGRES_PASSWORD: soughtbox
      POSTGRES_DB: soughtbox
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

**Step 2: Start Postgres**

Run: `docker-compose up -d`
Expected: Container starts, port 5432 available

**Step 3: Create .env file**

Create: `api/.env`

```
DATABASE_URL=postgres://soughtbox:soughtbox@localhost:5432/soughtbox
JWT_SECRET=dev-secret-change-in-production-use-openssl-rand
PORT=3000
```

**Step 4: Push schema to database**

Run: `cd api && pnpm db:push`
Expected: Tables created successfully

**Step 5: Start API and verify**

Run: `cd api && pnpm dev`
Expected: "SoughtBox API running on http://localhost:3000"

**Step 6: Test health endpoint**

Run: `curl http://localhost:3000`
Expected: `{"status":"ok","name":"SoughtBox API"}`

**Step 7: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add docker-compose for local Postgres"
```

---

## Phase 2: iOS Project Setup

### Task 2: Create Xcode Project

**Step 1: Create iOS project directory**

Run: `mkdir -p ios`

**Step 2: Create Xcode project**

1. Open Xcode
2. File → New → Project
3. Select "App" under iOS
4. Product Name: `SoughtBox`
5. Team: Your personal team (or None for now)
6. Organization Identifier: `com.soughtbox`
7. Interface: SwiftUI
8. Language: Swift
9. Storage: None
10. Uncheck "Include Tests" (we'll add later)
11. Save to: `soughtbox/ios/`

**Step 3: Set deployment target**

1. Select SoughtBox project in navigator
2. Select SoughtBox target
3. General → Minimum Deployments → iOS 17.0

**Step 4: Verify project runs**

Run: Cmd+R in Xcode Simulator
Expected: "Hello, world!" appears in simulator

**Step 5: Commit**

```bash
git add ios/
git commit -m "feat: create iOS Xcode project"
```

---

### Task 3: Create Project Structure

**Step 1: Create folder structure in Xcode**

Right-click SoughtBox folder → New Group (for each):
- `Models`
- `ViewModels`
- `Views`
- `Views/Auth`
- `Views/Lists`
- `Views/Chores`
- `Views/Settings`
- `Services`
- `Components`

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add iOS folder structure"
```

---

## Phase 3: iOS Core Services

### Task 4: API Configuration

**Step 1: Create Configuration.swift**

Create: `ios/SoughtBox/Services/Configuration.swift`

```swift
import Foundation

enum Configuration {
    static let apiBaseURL: URL = {
        #if DEBUG
        // Use localhost for simulator, your Mac's IP for device
        return URL(string: "http://localhost:3000")!
        #else
        return URL(string: "https://api.soughtbox.app")!
        #endif
    }()

    static let wsBaseURL: URL = {
        #if DEBUG
        return URL(string: "ws://localhost:3000/ws")!
        #else
        return URL(string: "wss://api.soughtbox.app/ws")!
        #endif
    }()
}
```

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add API configuration"
```

---

### Task 5: Keychain Service

**Step 1: Create KeychainService.swift**

Create: `ios/SoughtBox/Services/KeychainService.swift`

```swift
import Foundation
import Security

enum KeychainService {
    private static let service = "com.soughtbox.app"

    enum Key: String {
        case accessToken
        case refreshToken
    }

    static func save(_ value: String, for key: Key) {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        SecItemDelete(query as CFDictionary)
    }

    static func clearAll() {
        delete(.accessToken)
        delete(.refreshToken)
    }
}
```

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add Keychain service for secure token storage"
```

---

### Task 6: API Client

**Step 1: Create APIError.swift**

Create: `ios/SoughtBox/Services/APIError.swift`

```swift
import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Please log in again"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
```

**Step 2: Create APIClient.swift**

Create: `ios/SoughtBox/Services/APIClient.swift`

```swift
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
```

**Step 3: Commit**

```bash
git add ios/
git commit -m "feat: add API client with token refresh"
```

---

## Phase 4: Models

### Task 7: Create Models

**Step 1: Create User.swift**

Create: `ios/SoughtBox/Models/User.swift`

```swift
import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let householdId: String?
}
```

**Step 2: Create Household.swift**

Create: `ios/SoughtBox/Models/Household.swift`

```swift
import Foundation

struct Household: Codable, Identifiable {
    let id: String
    let name: String
    let createdAt: Date
}
```

**Step 3: Create List.swift**

Create: `ios/SoughtBox/Models/List.swift`

```swift
import Foundation

struct ItemList: Codable, Identifiable {
    let id: String
    let householdId: String
    let name: String
    let icon: String?
    let sortOrder: Int
    let createdAt: Date
    var items: [ListItem]?
}

struct ListItem: Codable, Identifiable {
    let id: String
    let listId: String
    let text: String
    var isCompleted: Bool
    let createdById: String
    let sortOrder: Int
    let completedAt: Date?
    let createdAt: Date
}
```

**Step 4: Create Chore.swift**

Create: `ios/SoughtBox/Models/Chore.swift`

```swift
import Foundation

enum Frequency: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly
    case asNeeded = "as-needed"

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .asNeeded: return "As Needed"
        }
    }
}

enum EffortLevel: String, Codable, CaseIterable {
    case light
    case medium
    case heavy

    var displayName: String {
        rawValue.capitalized
    }
}

struct Chore: Codable, Identifiable {
    let id: String
    let householdId: String
    let name: String
    let frequency: Frequency
    let effortLevel: EffortLevel
    let createdAt: Date
    var lastCompletion: ChoreCompletion?
}

struct ChoreCompletion: Codable, Identifiable {
    let id: String
    let choreId: String
    let completedById: String
    let completedAt: Date
    let completedBy: CompletedByUser?
}

struct CompletedByUser: Codable {
    let id: String
    let name: String
}
```

**Step 5: Create AuthResponses.swift**

Create: `ios/SoughtBox/Models/AuthResponses.swift`

```swift
import Foundation

struct AuthResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
}

struct HouseholdResponse: Codable {
    let household: Household
    let accessToken: String
}

struct MeResponse: Codable {
    let user: User
    let household: Household?
}

struct InviteResponse: Codable {
    let invite: InviteInfo
    let inviteLink: String
}

struct InviteInfo: Codable {
    let id: String
    let email: String
}
```

**Step 6: Commit**

```bash
git add ios/
git commit -m "feat: add data models"
```

---

## Phase 5: Auth Feature

### Task 8: AuthService

**Step 1: Create AuthService.swift**

Create: `ios/SoughtBox/Services/AuthService.swift`

```swift
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
```

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add AuthService"
```

---

### Task 9: AuthViewModel

**Step 1: Create AuthViewModel.swift**

Create: `ios/SoughtBox/ViewModels/AuthViewModel.swift`

```swift
import Foundation
import SwiftUI

@MainActor
@Observable
class AuthViewModel {
    var isLoggedIn = false
    var user: User?
    var household: Household?
    var isLoading = false
    var error: String?

    // Form fields
    var email = ""
    var password = ""
    var name = ""
    var householdName = ""
    var inviteEmail = ""
    var inviteToken = ""

    init() {
        isLoggedIn = AuthService.shared.isLoggedIn()
    }

    func checkAuth() async {
        guard AuthService.shared.isLoggedIn() else {
            isLoggedIn = false
            return
        }

        do {
            let response = try await AuthService.shared.getMe()
            user = response.user
            household = response.household
            isLoggedIn = true
        } catch {
            // Token invalid, clear and require login
            await AuthService.shared.logout()
            isLoggedIn = false
        }
    }

    func signUp() async {
        guard !email.isEmpty, !password.isEmpty, !name.isEmpty else {
            error = "Please fill in all fields"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await AuthService.shared.signUp(
                email: email,
                password: password,
                name: name
            )
            user = response.user
            isLoggedIn = true
            clearForm()
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await AuthService.shared.login(
                email: email,
                password: password
            )
            user = response.user
            household = nil // Will be fetched if exists
            isLoggedIn = true
            await checkAuth() // Get household info
            clearForm()
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createHousehold() async {
        guard !householdName.isEmpty else {
            error = "Please enter a household name"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await AuthService.shared.createHousehold(name: householdName)
            household = response.household
            householdName = ""
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func sendInvite() async {
        guard !inviteEmail.isEmpty else {
            error = "Please enter an email"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await AuthService.shared.sendInvite(email: inviteEmail)
            // In a real app, you'd show the invite link or confirm email was sent
            print("Invite sent: \(response.inviteLink)")
            inviteEmail = ""
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func acceptInvite() async {
        guard !inviteToken.isEmpty else {
            error = "Please enter an invite code"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await AuthService.shared.acceptInvite(token: inviteToken)
            household = response.household
            inviteToken = ""
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func logout() async {
        await AuthService.shared.logout()
        user = nil
        household = nil
        isLoggedIn = false
    }

    private func clearForm() {
        email = ""
        password = ""
        name = ""
    }
}
```

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add AuthViewModel"
```

---

### Task 10: Auth Views

**Step 1: Create LoginView.swift**

Create: `ios/SoughtBox/Views/Auth/LoginView.swift`

```swift
import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("SoughtBox")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Organize your life together")
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Name", text: $viewModel.name)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }

                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)
                }
                .padding(.horizontal)

                if let error = viewModel.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button {
                    Task {
                        if isSignUp {
                            await viewModel.signUp()
                        } else {
                            await viewModel.login()
                        }
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(isSignUp ? "Sign Up" : "Log In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
                .padding(.horizontal)

                Button {
                    withAnimation {
                        isSignUp.toggle()
                        viewModel.error = nil
                    }
                } label: {
                    Text(isSignUp ? "Already have an account? Log in" : "Don't have an account? Sign up")
                        .font(.footnote)
                }

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
```

**Step 2: Create HouseholdSetupView.swift**

Create: `ios/SoughtBox/Views/Auth/HouseholdSetupView.swift`

```swift
import SwiftUI

struct HouseholdSetupView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var mode: SetupMode = .choice

    enum SetupMode {
        case choice
        case create
        case join
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("Welcome, \(viewModel.user?.name ?? "")!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Set up your household to get started")
                    .foregroundStyle(.secondary)

                Spacer()

                switch mode {
                case .choice:
                    choiceView
                case .create:
                    createView
                case .join:
                    joinView
                }

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") {
                        Task {
                            await viewModel.logout()
                        }
                    }
                }
            }
        }
    }

    private var choiceView: some View {
        VStack(spacing: 16) {
            Button {
                withAnimation {
                    mode = .create
                }
            } label: {
                VStack {
                    Image(systemName: "house.fill")
                        .font(.largeTitle)
                    Text("Create Household")
                        .font(.headline)
                    Text("Start a new household and invite your partner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                withAnimation {
                    mode = .join
                }
            } label: {
                VStack {
                    Image(systemName: "envelope.fill")
                        .font(.largeTitle)
                    Text("Join Household")
                        .font(.headline)
                    Text("Enter an invite code from your partner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    private var createView: some View {
        VStack(spacing: 16) {
            TextField("Household Name", text: $viewModel.householdName)
                .textFieldStyle(.roundedBorder)

            if let error = viewModel.error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task {
                    await viewModel.createHousehold()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            Button("Back") {
                withAnimation {
                    mode = .choice
                    viewModel.error = nil
                }
            }
        }
        .padding(.horizontal)
    }

    private var joinView: some View {
        VStack(spacing: 16) {
            TextField("Invite Code", text: $viewModel.inviteToken)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            if let error = viewModel.error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task {
                    await viewModel.acceptInvite()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Join")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            Button("Back") {
                withAnimation {
                    mode = .choice
                    viewModel.error = nil
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    let viewModel = AuthViewModel()
    viewModel.user = User(id: "1", email: "test@test.com", name: "Nick", householdId: nil)
    return HouseholdSetupView(viewModel: viewModel)
}
```

**Step 3: Commit**

```bash
git add ios/
git commit -m "feat: add auth views"
```

---

## Phase 6: Lists Feature

### Task 11: ListsService

**Step 1: Create ListsService.swift**

Create: `ios/SoughtBox/Services/ListsService.swift`

```swift
import Foundation

actor ListsService {
    static let shared = ListsService()

    private init() {}

    struct ListsResponse: Decodable {
        let lists: [ItemList]
    }

    struct ListResponse: Decodable {
        let list: ItemList
    }

    struct ItemResponse: Decodable {
        let item: ListItem
    }

    struct SuccessResponse: Decodable {
        let success: Bool
    }

    struct CreateListRequest: Encodable {
        let name: String
        let icon: String?
    }

    struct CreateItemRequest: Encodable {
        let text: String
    }

    struct UpdateItemRequest: Encodable {
        let text: String?
        let isCompleted: Bool?
        let sortOrder: Int?
    }

    func getLists() async throws -> [ItemList] {
        let response: ListsResponse = try await APIClient.shared.get("/lists")
        return response.lists
    }

    func getList(id: String) async throws -> ItemList {
        let response: ListResponse = try await APIClient.shared.get("/lists/\(id)")
        return response.list
    }

    func createList(name: String, icon: String? = nil) async throws -> ItemList {
        let response: ListResponse = try await APIClient.shared.post(
            "/lists",
            body: CreateListRequest(name: name, icon: icon)
        )
        return response.list
    }

    func deleteList(id: String) async throws {
        let _: SuccessResponse = try await APIClient.shared.delete("/lists/\(id)")
    }

    func addItem(listId: String, text: String) async throws -> ListItem {
        let response: ItemResponse = try await APIClient.shared.post(
            "/lists/\(listId)/items",
            body: CreateItemRequest(text: text)
        )
        return response.item
    }

    func updateItem(listId: String, itemId: String, isCompleted: Bool) async throws -> ListItem {
        let response: ItemResponse = try await APIClient.shared.put(
            "/lists/\(listId)/items/\(itemId)",
            body: UpdateItemRequest(text: nil, isCompleted: isCompleted, sortOrder: nil)
        )
        return response.item
    }

    func deleteItem(listId: String, itemId: String) async throws {
        let _: SuccessResponse = try await APIClient.shared.delete("/lists/\(listId)/items/\(itemId)")
    }
}
```

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add ListsService"
```

---

### Task 12: ListsViewModel

**Step 1: Create ListsViewModel.swift**

Create: `ios/SoughtBox/ViewModels/ListsViewModel.swift`

```swift
import Foundation
import SwiftUI

@MainActor
@Observable
class ListsViewModel {
    var lists: [ItemList] = []
    var selectedList: ItemList?
    var isLoading = false
    var error: String?

    // Form fields
    var newListName = ""
    var newItemText = ""

    func loadLists() async {
        isLoading = true
        error = nil

        do {
            lists = try await ListsService.shared.getLists()
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadList(id: String) async {
        isLoading = true
        error = nil

        do {
            selectedList = try await ListsService.shared.getList(id: id)
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createList() async {
        guard !newListName.isEmpty else { return }

        do {
            let list = try await ListsService.shared.createList(name: newListName)
            lists.append(list)
            newListName = ""
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteList(_ list: ItemList) async {
        do {
            try await ListsService.shared.deleteList(id: list.id)
            lists.removeAll { $0.id == list.id }
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addItem() async {
        guard let list = selectedList, !newItemText.isEmpty else { return }

        do {
            let item = try await ListsService.shared.addItem(listId: list.id, text: newItemText)
            if selectedList?.items == nil {
                selectedList?.items = []
            }
            selectedList?.items?.append(item)
            newItemText = ""

            // Update in lists array too
            if let index = lists.firstIndex(where: { $0.id == list.id }) {
                if lists[index].items == nil {
                    lists[index].items = []
                }
                lists[index].items?.append(item)
            }
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleItem(_ item: ListItem) async {
        guard let list = selectedList else { return }

        // Optimistic update
        if let itemIndex = selectedList?.items?.firstIndex(where: { $0.id == item.id }) {
            selectedList?.items?[itemIndex].isCompleted.toggle()
        }

        do {
            let updated = try await ListsService.shared.updateItem(
                listId: list.id,
                itemId: item.id,
                isCompleted: !item.isCompleted
            )

            // Update with server response
            if let itemIndex = selectedList?.items?.firstIndex(where: { $0.id == item.id }) {
                selectedList?.items?[itemIndex] = updated
            }
        } catch {
            // Rollback on error
            if let itemIndex = selectedList?.items?.firstIndex(where: { $0.id == item.id }) {
                selectedList?.items?[itemIndex].isCompleted.toggle()
            }
            self.error = error.localizedDescription
        }
    }

    func deleteItem(_ item: ListItem) async {
        guard let list = selectedList else { return }

        do {
            try await ListsService.shared.deleteItem(listId: list.id, itemId: item.id)
            selectedList?.items?.removeAll { $0.id == item.id }

            // Update in lists array too
            if let listIndex = lists.firstIndex(where: { $0.id == list.id }) {
                lists[listIndex].items?.removeAll { $0.id == item.id }
            }
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add ListsViewModel"
```

---

### Task 13: Lists Views

**Step 1: Create ListsHomeView.swift**

Create: `ios/SoughtBox/Views/Lists/ListsHomeView.swift`

```swift
import SwiftUI

struct ListsHomeView: View {
    @Bindable var viewModel: ListsViewModel
    @State private var showingNewList = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.lists.isEmpty {
                    ProgressView()
                } else if viewModel.lists.isEmpty {
                    ContentUnavailableView(
                        "No Lists",
                        systemImage: "list.bullet",
                        description: Text("Create your first list to get started")
                    )
                } else {
                    List {
                        ForEach(viewModel.lists) { list in
                            NavigationLink {
                                ListDetailView(viewModel: viewModel, list: list)
                            } label: {
                                HStack {
                                    Text(list.icon ?? "📝")
                                    VStack(alignment: .leading) {
                                        Text(list.name)
                                        if let items = list.items {
                                            let incomplete = items.filter { !$0.isCompleted }.count
                                            Text("\(incomplete) item\(incomplete == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    await viewModel.deleteList(viewModel.lists[index])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewList = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New List", isPresented: $showingNewList) {
                TextField("List name", text: $viewModel.newListName)
                Button("Cancel", role: .cancel) {
                    viewModel.newListName = ""
                }
                Button("Create") {
                    Task {
                        await viewModel.createList()
                    }
                }
            }
            .refreshable {
                await viewModel.loadLists()
            }
            .task {
                await viewModel.loadLists()
            }
        }
    }
}

#Preview {
    ListsHomeView(viewModel: ListsViewModel())
}
```

**Step 2: Create ListDetailView.swift**

Create: `ios/SoughtBox/Views/Lists/ListDetailView.swift`

```swift
import SwiftUI

struct ListDetailView: View {
    @Bindable var viewModel: ListsViewModel
    let list: ItemList
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let items = viewModel.selectedList?.items, !items.isEmpty {
                List {
                    ForEach(items) { item in
                        HStack {
                            Button {
                                Task {
                                    await viewModel.toggleItem(item)
                                }
                            } label: {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            Text(item.text)
                                .strikethrough(item.isCompleted)
                                .foregroundStyle(item.isCompleted ? .secondary : .primary)

                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                if let item = viewModel.selectedList?.items?[index] {
                                    await viewModel.deleteItem(item)
                                }
                            }
                        }
                    }
                }
            } else if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                Spacer()
                ContentUnavailableView(
                    "No Items",
                    systemImage: "tray",
                    description: Text("Add your first item below")
                )
                Spacer()
            }

            // Add item bar
            HStack {
                TextField("Add item...", text: $viewModel.newItemText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        Task {
                            await viewModel.addItem()
                        }
                    }

                Button {
                    Task {
                        await viewModel.addItem()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(viewModel.newItemText.isEmpty)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle(list.name)
        .task {
            await viewModel.loadList(id: list.id)
        }
    }
}

#Preview {
    NavigationStack {
        ListDetailView(
            viewModel: ListsViewModel(),
            list: ItemList(
                id: "1",
                householdId: "1",
                name: "Groceries",
                icon: "🛒",
                sortOrder: 0,
                createdAt: Date(),
                items: []
            )
        )
    }
}
```

**Step 3: Commit**

```bash
git add ios/
git commit -m "feat: add lists views"
```

---

## Phase 7: Chores Feature

### Task 14: ChoresService

**Step 1: Create ChoresService.swift**

Create: `ios/SoughtBox/Services/ChoresService.swift`

```swift
import Foundation

actor ChoresService {
    static let shared = ChoresService()

    private init() {}

    struct ChoresResponse: Decodable {
        let chores: [Chore]
    }

    struct ChoreResponse: Decodable {
        let chore: Chore
    }

    struct CompletionResponse: Decodable {
        let completion: ChoreCompletion
    }

    struct SuccessResponse: Decodable {
        let success: Bool
    }

    struct CreateChoreRequest: Encodable {
        let name: String
        let frequency: String
        let effortLevel: String
    }

    func getChores() async throws -> [Chore] {
        let response: ChoresResponse = try await APIClient.shared.get("/chores")
        return response.chores
    }

    func createChore(name: String, frequency: Frequency, effortLevel: EffortLevel) async throws -> Chore {
        let response: ChoreResponse = try await APIClient.shared.post(
            "/chores",
            body: CreateChoreRequest(
                name: name,
                frequency: frequency.rawValue,
                effortLevel: effortLevel.rawValue
            )
        )
        return response.chore
    }

    func deleteChore(id: String) async throws {
        let _: SuccessResponse = try await APIClient.shared.delete("/chores/\(id)")
    }

    func completeChore(id: String) async throws -> ChoreCompletion {
        let response: CompletionResponse = try await APIClient.shared.post("/chores/\(id)/complete")
        return response.completion
    }
}
```

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add ChoresService"
```

---

### Task 15: ChoresViewModel

**Step 1: Create ChoresViewModel.swift**

Create: `ios/SoughtBox/ViewModels/ChoresViewModel.swift`

```swift
import Foundation
import SwiftUI

@MainActor
@Observable
class ChoresViewModel {
    var chores: [Chore] = []
    var isLoading = false
    var error: String?

    // Form fields
    var newChoreName = ""
    var newChoreFrequency: Frequency = .asNeeded
    var newChoreEffort: EffortLevel = .medium

    func loadChores() async {
        isLoading = true
        error = nil

        do {
            chores = try await ChoresService.shared.getChores()
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createChore() async {
        guard !newChoreName.isEmpty else { return }

        do {
            let chore = try await ChoresService.shared.createChore(
                name: newChoreName,
                frequency: newChoreFrequency,
                effortLevel: newChoreEffort
            )
            chores.append(chore)
            newChoreName = ""
            newChoreFrequency = .asNeeded
            newChoreEffort = .medium
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteChore(_ chore: Chore) async {
        do {
            try await ChoresService.shared.deleteChore(id: chore.id)
            chores.removeAll { $0.id == chore.id }
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func completeChore(_ chore: Chore) async {
        do {
            let completion = try await ChoresService.shared.completeChore(id: chore.id)
            if let index = chores.firstIndex(where: { $0.id == chore.id }) {
                chores[index].lastCompletion = completion
            }
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func isDue(_ chore: Chore) -> Bool {
        guard let lastCompletion = chore.lastCompletion else {
            return true // Never done = due
        }

        let now = Date()
        let lastDone = lastCompletion.completedAt

        switch chore.frequency {
        case .daily:
            return !Calendar.current.isDate(lastDone, inSameDayAs: now)
        case .weekly:
            return lastDone < Calendar.current.date(byAdding: .day, value: -7, to: now)!
        case .monthly:
            return lastDone < Calendar.current.date(byAdding: .month, value: -1, to: now)!
        case .asNeeded:
            return false // Never auto-due
        }
    }
}
```

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add ChoresViewModel"
```

---

### Task 16: Chores View

**Step 1: Create ChorePoolView.swift**

Create: `ios/SoughtBox/Views/Chores/ChorePoolView.swift`

```swift
import SwiftUI

struct ChorePoolView: View {
    @Bindable var viewModel: ChoresViewModel
    @State private var showingNewChore = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.chores.isEmpty {
                    ProgressView()
                } else if viewModel.chores.isEmpty {
                    ContentUnavailableView(
                        "No Chores",
                        systemImage: "house",
                        description: Text("Add chores to your household")
                    )
                } else {
                    List {
                        ForEach(viewModel.chores) { chore in
                            ChoreRow(
                                chore: chore,
                                isDue: viewModel.isDue(chore),
                                onComplete: {
                                    Task {
                                        await viewModel.completeChore(chore)
                                    }
                                }
                            )
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    await viewModel.deleteChore(viewModel.chores[index])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chores")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewChore = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewChore) {
                NewChoreSheet(viewModel: viewModel, isPresented: $showingNewChore)
            }
            .refreshable {
                await viewModel.loadChores()
            }
            .task {
                await viewModel.loadChores()
            }
        }
    }
}

struct ChoreRow: View {
    let chore: Chore
    let isDue: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chore.name)
                        .font(.headline)

                    if isDue {
                        Text("Due")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text(chore.frequency.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let lastCompletion = chore.lastCompletion {
                        Text("• \(lastCompletion.completedBy?.name ?? "Someone") \(lastCompletion.completedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                onComplete()
            } label: {
                Text("I did this")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

struct NewChoreSheet: View {
    @Bindable var viewModel: ChoresViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Chore name", text: $viewModel.newChoreName)
                }

                Section("Frequency") {
                    Picker("Frequency", selection: $viewModel.newChoreFrequency) {
                        ForEach(Frequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Effort") {
                    Picker("Effort", selection: $viewModel.newChoreEffort) {
                        ForEach(EffortLevel.allCases, id: \.self) { effort in
                            Text(effort.displayName).tag(effort)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.newChoreName = ""
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await viewModel.createChore()
                            isPresented = false
                        }
                    }
                    .disabled(viewModel.newChoreName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ChorePoolView(viewModel: ChoresViewModel())
}
```

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add chores view"
```

---

## Phase 8: Settings & Main App

### Task 17: Settings View

**Step 1: Create SettingsView.swift**

Create: `ios/SoughtBox/Views/Settings/SettingsView.swift`

```swift
import SwiftUI

struct SettingsView: View {
    @Bindable var authViewModel: AuthViewModel
    @State private var showingInvite = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = authViewModel.user {
                        LabeledContent("Name", value: user.name)
                        LabeledContent("Email", value: user.email)
                    }
                }

                Section("Household") {
                    if let household = authViewModel.household {
                        LabeledContent("Name", value: household.name)

                        Button {
                            showingInvite = true
                        } label: {
                            Label("Invite Partner", systemImage: "person.badge.plus")
                        }
                    } else {
                        Text("No household")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await authViewModel.logout()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Invite Partner", isPresented: $showingInvite) {
                TextField("Partner's email", text: $authViewModel.inviteEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                Button("Cancel", role: .cancel) {
                    authViewModel.inviteEmail = ""
                }
                Button("Send Invite") {
                    Task {
                        await authViewModel.sendInvite()
                    }
                }
            } message: {
                Text("Enter your partner's email to send them an invite.")
            }
        }
    }
}

#Preview {
    let viewModel = AuthViewModel()
    viewModel.user = User(id: "1", email: "nick@test.com", name: "Nick", householdId: "1")
    viewModel.household = Household(id: "1", name: "Our Home", createdAt: Date())
    return SettingsView(authViewModel: viewModel)
}
```

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add settings view"
```

---

### Task 18: Main Tab View & App Entry

**Step 1: Create MainTabView.swift**

Create: `ios/SoughtBox/Views/MainTabView.swift`

```swift
import SwiftUI

struct MainTabView: View {
    @State private var listsViewModel = ListsViewModel()
    @State private var choresViewModel = ChoresViewModel()
    @Bindable var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            ListsHomeView(viewModel: listsViewModel)
                .tabItem {
                    Label("Lists", systemImage: "list.bullet")
                }

            ChorePoolView(viewModel: choresViewModel)
                .tabItem {
                    Label("Chores", systemImage: "house")
                }

            SettingsView(authViewModel: authViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    let viewModel = AuthViewModel()
    viewModel.user = User(id: "1", email: "test@test.com", name: "Nick", householdId: "1")
    viewModel.household = Household(id: "1", name: "Home", createdAt: Date())
    return MainTabView(authViewModel: viewModel)
}
```

**Step 2: Update SoughtBoxApp.swift**

Replace: `ios/SoughtBox/SoughtBoxApp.swift`

```swift
import SwiftUI

@main
struct SoughtBoxApp: App {
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if !authViewModel.isLoggedIn {
                    LoginView(viewModel: authViewModel)
                } else if authViewModel.household == nil {
                    HouseholdSetupView(viewModel: authViewModel)
                } else {
                    MainTabView(authViewModel: authViewModel)
                }
            }
            .task {
                await authViewModel.checkAuth()
            }
        }
    }
}
```

**Step 3: Delete ContentView.swift**

Delete: `ios/SoughtBox/ContentView.swift` (the default file)

**Step 4: Commit**

```bash
git add ios/
git commit -m "feat: add main app structure with tab navigation"
```

---

## Phase 9: WebSocket Real-Time (Optional Enhancement)

### Task 19: WebSocket Client

**Step 1: Create WebSocketClient.swift**

Create: `ios/SoughtBox/Services/WebSocketClient.swift`

```swift
import Foundation

@MainActor
@Observable
class WebSocketClient {
    static let shared = WebSocketClient()

    private var webSocket: URLSessionWebSocketTask?
    private var isConnected = false

    var onListUpdate: ((String, Any) -> Void)?
    var onChoreUpdate: ((String, Any) -> Void)?

    private init() {}

    func connect() {
        guard let token = KeychainService.get(.accessToken) else { return }
        guard !isConnected else { return }

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: Configuration.wsBaseURL)
        webSocket?.resume()

        // Authenticate
        let authMessage = ["type": "auth", "token": token]
        if let data = try? JSONSerialization.data(withJSONObject: authMessage),
           let string = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(string)) { _ in }
        }

        isConnected = true
        receiveMessage()
    }

    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case .string(let text) = message,
                   let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String {

                    Task { @MainActor in
                        self?.handleMessage(type: type, payload: json["payload"])
                    }
                }

                // Continue receiving
                Task { @MainActor in
                    self?.receiveMessage()
                }

            case .failure:
                Task { @MainActor in
                    self?.isConnected = false
                    // Reconnect after delay
                    try? await Task.sleep(for: .seconds(5))
                    self?.connect()
                }
            }
        }
    }

    private func handleMessage(type: String, payload: Any?) {
        guard let payload = payload else { return }

        if type.hasPrefix("list") {
            onListUpdate?(type, payload)
        } else if type.hasPrefix("chore") {
            onChoreUpdate?(type, payload)
        }
    }
}
```

**Step 2: Commit**

```bash
git add ios/
git commit -m "feat: add WebSocket client for real-time updates"
```

---

## Phase 10: Final Polish & Deploy

### Task 20: Deploy API to Railway

**Step 1: Login to Railway**

Run: `railway login`
Expected: Browser opens for authentication

**Step 2: Initialize Railway project**

Run: `cd api && railway init`
Expected: Select/create project in Railway

**Step 3: Add Postgres plugin**

Run: `railway add`
Expected: Select PostgreSQL

**Step 4: Set environment variables**

Run: `railway variables set JWT_SECRET=$(openssl rand -base64 32)`
Expected: Variable set

**Step 5: Deploy**

Run: `railway up`
Expected: Deployment succeeds, URL provided

**Step 6: Run migrations on production**

Run: `railway run pnpm db:push`
Expected: Tables created in production DB

**Step 7: Commit railway config**

```bash
git add .
git commit -m "feat: add Railway deployment config"
```

---

### Task 21: Update iOS for Production

**Step 1: Update Configuration.swift with production URL**

After Railway deploy gives you a URL (e.g., `soughtbox-api.up.railway.app`), update the production URLs in `ios/SoughtBox/Services/Configuration.swift`.

**Step 2: Test on physical device**

1. Connect iPhone
2. Select device in Xcode
3. Run (Cmd+R)
4. Test full flow: signup → create household → create list → add items

**Step 3: Final commit**

```bash
git add ios/
git commit -m "feat: configure production API URL"
git push
```

---

## Summary

**Total Tasks:** 21
**Phases:**
1. Database & API Verification (1 task)
2. iOS Project Setup (2 tasks)
3. iOS Core Services (3 tasks)
4. Models (1 task)
5. Auth Feature (3 tasks)
6. Lists Feature (3 tasks)
7. Chores Feature (3 tasks)
8. Settings & Main App (2 tasks)
9. WebSocket Real-Time (1 task)
10. Final Polish & Deploy (2 tasks)
