import Foundation
import SwiftData
import XCTest
@testable import Science_Club_Diary

@MainActor
final class JournalEntryPersistenceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: MoodEntry.self, configurations: configuration)
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    func testCreatePersistsEveryMoodEntryField() throws {
        let date = Date(timeIntervalSince1970: 1_785_484_800)
        let draft = makeDraft()

        let saved = try MoodEntrySaveService.save(
            draft: draft,
            editing: nil,
            in: context,
            now: date
        )

        let entries = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, saved.id)
        XCTAssertEqual(entries.first?.date, date)
        XCTAssertEqual(entries.first.map(JournalEntryDraft.init(entry:)), draft)
    }

    func testEditingUpdatesTheSameRecordWithoutCreatingDuplicate() throws {
        let original = try MoodEntrySaveService.save(
            draft: makeDraft(notes: "最初のメモ"),
            editing: nil,
            in: context,
            now: Date(timeIntervalSince1970: 1_785_484_800)
        )
        let originalID = original.id
        let originalDate = original.date

        let updatedDraft = makeDraft(moodScore: 6, notes: "編集後のメモ")
        let updated = try MoodEntrySaveService.save(
            draft: updatedDraft,
            editing: original,
            in: context
        )

        let entries = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(updated.id, originalID)
        XCTAssertEqual(entries.first?.id, originalID)
        XCTAssertEqual(entries.first?.date, originalDate)
        XCTAssertEqual(entries.first?.moodScore, 6)
        XCTAssertEqual(entries.first?.notes, "編集後のメモ")
    }

    func testCreateFailureDoesNotPersistRecordOrMutateDraft() throws {
        let draft = makeDraft(notes: "失敗しても残す入力")
        let originalDraft = draft

        XCTAssertThrowsError(
            try MoodEntrySaveService.save(
                draft: draft,
                editing: nil,
                in: context,
                persist: { _ in throw TestError.forcedFailure }
            )
        )

        XCTAssertEqual(draft, originalDraft)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 0)
    }

    func testEditFailureRollsBackPersistedValues() throws {
        let originalDraft = makeDraft(moodScore: 3, notes: "保存済み")
        let entry = try MoodEntrySaveService.save(
            draft: originalDraft,
            editing: nil,
            in: context
        )

        XCTAssertThrowsError(
            try MoodEntrySaveService.save(
                draft: makeDraft(moodScore: 7, notes: "保存に失敗"),
                editing: entry,
                in: context,
                persist: { _ in throw TestError.forcedFailure }
            )
        )

        let entries = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first.map(JournalEntryDraft.init(entry:)), originalDraft)
    }

    func testUnusedDraftHasNoPersistenceSideEffect() throws {
        _ = makeDraft(notes: "キャンセルする入力")

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 0)
    }

    func testLegacyRecordTypeAndExistingFieldsRoundTrip() throws {
        let legacy = makeDraft(recordType: "今日一日の気分", notes: "既存形式")
        _ = try MoodEntrySaveService.save(draft: legacy, editing: nil, in: context)

        context = ModelContext(container)
        let loaded = try context.fetch(FetchDescriptor<MoodEntry>())

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.recordType, "今日一日の気分")
        XCTAssertEqual(loaded.first.map(JournalEntryDraft.init(entry:)), legacy)
    }

    func testLegacyRecordTypesMapToInternalKindsWithoutSchemaChange() {
        XCTAssertEqual(RecordKind(storedValue: "今現在の気分"), .moment)
        XCTAssertEqual(RecordKind(storedValue: "今の気分"), .moment)
        XCTAssertEqual(RecordKind(storedValue: "瞬間記録"), .moment)
        XCTAssertEqual(RecordKind(storedValue: "今日一日の気分"), .dailyReflection)
        XCTAssertEqual(RecordKind(storedValue: "1日の振り返り"), .dailyReflection)
        XCTAssertEqual(RecordKind(storedValue: "一日振り返り"), .dailyReflection)
        XCTAssertEqual(RecordKind(storedValue: "旧バージョンの未知の値"), .moment)
    }

    func testMomentRecordsCanRepeatOnSameDay() throws {
        let now = Date(timeIntervalSince1970: 1_785_484_800)

        _ = try MoodEntrySaveService.save(
            draft: makeDraft(recordType: RecordKind.moment.storageValue, notes: "朝"),
            editing: nil,
            in: context,
            now: now
        )
        _ = try MoodEntrySaveService.save(
            draft: makeDraft(recordType: RecordKind.moment.storageValue, notes: "夕方"),
            editing: nil,
            in: context,
            now: now.addingTimeInterval(60)
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 2)
    }

    func testDailyReflectionRejectsSecondRecordOnSameLocalDay() throws {
        let calendar = japaneseCalendar()
        let firstDate = localDate(year: 2026, month: 7, day: 31, hour: 8, calendar: calendar)
        let secondDate = localDate(year: 2026, month: 7, day: 31, hour: 23, calendar: calendar)
        let first = try MoodEntrySaveService.save(
            draft: makeDraft(recordType: RecordKind.dailyReflection.storageValue, notes: "先の記録"),
            editing: nil,
            in: context,
            now: firstDate,
            calendar: calendar
        )

        XCTAssertThrowsError(
            try MoodEntrySaveService.save(
                draft: makeDraft(recordType: RecordKind.dailyReflection.storageValue, notes: "重複"),
                editing: nil,
                in: context,
                now: secondDate,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(
                error as? JournalEntrySaveError,
                .dailyReflectionAlreadyExists(first.id)
            )
        }

        let entries = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.notes, "先の記録")
    }

    func testDailyReflectionAllowsAdjacentLocalDays() throws {
        let calendar = japaneseCalendar()
        let firstDate = localDate(year: 2026, month: 7, day: 31, hour: 23, minute: 59, calendar: calendar)
        let nextDate = localDate(year: 2026, month: 8, day: 1, hour: 0, minute: 1, calendar: calendar)

        _ = try MoodEntrySaveService.save(
            draft: makeDraft(recordType: RecordKind.dailyReflection.storageValue),
            editing: nil,
            in: context,
            now: firstDate,
            calendar: calendar
        )
        _ = try MoodEntrySaveService.save(
            draft: makeDraft(recordType: RecordKind.dailyReflection.storageValue),
            editing: nil,
            in: context,
            now: nextDate,
            calendar: calendar
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 2)
    }

    func testEditingExistingDailyReflectionUpdatesSameRecord() throws {
        let calendar = japaneseCalendar()
        let date = localDate(year: 2026, month: 7, day: 31, hour: 21, calendar: calendar)
        let original = try MoodEntrySaveService.save(
            draft: makeDraft(recordType: RecordKind.dailyReflection.storageValue, notes: "保存前"),
            editing: nil,
            in: context,
            now: date,
            calendar: calendar
        )

        let updated = try MoodEntrySaveService.save(
            draft: makeDraft(recordType: RecordKind.dailyReflection.storageValue, notes: "編集後"),
            editing: original,
            in: context,
            calendar: calendar
        )

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.notes, "編集後")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 1)
    }

    func testDraftNormalizationRemovesBlankAndDuplicateTags() throws {
        var draft = makeDraft(notes: "  メモ  ")
        draft.influences = [" 天気 ", "", "天気", "  ", "学校"]

        let saved = try MoodEntrySaveService.save(
            draft: draft,
            editing: nil,
            in: context
        )

        XCTAssertEqual(saved.notes, "メモ")
        XCTAssertEqual(saved.influences, ["天気", "学校"])
    }

    func testDeleteFailureKeepsPersistedEntry() throws {
        let entry = try MoodEntrySaveService.save(
            draft: makeDraft(notes: "削除しない"),
            editing: nil,
            in: context
        )

        XCTAssertThrowsError(
            try MoodEntryDeletionService.delete(
                entry,
                in: context,
                persist: { _ in throw TestError.forcedFailure }
            )
        )

        let entries = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, entry.id)
    }

    private func japaneseCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func localDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }

    private func makeDraft(
        recordType: String = "今現在の気分",
        moodScore: Int = 5,
        notes: String = "短いメモ"
    ) -> JournalEntryDraft {
        JournalEntryDraft(
            recordType: recordType,
            mood: "やや快適",
            moodScore: moodScore,
            emotions: ["希望", "感謝"],
            influences: ["家族", "天気"],
            lifeFactors: ["睡眠", "食事"],
            notes: notes,
            activities: ["散歩", "読書"],
            gratitude: "話を聞いてもらえた",
            reflections: "急がずに振り返れた"
        )
    }

    private enum TestError: Error {
        case forcedFailure
    }
}
