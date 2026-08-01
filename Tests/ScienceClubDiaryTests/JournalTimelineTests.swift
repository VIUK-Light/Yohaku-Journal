import Foundation
import XCTest
@testable import Science_Club_Diary

final class JournalTimelineTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testTimelineGroupsByDayAndSearchesBodyAndTags() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let entries = [
            makeEntry(date: now, score: 5, notes: "実験の準備", influences: ["学校"]),
            makeEntry(date: now.addingTimeInterval(-3_600), score: 4, notes: "少し休む", influences: ["健康"]),
            makeEntry(date: now.addingTimeInterval(-86_400), score: 6, notes: "家族と話した", influences: ["家族"])
        ]

        var query = JournalTimelineQuery()
        query.text = "実験"
        XCTAssertEqual(JournalTimeline.sections(from: entries, query: query, now: now, calendar: calendar).count, 1)

        query.text = ""
        query.eventTag = "健康"
        let sections = JournalTimeline.sections(from: entries, query: query, now: now, calendar: calendar)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.entries.count, 1)
        XCTAssertEqual(sections.first?.entries.first?.notes, "少し休む")
    }

    func testTimelineKindAndRangeFiltersDoNotChangeStoredValues() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let entries = [
            makeEntry(date: now, score: 4, kind: .dailyReflection),
            makeEntry(date: now.addingTimeInterval(-8 * 86_400), score: 6, kind: .moment)
        ]
        var query = JournalTimelineQuery()
        query.recordKind = .dailyReflection
        query.range = .week

        let result = JournalTimeline.filtered(entries: entries, query: query, now: now, calendar: calendar)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].recordType, RecordKind.dailyReflection.storageValue)
    }

    private func makeEntry(
        date: Date,
        score: Int,
        kind: RecordKind = .moment,
        notes: String = "",
        influences: [String] = []
    ) -> MoodEntry {
        let entry = MoodEntry()
        entry.date = date
        entry.moodScore = score
        entry.mood = "気分\(score)"
        entry.recordType = kind.storageValue
        entry.notes = notes
        entry.influences = influences
        return entry
    }
}
