import Foundation
import Testing
@testable import ping

struct NotificationHistoryPruneTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    @Test func sevenDayRetentionDropsOldEntries() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let old = NotificationHistoryEntry(
            id: "a",
            receivedAt: Date(timeIntervalSince1970: 1_699_000_000),
            title: nil,
            subtitle: nil,
            body: "old",
            linkURL: nil,
            imageURL: nil
        )
        let recent = NotificationHistoryEntry(
            id: "b",
            receivedAt: now,
            title: nil,
            subtitle: nil,
            body: "new",
            linkURL: nil,
            imageURL: nil
        )
        let out = NotificationHistoryPrune.filtered(
            entries: [old, recent],
            retention: .sevenDays,
            now: now,
            calendar: calendar
        )
        #expect(out.count == 1)
        #expect(out.first?.id == "b")
    }

    @Test func earliestIncludedDateForOneYear() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cutoff = NotificationHistoryRetention.oneYear.earliestIncludedDate(now: now, calendar: calendar)!
        let expected = calendar.date(byAdding: .year, value: -1, to: now)!
        #expect(cutoff == expected)
    }

    @Test func decodesStoredJSONWithoutImageURLKey() throws {
        let receivedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let interval = receivedAt.timeIntervalSinceReferenceDate
        let json = """
        [{"id":"x","receivedAt":\(interval),"title":null,"subtitle":null,"body":"hi","linkURL":null}]
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode([NotificationHistoryEntry].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded[0].imageURL == nil)
        #expect(decoded[0].body == "hi")
    }

    @Test func maxEntryCapTrimsOldest() {
        let now = Date()
        var many: [NotificationHistoryEntry] = []
        for i in 0 ..< 6000 {
            let d = calendar.date(byAdding: .second, value: -i, to: now)!
            many.append(
                NotificationHistoryEntry(
                    id: "id-\(i)",
                    receivedAt: d,
                    title: nil,
                    subtitle: nil,
                    body: "x",
                    linkURL: nil,
                    imageURL: nil
                )
            )
        }
        let out = NotificationHistoryPrune.filtered(
            entries: many,
            retention: .oneYear,
            now: now,
            calendar: calendar
        )
        #expect(out.count == 5000)
    }
}
