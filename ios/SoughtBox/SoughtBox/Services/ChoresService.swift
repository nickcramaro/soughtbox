import Foundation

actor ChoresService {
    static let shared = ChoresService()

    private init() {}

    struct ChoresResponse: Decodable {
        let chores: [Chore]
    }

    struct ChoreResponse: Decodable {
        let chore: Chore
    }

    struct CompletionResponse: Decodable {
        let completion: ChoreCompletion
    }

    struct SuccessResponse: Decodable {
        let success: Bool
    }

    struct CreateChoreRequest: Encodable {
        let name: String
        let frequency: String
        let effortLevel: String
    }

    func getChores() async throws -> [Chore] {
        let response: ChoresResponse = try await APIClient.shared.get("/chores")
        return response.chores
    }

    func createChore(name: String, frequency: Frequency, effortLevel: EffortLevel) async throws -> Chore {
        let response: ChoreResponse = try await APIClient.shared.post(
            "/chores",
            body: CreateChoreRequest(
                name: name,
                frequency: frequency.rawValue,
                effortLevel: effortLevel.rawValue
            )
        )
        return response.chore
    }

    func deleteChore(id: String) async throws {
        let _: SuccessResponse = try await APIClient.shared.delete("/chores/\(id)")
    }

    func completeChore(id: String) async throws -> ChoreCompletion {
        let response: CompletionResponse = try await APIClient.shared.post("/chores/\(id)/complete")
        return response.completion
    }
}
