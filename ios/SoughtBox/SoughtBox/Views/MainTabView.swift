import SwiftUI

struct MainTabView: View {
    @State private var listsViewModel = ListsViewModel()
    @State private var choresViewModel = ChoresViewModel()
    @Bindable var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            ListsHomeView(viewModel: listsViewModel)
                .tabItem {
                    Label("Lists", systemImage: "list.bullet")
                }

            ChorePoolView(viewModel: choresViewModel)
                .tabItem {
                    Label("Chores", systemImage: "house")
                }

            SettingsView(authViewModel: authViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    let viewModel = AuthViewModel()
    viewModel.user = User(id: "1", email: "test@test.com", name: "Nick", householdId: "1")
    viewModel.household = Household(id: "1", name: "Home", createdAt: Date())
    return MainTabView(authViewModel: viewModel)
}
