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
