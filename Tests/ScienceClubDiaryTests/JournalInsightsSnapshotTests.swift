import Foundation
import XCTest
@testable import Science_Club_Diary

final class JournalInsightsSnapshotTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testSmallEventSamplesDoNotReceiveAnAverage() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let entries = [
            makeEntry(date: now, score: 2, tag: "家族"),
            makeEntry(date: now.addingTimeInterval(-60), score: 6, tag: "家族"),
            makeEntry(date: now.addingTimeInterval(-120), score: 4, tag: "学校"),
            makeEntry(date: now.addingTimeInterval(-180), score: 5, tag: "学校"),
            makeEntry(date: now.addingTimeInterval(-240), score: 6, tag: "学校")
        ]

        let snapshot = JournalInsightsCalculator.make(
            entries: entries,
            range: .all,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.totalEntries, 5)
        XCTAssertEqual(snapshot.eventTagTypeCount, 2)
        XCTAssertNil(snapshot.eventBreakdowns.first { $0.name == "家族" }?.averageMood)
        XCTAssertEqual(snapshot.eventBreakdowns.first { $0.name == "学校" }?.averageMood, 5)
    }

    func testInsightsKeepOnlyTopEightEventTags() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let entries = (1...10).map { index in
            makeEntry(
                date: now.addingTimeInterval(TimeInterval(-index * 60)),
                score: 4,
                tag: "タグ\(index)"
            )
        }

        let snapshot = JournalInsightsCalculator.make(
            entries: entries,
            range: .all,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.eventTagTypeCount, 10)
        XCTAssertEqual(snapshot.eventBreakdowns.count, 8)
        XCTAssertEqual(snapshot.omittedEventTagCount, 2)
    }

    func testWeekRangeIncludesTodayAndSixPreviousLocalDaysOnly() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let today = calendar.startOfDay(for: now)
        let date = { (offset: Int) in
            calendar.date(byAdding: .day, value: offset, to: today)!
        }
        let entries = [
            makeEntry(date: date(0).addingTimeInterval(3_600), score: 2, tag: "学校"),
            makeEntry(date: date(0).addingTimeInterval(7_200), score: 6, tag: "学校"),
            makeEntry(date: date(-1).addingTimeInterval(3_600), score: 4, tag: "学校"),
            makeEntry(date: date(-6).addingTimeInterval(3_600), score: 5, tag: "学校"),
            makeEntry(date: date(-7).addingTimeInterval(3_600), score: 7, tag: "学校")
        ]

        let snapshot = JournalInsightsCalculator.make(
            entries: entries,
            range: .week,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.totalEntries, 4)
        XCTAssertEqual(snapshot.moodTrend.count, 3)
        XCTAssertEqual(snapshot.moodTrend.last?.averageScore, 4)
    }

    func testEventTagsAreTrimmedAndEmptyTagsAreIgnored() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let entry = MoodEntry()
        entry.date = now
        entry.moodScore = 5
        entry.influences = [" 学校 ", "学校", "   ", "\n"]

        let snapshot = JournalInsightsCalculator.make(
            entries: [entry],
            range: .all,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.eventTagTypeCount, 1)
        XCTAssertEqual(snapshot.eventBreakdowns.map(\.name), ["学校"])
        XCTAssertEqual(snapshot.eventBreakdowns.first?.entryCount, 1)
    }

    private func makeEntry(date: Date, score: Int, tag: String) -> MoodEntry {
        let entry = MoodEntry()
        entry.date = date
        entry.moodScore = score
        entry.mood = "気分\(score)"
        entry.influences = [tag]
        return entry
    }
}
