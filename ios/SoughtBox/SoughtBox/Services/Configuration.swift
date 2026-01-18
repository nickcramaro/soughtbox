import Foundation

enum Configuration {
    static let apiBaseURL: URL = {
        #if DEBUG
        // Use localhost for simulator, your Mac's IP for device
        return URL(string: "http://localhost:3000")!
        #else
        return URL(string: "https://api.soughtbox.app")!
        #endif
    }()

    static let wsBaseURL: URL = {
        #if DEBUG
        return URL(string: "ws://localhost:3000/ws")!
        #else
        return URL(string: "wss://api.soughtbox.app/ws")!
        #endif
    }()
}
