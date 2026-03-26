import Foundation

enum AppConfig {
    static let apiBase =
        ProcessInfo.processInfo.environment["PING_API_BASE_URL"] ?? "http://127.0.0.1:3000"
    static let cloudKitApiToken =
        ProcessInfo.processInfo.environment["PING_CLOUDKIT_API_TOKEN"] ?? ""
}
