import SwiftUI

struct MoodEntryRow: View {
    let entry: MoodEntry

    var body: some View {
        HStack(spacing: 12) {
            DiaryLineIcon(
                kind: .mood(entry.moodScore),
                color: DiaryTheme.moodColor(for: entry.moodScore),
                size: 34
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.mood)
                        .font(.headline)
                        .foregroundStyle(DiaryTheme.ink)
                    Text(entry.recordKind.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DiaryTheme.muted)
                }

                if !entry.influences.isEmpty {
                    Text(entry.influences.prefix(3).joined(separator: "・"))
                        .font(.caption)
                        .foregroundStyle(DiaryTheme.orange)
                        .lineLimit(1)
                } else if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.subheadline)
                        .foregroundStyle(DiaryTheme.muted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Text(timeString(entry.date))
                .font(.caption)
                .foregroundStyle(DiaryTheme.muted)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("タップして詳細を開きます")
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
