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
