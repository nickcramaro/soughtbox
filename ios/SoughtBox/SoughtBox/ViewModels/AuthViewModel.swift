import Foundation
import SwiftUI

@MainActor
@Observable
class AuthViewModel {
    var isLoggedIn = false
    var user: User?
    var household: Household?
    var isLoading = false
    var error: String?

    // Form fields
    var email = ""
    var password = ""
    var name = ""
    var householdName = ""
    var inviteEmail = ""
    var inviteToken = ""

    init() {
        isLoggedIn = AuthService.shared.isLoggedIn()
    }

    func checkAuth() async {
        guard AuthService.shared.isLoggedIn() else {
            isLoggedIn = false
            return
        }

        do {
            let response = try await AuthService.shared.getMe()
            user = response.user
            household = response.household
            isLoggedIn = true
        } catch {
            // Token invalid, clear and require login
            await AuthService.shared.logout()
            isLoggedIn = false
        }
    }

    func signUp() async {
        guard !email.isEmpty, !password.isEmpty, !name.isEmpty else {
            error = "Please fill in all fields"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await AuthService.shared.signUp(
                email: email,
                password: password,
                name: name
            )
            user = response.user
            isLoggedIn = true
            clearForm()
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await AuthService.shared.login(
                email: email,
                password: password
            )
            user = response.user
            household = nil // Will be fetched if exists
            isLoggedIn = true
            await checkAuth() // Get household info
            clearForm()
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createHousehold() async {
        guard !householdName.isEmpty else {
            error = "Please enter a household name"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await AuthService.shared.createHousehold(name: householdName)
            household = response.household
            householdName = ""
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func sendInvite() async {
        guard !inviteEmail.isEmpty else {
            error = "Please enter an email"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await AuthService.shared.sendInvite(email: inviteEmail)
            // In a real app, you'd show the invite link or confirm email was sent
            print("Invite sent: \(response.inviteLink)")
            inviteEmail = ""
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func acceptInvite() async {
        guard !inviteToken.isEmpty else {
            error = "Please enter an invite code"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await AuthService.shared.acceptInvite(token: inviteToken)
            household = response.household
            inviteToken = ""
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func logout() async {
        await AuthService.shared.logout()
        user = nil
        household = nil
        isLoggedIn = false
    }

    private func clearForm() {
        email = ""
        password = ""
        name = ""
    }
}
