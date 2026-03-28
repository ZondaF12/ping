import Foundation
import UserNotifications

/// How long to keep notification history on device (local only; never synced to server).
enum NotificationHistoryRetention: String, CaseIterable, Codable, Sendable {
    case sevenDays = "7d"
    case fourteenDays = "14d"
    case oneMonth = "1mo"
    case sixMonths = "6mo"
    case oneYear = "1y"

    static let storageKey = "ping.notificationHistory.retention.v1"

    var displayTitle: String {
        switch self {
        case .sevenDays: return "7 days"
        case .fourteenDays: return "14 days"
        case .oneMonth: return "1 month"
        case .sixMonths: return "6 months"
        case .oneYear: return "1 year"
        }
    }

    var menuLabel: String {
        "Keep for \(displayTitle)"
    }

    /// Earliest `receivedAt` to keep (inclusive). Entries strictly before this are pruned.
    func earliestIncludedDate(now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .fourteenDays:
            return calendar.date(byAdding: .day, value: -14, to: now)
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: now)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        }
    }
}

struct NotificationHistoryEntry: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String
    var receivedAt: Date
    var title: String?
    var subtitle: String?
    var body: String
    /// Deep link from push `userInfo`, if present.
    var linkURL: String?
    /// Rich notification image URL from push `userInfo["image_url"]`, if present.
    var imageURL: String?

    var primaryLine: String {
        let t = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        if let title, !title.isEmpty { return title }
        return "Notification"
    }

    /// Text shared from the detail sheet.
    var shareText: String {
        var lines: [String] = []
        if let title, !title.isEmpty { lines.append(title) }
        if let subtitle, !subtitle.isEmpty { lines.append(subtitle) }
        let b = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !b.isEmpty { lines.append(b) }
        if let linkURL, !linkURL.isEmpty { lines.append(linkURL) }
        return lines.isEmpty ? "Notification" : lines.joined(separator: "\n")
    }
}

enum NotificationHistoryEntryFactory {
    static func from(notification: UNNotification) -> NotificationHistoryEntry {
        let content = notification.request.content
        let userInfo = content.userInfo
        let url = userInfo["url"] as? String
        let imageURL = userInfo["image_url"] as? String
        let id = notification.request.identifier.isEmpty
            ? UUID().uuidString
            : notification.request.identifier

        let bodyText = content.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleText = content.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitleText = content.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        return NotificationHistoryEntry(
            id: id,
            receivedAt: notification.date,
            title: titleText.isEmpty ? nil : titleText,
            subtitle: subtitleText.isEmpty ? nil : subtitleText,
            body: bodyText.isEmpty && titleText.isEmpty ? "" : bodyText,
            linkURL: url,
            imageURL: imageURL.flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}

struct NotificationHistoryDaySection: Identifiable {
    let dayStart: Date
    let entries: [NotificationHistoryEntry]
    var id: Date { dayStart }

    static func build(
        entries: [NotificationHistoryEntry],
        calendar: Calendar = .current
    ) -> [NotificationHistoryDaySection] {
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.receivedAt) }
        return grouped.keys.sorted(by: >).map { day in
            NotificationHistoryDaySection(
                dayStart: day,
                entries: (grouped[day] ?? []).sorted { $0.receivedAt > $1.receivedAt }
            )
        }
    }

    func headerTitle(calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(dayStart) { return "Today" }
        if calendar.isDateInYesterday(dayStart) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM yyyy"
        f.locale = .current
        return f.string(from: dayStart)
    }
}

enum NotificationHistoryTimeFormatting {
    static func rowTrailingLabel(for date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

enum NotificationHistoryPrune {
    private static let maxEntries = 5000

    static func filtered(
        entries: [NotificationHistoryEntry],
        retention: NotificationHistoryRetention,
        now: Date,
        calendar: Calendar = .current
    ) -> [NotificationHistoryEntry] {
        guard let cutoff = retention.earliestIncludedDate(now: now, calendar: calendar) else {
            return entries
        }
        let kept = entries.filter { $0.receivedAt >= cutoff }
        if kept.count <= maxEntries { return kept }
        return Array(
            kept.sorted { $0.receivedAt > $1.receivedAt }.prefix(maxEntries)
        )
    }
}
