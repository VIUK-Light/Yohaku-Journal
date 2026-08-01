import Foundation
import SwiftData

/// 入力画面の値をSwiftDataモデルから切り離して保持する保存用スナップショット。
///
/// 保存に失敗してもこの値は変化しないため、画面は利用者の入力を維持できる。
struct JournalEntryDraft: Equatable {
    var recordType: String
    var mood: String
    var moodScore: Int
    var emotions: [String]
    var influences: [String]
    var lifeFactors: [String]
    var notes: String
    var activities: [String]
    var gratitude: String
    var reflections: String

    var recordKind: RecordKind {
        get { RecordKind(storedValue: recordType) }
        set { recordType = newValue.storageValue }
    }

    init(
        recordType: String,
        mood: String,
        moodScore: Int,
        emotions: [String],
        influences: [String],
        lifeFactors: [String],
        notes: String,
        activities: [String],
        gratitude: String,
        reflections: String
    ) {
        self.recordType = recordType
        self.mood = mood
        self.moodScore = moodScore
        self.emotions = emotions
        self.influences = influences
        self.lifeFactors = lifeFactors
        self.notes = notes
        self.activities = activities
        self.gratitude = gratitude
        self.reflections = reflections
    }

    init(entry: MoodEntry) {
        self.init(
            recordType: entry.recordType,
            mood: entry.mood,
            moodScore: entry.moodScore,
            emotions: entry.emotions,
            influences: entry.influences,
            lifeFactors: entry.lifeFactors,
            notes: entry.notes,
            activities: entry.activities,
            gratitude: entry.gratitude,
            reflections: entry.reflections
        )
    }

    func apply(to entry: MoodEntry) {
        entry.recordType = recordType
        entry.mood = mood
        entry.moodScore = moodScore
        entry.emotions = emotions
        entry.influences = influences
        entry.lifeFactors = lifeFactors
        entry.notes = notes
        entry.activities = activities
        entry.gratitude = gratitude
        entry.reflections = reflections
    }

    func normalized() -> JournalEntryDraft {
        JournalEntryDraft(
            recordType: recordType.trimmingCharacters(in: .whitespacesAndNewlines),
            mood: mood.trimmingCharacters(in: .whitespacesAndNewlines),
            moodScore: moodScore,
            emotions: normalizedValues(emotions),
            influences: normalizedValues(influences),
            lifeFactors: normalizedValues(lifeFactors),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            activities: normalizedValues(activities),
            gratitude: gratitude.trimmingCharacters(in: .whitespacesAndNewlines),
            reflections: reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func normalizedValues(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }
}

enum JournalEntrySaveError: Error, Equatable, LocalizedError {
    case invalidMoodScore
    case emptyMood
    case dailyReflectionAlreadyExists(UUID)

    var errorDescription: String? {
        switch self {
        case .invalidMoodScore:
            return "気分は7段階から選んでください。"
        case .emptyMood:
            return "選んだ気分を確認できませんでした。"
        case .dailyReflectionAlreadyExists:
            return "この日の一日振り返りはすでにあります。既存の記録を編集してください。"
        }
    }
}

/// 日記の新規保存と編集を同じ経路で行い、失敗時の復元規則を一か所に保つ。
@MainActor
enum MoodEntrySaveService {
    typealias ContextSaver = (ModelContext) throws -> Void

    @discardableResult
    static func save(
        draft: JournalEntryDraft,
        editing entryToEdit: MoodEntry?,
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        persist: ContextSaver = { try $0.save() }
    ) throws -> MoodEntry {
        let normalizedDraft = draft.normalized()
        guard (1...7).contains(normalizedDraft.moodScore) else {
            throw JournalEntrySaveError.invalidMoodScore
        }
        guard !normalizedDraft.mood.isEmpty else {
            throw JournalEntrySaveError.emptyMood
        }

        let targetDate = entryToEdit?.date ?? now
        if normalizedDraft.recordKind == .dailyReflection {
            try ensureDailyReflectionIsUnique(
                on: targetDate,
                excluding: entryToEdit?.id,
                in: context,
                calendar: calendar
            )
        }

        let entry = entryToEdit ?? MoodEntry()
        normalizedDraft.apply(to: entry)

        if entryToEdit == nil {
            entry.date = now
            context.insert(entry)
        }

        do {
            try persist(context)
            return entry
        } catch {
            if entryToEdit == nil {
                context.delete(entry)
            } else {
                context.rollback()
            }
            throw error
        }
    }

    private static func ensureDailyReflectionIsUnique(
        on date: Date,
        excluding excludedID: UUID?,
        in context: ModelContext,
        calendar: Calendar
    ) throws {
        let dayStart = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return
        }

        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate { entry in
                entry.date >= dayStart && entry.date < nextDay
            }
        )
        let existing = try context.fetch(descriptor).first { entry in
            entry.id != excludedID && entry.recordKind == .dailyReflection
        }

        if let existing {
            throw JournalEntrySaveError.dailyReflectionAlreadyExists(existing.id)
        }
    }
}

@MainActor
enum MoodEntryDeletionService {
    typealias ContextSaver = (ModelContext) throws -> Void

    static func delete(
        _ entry: MoodEntry,
        in context: ModelContext,
        persist: ContextSaver = { try $0.save() }
    ) throws {
        context.delete(entry)
        do {
            try persist(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
