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
