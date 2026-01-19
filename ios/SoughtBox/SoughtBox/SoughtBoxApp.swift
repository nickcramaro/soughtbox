import SwiftUI

@main
struct SoughtBoxApp: App {
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if !authViewModel.isLoggedIn {
                    LoginView(viewModel: authViewModel)
                } else if authViewModel.household == nil {
                    HouseholdSetupView(viewModel: authViewModel)
                } else {
                    MainTabView(authViewModel: authViewModel)
                }
            }
            .task {
                await authViewModel.checkAuth()
            }
        }
    }
}
