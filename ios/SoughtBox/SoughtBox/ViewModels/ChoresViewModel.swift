import Foundation
import SwiftUI

@MainActor
@Observable
class ChoresViewModel {
    var chores: [Chore] = []
    var isLoading = false
    var error: String?

    // Form fields
    var newChoreName = ""
    var newChoreFrequency: Frequency = .asNeeded
    var newChoreEffort: EffortLevel = .medium

    func loadChores() async {
        isLoading = true
        error = nil

        do {
            chores = try await ChoresService.shared.getChores()
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createChore() async {
        guard !newChoreName.isEmpty else { return }

        do {
            let chore = try await ChoresService.shared.createChore(
                name: newChoreName,
                frequency: newChoreFrequency,
                effortLevel: newChoreEffort
            )
            chores.append(chore)
            newChoreName = ""
            newChoreFrequency = .asNeeded
            newChoreEffort = .medium
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteChore(_ chore: Chore) async {
        do {
            try await ChoresService.shared.deleteChore(id: chore.id)
            chores.removeAll { $0.id == chore.id }
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func completeChore(_ chore: Chore) async {
        do {
            let completion = try await ChoresService.shared.completeChore(id: chore.id)
            if let index = chores.firstIndex(where: { $0.id == chore.id }) {
                chores[index].lastCompletion = completion
            }
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func isDue(_ chore: Chore) -> Bool {
        guard let lastCompletion = chore.lastCompletion else {
            return true // Never done = due
        }

        let now = Date()
        let lastDone = lastCompletion.completedAt

        switch chore.frequency {
        case .daily:
            return !Calendar.current.isDate(lastDone, inSameDayAs: now)
        case .weekly:
            return lastDone < Calendar.current.date(byAdding: .day, value: -7, to: now)!
        case .monthly:
            return lastDone < Calendar.current.date(byAdding: .month, value: -1, to: now)!
        case .asNeeded:
            return false // Never auto-due
        }
    }
}
