import Foundation

enum AppConfig {
    static let apiBase =
        ProcessInfo.processInfo.environment["PING_API_BASE_URL"] ?? "https://ping-production-9dc3.up.railway.app"

    static let cloudKitApiToken: String = {
        let key = "PING_CLOUDKIT_API_TOKEN"
        let env = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !env.isEmpty { return env }
        if let plist = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let v = plist.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { return v }
        }
        return ""
    }()
}
