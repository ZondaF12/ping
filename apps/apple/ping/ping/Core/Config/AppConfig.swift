import Foundation

enum AppConfig {
    static let apiBase =
        ProcessInfo.processInfo.environment["PING_API_BASE_URL"] ?? "https://ping-production-9dc3.up.railway.app"
    static let cloudKitApiToken =
        ProcessInfo.processInfo.environment["PING_CLOUDKIT_API_TOKEN"] ?? ""
}
