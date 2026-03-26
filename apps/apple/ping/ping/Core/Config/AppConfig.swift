import Foundation

enum AppConfig {
    static let apiBase =
        ProcessInfo.processInfo.environment["PING_API_BASE_URL"] ?? "http://127.0.0.1:3000"
}
