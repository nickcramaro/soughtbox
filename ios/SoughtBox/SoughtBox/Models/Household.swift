import Foundation

struct Household: Codable, Identifiable {
    let id: String
    let name: String
    let createdAt: Date
}
