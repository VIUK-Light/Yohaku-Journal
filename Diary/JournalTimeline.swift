import Foundation

/// タイムラインの表示条件。入力画面やSwiftDataモデルとは分離して保持する。
struct JournalTimelineQuery: Equatable {
    var text = ""
    var recordKind: RecordKind?
    var eventTag: String?
    var range: JournalTimelineRange = .all

    var hasActiveFilters: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        recordKind != nil ||
        eventTag != nil ||
        range != .all
    }
}

enum JournalTimelineRange: String, CaseIterable, Identifiable {
    case all
    case week
    case month
    case quarter

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "すべて"
        case .week: return "7日"
        case .month: return "30日"
        case .quarter: return "90日"
        }
    }

    var dayCount: Int? {
        switch self {
        case .all: return nil
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }
}

struct JournalDaySection: Identifiable {
    let date: Date
    let entries: [MoodEntry]

    var id: Date { date }
}

/// 大量のViewを先に作らず、絞り込みと日付グループだけを一度に計算する。
enum JournalTimeline {
    static func sections(
        from entries: [MoodEntry],
        query: JournalTimelineQuery,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [JournalDaySection] {
        let filtered = filtered(entries: entries, query: query, now: now, calendar: calendar)
        var grouped: [Date: [MoodEntry]] = [:]

        for entry in filtered {
            grouped[calendar.startOfDay(for: entry.date), default: []].append(entry)
        }

        return grouped.keys.sorted(by: >).map { day in
            JournalDaySection(
                date: day,
                entries: (grouped[day] ?? []).sorted { $0.date > $1.date }
            )
        }
    }

    static func filtered(
        entries: [MoodEntry],
        query: JournalTimelineQuery,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MoodEntry] {
        let normalizedText = query.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let bounds = dateBounds(for: query.range, now: now, calendar: calendar)

        return entries.filter { entry in
            if let bounds, !(entry.date >= bounds.lowerBound && entry.date < bounds.upperBound) {
                return false
            }

            if let recordKind = query.recordKind, entry.recordKind != recordKind {
                return false
            }

            if let eventTag = query.eventTag, !entry.influences.contains(eventTag) {
                return false
            }

            guard !normalizedText.isEmpty else { return true }
            let searchableValues = [
                entry.mood,
                entry.recordType,
                entry.notes,
                entry.gratitude,
                entry.reflections
            ] + entry.emotions + entry.influences + entry.lifeFactors + entry.activities

            return searchableValues.contains {
                $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
                    .contains(normalizedText)
            }
        }
        .sorted { $0.date > $1.date }
    }

    static func eventTags(from entries: [MoodEntry]) -> [String] {
        Set(entries.flatMap(\.influences))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted()
    }

    private static func dateBounds(
        for range: JournalTimelineRange,
        now: Date,
        calendar: Calendar
    ) -> Range<Date>? {
        guard let dayCount = range.dayCount else { return nil }
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else {
            return nil
        }
        return start..<end
    }
}
