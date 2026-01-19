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
