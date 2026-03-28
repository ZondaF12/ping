import Combine
import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class NotificationHistoryStore: ObservableObject {
    private static let entriesKey = "ping.notificationHistory.entries.v1"

    @Published private(set) var entries: [NotificationHistoryEntry] = []
    @Published private(set) var retention: NotificationHistoryRetention

    init(defaults: UserDefaults = .standard) {
        if let raw = defaults.string(forKey: NotificationHistoryRetention.storageKey),
           let r = NotificationHistoryRetention(rawValue: raw) {
            retention = r
        } else {
            retention = .fourteenDays
        }
        entries = Self.loadEntries(from: defaults)
        applyPruneAndSave()
        if defaults.string(forKey: NotificationHistoryRetention.storageKey) == nil {
            defaults.set(retention.rawValue, forKey: NotificationHistoryRetention.storageKey)
        }
    }

    func updateRetention(_ newValue: NotificationHistoryRetention) {
        guard newValue != retention else { return }
        retention = newValue
        UserDefaults.standard.set(retention.rawValue, forKey: NotificationHistoryRetention.storageKey)
        applyPruneAndSave()
    }

    func recordIfNew(_ notification: UNNotification) {
        let entry = NotificationHistoryEntryFactory.from(notification: notification)
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        var next = entries
        next.append(entry)
        next.sort { $0.receivedAt > $1.receivedAt }
        entries = next
        applyPruneAndSave()
    }

    /// Merge notifications still in Notification Center (helps backfill background deliveries).
    func syncDeliveredNotifications() async {
        let delivered = await withCheckedContinuation { (cont: CheckedContinuation<[UNNotification], Never>) in
            UNUserNotificationCenter.current().getDeliveredNotifications { notes in
                cont.resume(returning: notes)
            }
        }
        var next = entries
        var changed = false
        for n in delivered {
            let entry = NotificationHistoryEntryFactory.from(notification: n)
            if !next.contains(where: { $0.id == entry.id }) {
                next.append(entry)
                changed = true
            }
        }
        if changed {
            next.sort { $0.receivedAt > $1.receivedAt }
            entries = next
            applyPruneAndSave()
        }
    }

    func clearAll() {
        entries = []
        saveEntries()
    }

    private func applyPruneAndSave() {
        let pruned = NotificationHistoryPrune.filtered(
            entries: entries,
            retention: retention,
            now: Date()
        )
        entries = pruned.sorted { $0.receivedAt > $1.receivedAt }
        saveEntries()
    }

    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.entriesKey)
    }

    private static func loadEntries(from defaults: UserDefaults) -> [NotificationHistoryEntry] {
        guard let data = defaults.data(forKey: entriesKey) else { return [] }
        return (try? JSONDecoder().decode([NotificationHistoryEntry].self, from: data)) ?? []
    }
}
