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
