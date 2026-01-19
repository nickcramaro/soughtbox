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
