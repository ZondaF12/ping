import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum DeviceInfo {
    static var deviceLabel: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "Device"
        #endif
    }

    /// Matches `device_kind` in `@ping/shared` / API.
    static var deviceKind: String {
        #if canImport(UIKit)
        #if targetEnvironment(macCatalyst)
        return "catalyst"
        #endif
        switch UIDevice.current.userInterfaceIdiom {
        case .phone: return "iphone"
        case .pad: return "ipad"
        case .mac: return "mac"
        case .tv: return "tv"
        case .carPlay: return "unspecified"
        case .unspecified: return "unspecified"
        case .vision: return "vision"
        @unknown default: return "unspecified"
        }
        #else
        return "unspecified"
        #endif
    }

    /// Matches API `apns_environment` (`sandbox` | `production`).
    static var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}
