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
