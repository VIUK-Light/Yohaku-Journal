import SwiftUI
import SwiftData

/// 日記の履歴と、選択中の記録を一つの作業面で扱うメイン画面。
struct MoodJournalView: View {
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)])
    private var moodEntries: [MoodEntry]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedEntry: MoodEntry?
    @State private var route: JournalRoute = .welcome
    @State private var showingArticles = false
    @State private var showingMentalHealthCheck = false
    @State private var showingAppInfo = false
    @State private var entryPendingDeletion: MoodEntry?
    @State private var showingDeletionError = false
    @State private var deletionErrorMessage = ""

    @Namespace private var namespace

    private enum JournalRoute {
        case welcome
        case new
        case detail
        case edit
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingAppInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("アプリについて")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    startNewEntry()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新しい記録を作成")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingArticles = true
                    } label: {
                        Label("心の健康記事", systemImage: "book")
                    }

                    Button {
                        showingMentalHealthCheck = true
                    } label: {
                        Label("セルフチェック", systemImage: "list.bullet.clipboard")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("心の健康ツール")
            }
        }
        .sheet(isPresented: $showingArticles) {
            ArticleListView()
        }
        .sheet(isPresented: $showingMentalHealthCheck) {
            MentalHealthCheckView()
        }
        .sheet(isPresented: $showingAppInfo) {
            AppInfoView()
        }
        .navigationTitle("心の記録")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "この記録を削除しますか？",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        entryPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                deletePendingEntry()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除した記録は元に戻せません。")
        }
        .alert("削除できませんでした", isPresented: $showingDeletionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage)
        }
        .frame(
            minWidth: DiaryRuntime.isMacWindow ? 1024 : 0,
            minHeight: DiaryRuntime.isMacWindow ? 700 : 0
        )
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            if !moodEntries.isEmpty {
                todaySummary
                Divider()
            }

            moodEntriesList
        }
        .background(DiaryTheme.canvas)
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch route {
        case .welcome:
            welcomeView
        case .new:
            NewMoodEntryView(
                onSave: finishSaving,
                onCancel: cancelEditor
            )
        case .detail:
            if let selectedEntry {
                MoodEntryDetailView(
                    entry: selectedEntry,
                    onEdit: { route = .edit },
                    onDelete: {
                        self.selectedEntry = nil
                        route = .welcome
                    }
                )
            } else {
                welcomeView
            }
        case .edit:
            if let selectedEntry {
                NewMoodEntryView(
                    entryToEdit: selectedEntry,
                    onSave: finishSaving,
                    onCancel: cancelEditor
                )
            } else {
                welcomeView
            }
        }
    }

    private var todaySummary: some View {
        HStack(spacing: 12) {
            DiaryLineIcon(
                kind: .mood(todayEntry?.moodScore ?? 4),
                color: todayEntry.map { DiaryTheme.moodColor(for: $0.moodScore) } ?? DiaryTheme.muted,
                size: 32
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("今日の気分")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DiaryTheme.muted)
                Text(todayEntry?.mood ?? "まだ記録なし")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DiaryTheme.ink)
            }

            Spacer()

            if let todayEntry {
                Text("\(todayEntry.moodScore)/7")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DiaryTheme.moodColor(for: todayEntry.moodScore))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DiaryTheme.surface)
    }

    @ViewBuilder
    private var moodEntriesList: some View {
        if moodEntries.isEmpty {
            ContentUnavailableView {
                Label("まだ記録がありません", systemImage: "square.and.pencil")
            } description: {
                Text("必要なときに、今の気持ちを残せます")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DiaryTheme.canvas)
        } else {
            List(moodEntries) { entry in
                MoodEntryRow(entry: entry, namespace: namespace)
                    .listRowBackground(selectedEntry?.id == entry.id ? DiaryTheme.accentSoft : DiaryTheme.surface)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedEntry = entry
                        route = .detail
                    }
                    .accessibilityHint("タップして記録の詳細を表示")
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            entryPendingDeletion = entry
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DiaryTheme.canvas)
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 22) {
            DiaryLineIcon(kind: .journal, color: DiaryTheme.accent, size: 70)

            VStack(spacing: 8) {
                Text("心の記録")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(DiaryTheme.ink)

                Text("必要なときに、必要なだけ。\n今の気持ちを静かに残せます。")
                    .font(.body)
                    .foregroundStyle(DiaryTheme.muted)
                    .multilineTextAlignment(.center)
            }

            Button {
                startNewEntry()
            } label: {
                Label("記録を始める", systemImage: "plus")
                    .font(.headline)
                    .frame(minWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .controlSize(.large)
            .tint(DiaryTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(DiaryTheme.canvas)
    }

    private var todayEntry: MoodEntry? {
        let calendar = Calendar.current
        return moodEntries.first { entry in
            calendar.isDate(entry.date, inSameDayAs: Date())
        }
    }

    private func startNewEntry() {
        selectedEntry = nil
        route = .new
    }

    private func cancelEditor() {
        route = selectedEntry == nil ? .welcome : .detail
    }

    private func finishSaving(_ entry: MoodEntry) {
        selectedEntry = entry
        route = .detail
    }

    private func deletePendingEntry() {
        guard let entry = entryPendingDeletion else { return }

        modelContext.delete(entry)
        do {
            try modelContext.save()
            if selectedEntry?.id == entry.id {
                selectedEntry = nil
                route = .welcome
            }
            entryPendingDeletion = nil
        } catch {
            modelContext.rollback()
            entryPendingDeletion = nil
            deletionErrorMessage = error.localizedDescription
            showingDeletionError = true
        }
    }
}

struct MoodEntryRow: View {
    let entry: MoodEntry
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 12) {
            DiaryLineIcon(
                kind: .mood(entry.moodScore),
                color: DiaryTheme.moodColor(for: entry.moodScore),
                size: 30
            )
            .matchedGeometryEffect(id: "mood_icon_\(entry.id)", in: namespace)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mood)
                    .font(.headline)
                    .foregroundStyle(DiaryTheme.ink)
                Text(entry.recordType)
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.subheadline)
                        .foregroundStyle(DiaryTheme.muted)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(japaneseDateTimeString(from: entry.date))
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
                Text("\(entry.moodScore)/7")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DiaryTheme.moodColor(for: entry.moodScore))
            }
        }
        .padding(.vertical, 5)
    }

    private func japaneseDateTimeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
