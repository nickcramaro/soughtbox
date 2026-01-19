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
