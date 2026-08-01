import SwiftUI

/// 今日の記録と、保存済みの記録を一つのタイムラインとして表示する。
struct JournalRecordView: View {
    let entries: [MoodEntry]
    let showsRecentEntries: Bool
    let onCreate: (RecordKind) -> Void
    let onEdit: (MoodEntry) -> Void
    let onSelect: (MoodEntry) -> Void
    let onDelete: (MoodEntry) -> Void

    @State private var query = JournalTimelineQuery()

    private var todayEntries: [MoodEntry] {
        entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    private var latestMoment: MoodEntry? {
        todayEntries.first { $0.recordKind == .moment }
    }

    private var todayDailyReflection: MoodEntry? {
        todayEntries.first { $0.recordKind == .dailyReflection }
    }

    private var timelineSections: [JournalDaySection] {
        JournalTimeline.sections(from: entries, query: query)
    }

    var body: some View {
        Group {
            if showsRecentEntries {
                recordList.searchable(text: $query.text, prompt: "本文やタグを検索")
            } else {
                recordList
            }
        }
        .navigationTitle("記録")
        .navigationBarTitleDisplayMode(.large)
    }

    private var recordList: some View {
        List {
            Section {
                todayPanel
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(DiaryTheme.canvas)
                    .listRowSeparator(.hidden)
            }

            if showsRecentEntries {
                Section {
                    JournalFilterBar(
                        query: $query,
                        eventTags: JournalTimeline.eventTags(from: entries)
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(DiaryTheme.canvas)
                    .listRowSeparator(.hidden)
                }

                if timelineSections.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            DiaryLineIcon(kind: .journal, color: DiaryTheme.muted, size: 38)
                            Text(entries.isEmpty ? "まだ記録がありません" : "条件に合う記録がありません")
                                .font(.headline)
                            if query.hasActiveFilters {
                                Button("絞り込みを解除") { query = JournalTimelineQuery() }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .listRowBackground(DiaryTheme.canvas)
                        .listRowSeparator(.hidden)
                    }
                } else {
                    ForEach(timelineSections) { section in
                        Section(dayTitle(section.date)) {
                            ForEach(section.entries) { entry in
                                Button { onSelect(entry) } label: {
                                    MoodEntryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(DiaryTheme.surface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { onDelete(entry) } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DiaryTheme.canvas)
    }

    private var todayPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("今日")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(DiaryTheme.ink)

                    if let latestMoment {
                        Text("最後の瞬間記録：\(latestMoment.mood)・\(timeString(latestMoment.date))")
                            .font(.subheadline)
                            .foregroundStyle(DiaryTheme.muted)
                    } else {
                        Text("まだ瞬間記録はありません")
                            .font(.subheadline)
                            .foregroundStyle(DiaryTheme.muted)
                    }
                }

                Spacer(minLength: 8)
                DiaryLineIcon(
                    kind: .mood(latestMoment?.moodScore ?? 4),
                    color: latestMoment.map { DiaryTheme.moodColor(for: $0.moodScore) } ?? DiaryTheme.muted,
                    size: 48
                )
            }

            HStack(spacing: 14) {
                Label("瞬間 \(todayEntries.lazy.filter { $0.recordKind == .moment }.count)件", systemImage: "clock")
                Label(
                    todayDailyReflection == nil ? "振り返り 未作成" : "振り返り 保存済み",
                    systemImage: todayDailyReflection == nil ? "circle" : "checkmark.circle"
                )
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(DiaryTheme.muted)

            Button { onCreate(.moment) } label: {
                Label("今の気分を記録", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .controlSize(.large)
            .tint(DiaryTheme.primary)

            Button {
                if let todayDailyReflection { onEdit(todayDailyReflection) }
                else { onCreate(.dailyReflection) }
            } label: {
                HStack {
                    Text(todayDailyReflection == nil ? "一日を振り返る" : "今日の振り返りを編集")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.bold())
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DiaryTheme.ink)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("瞬間記録は何度でも。一日振り返りは、その日に1件だけ保存できます。")
                .font(.caption)
                .foregroundStyle(DiaryTheme.muted)
        }
        .frame(maxWidth: 680, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今日" }
        if Calendar.current.isDateInYesterday(date) { return "昨日" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter.string(from: date)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct JournalFilterBar: View {
    @Binding var query: JournalTimelineQuery
    let eventTags: [String]

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Section("記録の種類") {
                    Button("すべて") { query.recordKind = nil }
                    Button(RecordKind.moment.title) { query.recordKind = .moment }
                    Button(RecordKind.dailyReflection.title) { query.recordKind = .dailyReflection }
                }
                Section("期間") {
                    ForEach(JournalTimelineRange.allCases) { range in
                        Button(range.title) { query.range = range }
                    }
                }
                if !eventTags.isEmpty {
                    Section("出来事") {
                        Button("すべて") { query.eventTag = nil }
                        ForEach(eventTags, id: \.self) { tag in
                            Button(tag) { query.eventTag = tag }
                        }
                    }
                }
            } label: {
                Label(filterTitle, systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.bordered)

            if query.hasActiveFilters {
                Button("解除") { query = JournalTimelineQuery() }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("絞り込みを解除")
            }

            Spacer()
        }
    }

    private var filterTitle: String {
        if let recordKind = query.recordKind { return recordKind.title }
        if let eventTag = query.eventTag { return eventTag }
        if query.range != .all { return query.range.title }
        return "絞り込み"
    }
}
