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
