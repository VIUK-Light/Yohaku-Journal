import Foundation

enum JournalInsightRange: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case all

    var id: Self { self }

    var title: String {
        switch self {
        case .week: return "7日"
        case .month: return "30日"
        case .quarter: return "90日"
        case .all: return "すべて"
        }
    }

    var dayCount: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .all: return nil
        }
    }
}

struct MoodTrendPoint: Identifiable {
    let date: Date
    let averageScore: Double
    let entryCount: Int

    var id: Date { date }
}

struct EventBreakdown: Identifiable {
    let name: String
    let entryCount: Int
    let averageMood: Double?

    var id: String { name }
}

struct JournalInsightsSnapshot {
    let totalEntries: Int
    let averageMood: Double?
    let eventTagTypeCount: Int
    let moodTrend: [MoodTrendPoint]
    let eventBreakdowns: [EventBreakdown]
    let omittedEventTagCount: Int
}

private struct MoodAggregate {
    var total = 0
    var count = 0
}

/// 記録配列を一度だけ走査し、観察画面に必要な値型だけを作る。
enum JournalInsightsCalculator {
    static func make(
        entries: [MoodEntry],
        range: JournalInsightRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> JournalInsightsSnapshot {
        let today = calendar.startOfDay(for: now)
        let endDate = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let startDate: Date

        if let dayCount = range.dayCount {
            startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        } else {
            startDate = entries.map { calendar.startOfDay(for: $0.date) }.min() ?? today
        }

        var totalEntries = 0
        var totalMoodScore = 0
        var moodByDay: [Date: MoodAggregate] = [:]
        var events: [String: MoodAggregate] = [:]

        for entry in entries where entry.date >= startDate && entry.date < endDate {
            totalEntries += 1
            totalMoodScore += entry.moodScore

            let day = calendar.startOfDay(for: entry.date)
            moodByDay[day, default: MoodAggregate()].count += 1
            moodByDay[day, default: MoodAggregate()].total += entry.moodScore

            let normalizedEvents = Set(entry.influences.compactMap { event in
                let trimmed = event.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            })
            for event in normalizedEvents {
                events[event, default: MoodAggregate()].count += 1
                events[event, default: MoodAggregate()].total += entry.moodScore
            }
        }

        let trend = moodByDay.keys.sorted().compactMap { day -> MoodTrendPoint? in
            guard let aggregate = moodByDay[day], aggregate.count > 0 else { return nil }
            return MoodTrendPoint(
                date: day,
                averageScore: Double(aggregate.total) / Double(aggregate.count),
                entryCount: aggregate.count
            )
        }

        let sortedEvents = events.map { name, aggregate in
            EventBreakdown(
                name: name,
                entryCount: aggregate.count,
                averageMood: aggregate.count >= 3
                    ? Double(aggregate.total) / Double(aggregate.count)
                    : nil
            )
        }
        .sorted {
            if $0.entryCount == $1.entryCount { return $0.name < $1.name }
            return $0.entryCount > $1.entryCount
        }

        return JournalInsightsSnapshot(
            totalEntries: totalEntries,
            averageMood: totalEntries == 0 ? nil : Double(totalMoodScore) / Double(totalEntries),
            eventTagTypeCount: events.count,
            moodTrend: trend,
            eventBreakdowns: Array(sortedEvents.prefix(8)),
            omittedEventTagCount: max(0, sortedEvents.count - 8)
        )
    }
}
