import Foundation

@MainActor
@Observable
class WebSocketClient {
    static let shared = WebSocketClient()

    private var webSocket: URLSessionWebSocketTask?
    private var isConnected = false

    var onListUpdate: ((String, Any) -> Void)?
    var onChoreUpdate: ((String, Any) -> Void)?

    private init() {}

    func connect() {
        guard let token = KeychainService.get(.accessToken) else { return }
        guard !isConnected else { return }

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: Configuration.wsBaseURL)
        webSocket?.resume()

        // Authenticate
        let authMessage = ["type": "auth", "token": token]
        if let data = try? JSONSerialization.data(withJSONObject: authMessage),
           let string = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(string)) { _ in }
        }

        isConnected = true
        receiveMessage()
    }

    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case .string(let text) = message,
                   let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String {

                    Task { @MainActor in
                        self?.handleMessage(type: type, payload: json["payload"])
                    }
                }

                // Continue receiving
                Task { @MainActor in
                    self?.receiveMessage()
                }

            case .failure:
                Task { @MainActor in
                    self?.isConnected = false
                    // Reconnect after delay
                    try? await Task.sleep(for: .seconds(5))
                    self?.connect()
                }
            }
        }
    }

    private func handleMessage(type: String, payload: Any?) {
        guard let payload = payload else { return }

        if type.hasPrefix("list") {
            onListUpdate?(type, payload)
        } else if type.hasPrefix("chore") {
            onChoreUpdate?(type, payload)
        }
    }
}
