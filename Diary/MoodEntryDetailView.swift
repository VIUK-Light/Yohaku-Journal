import SwiftUI
import SwiftData

/// 保存済みの日記を確認・編集・削除する画面。
struct MoodEntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable private var entry: MoodEntry

    private let onEdit: () -> Void
    private let onDelete: () -> Void
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""

    init(
        entry: MoodEntry,
        onEdit: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        self.entry = entry
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                moodHeader

                if hasAnyTags {
                    tagsSection
                }

                if hasAnyTextContent {
                    notesAndReflectionsSection
                } else {
                    emptyDetailsCard
                }
            }
            .frame(maxWidth: 640)
            .padding(16)
        }
        .background(DiaryTheme.canvas)
        .navigationTitle("記録の詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    onEdit()
                } label: {
                    Label("編集", systemImage: "pencil")
                }

                Menu {
                    Button("記録を削除", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("その他の操作")
            }
        }
        .confirmationDialog(
            "この記録を削除しますか？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                deleteEntry()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除した記録は元に戻せません。")
        }
        .alert("削除できませんでした", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
    }

    private var moodHeader: some View {
        VStack(spacing: 12) {
            DiaryLineIcon(
                kind: .mood(entry.moodScore),
                color: DiaryTheme.moodColor(for: entry.moodScore),
                size: 76
            )

            Text(entry.mood)
                .font(.largeTitle.weight(.bold))

            HStack(spacing: 8) {
                Label(entry.recordType, systemImage: "clock")
                Text("・")
                Text("スコア \(entry.moodScore)/7")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DiaryTheme.muted)

            Text(formattedDate(entry.date))
                .font(.caption)
                .foregroundStyle(DiaryTheme.muted.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("記録した項目", systemImage: "tag.fill")

            if !entry.emotions.isEmpty {
                tagGroup(title: "感情", tags: entry.emotions, color: .blue)
            }
            if !entry.influences.isEmpty {
                tagGroup(title: "出来事", tags: entry.influences, color: .orange)
            }
            if !entry.lifeFactors.isEmpty {
                tagGroup(title: "生活習慣", tags: entry.lifeFactors, color: .green)
            }
            if !entry.activities.isEmpty {
                tagGroup(title: "今日したこと", tags: entry.activities, color: .purple)
            }
        }
        .diaryDetailCard()
    }

    private var notesAndReflectionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("書いたこと", systemImage: "note.text")

            if !entry.notes.isEmpty {
                textGroup(title: "メモ", text: entry.notes, systemImage: "note.text")
            }
            if !entry.gratitude.isEmpty {
                textGroup(title: "感謝していること", text: entry.gratitude, systemImage: "heart.fill")
            }
            if !entry.reflections.isEmpty {
                textGroup(title: "今日の振り返り", text: entry.reflections, systemImage: "arrow.clockwise")
            }
        }
        .diaryDetailCard()
    }

    private var emptyDetailsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.title2)
                .foregroundStyle(DiaryTheme.muted)

            VStack(alignment: .leading, spacing: 4) {
                Text("詳細情報はありません")
                    .font(.headline)
                Text("編集ボタンから、感情やメモを追加できます")
                    .font(.subheadline)
                    .foregroundStyle(DiaryTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .diaryDetailCard()
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.bold))
    }

    private func tagGroup(title: String, tags: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DiaryTheme.muted)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(color.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    private func textGroup(title: String, text: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
    }

    private var hasAnyTags: Bool {
        !entry.emotions.isEmpty ||
        !entry.influences.isEmpty ||
        !entry.lifeFactors.isEmpty ||
        !entry.activities.isEmpty
    }

    private var hasAnyTextContent: Bool {
        !entry.notes.isEmpty ||
        !entry.gratitude.isEmpty ||
        !entry.reflections.isEmpty
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private func deleteEntry() {
        context.delete(entry)

        do {
            try context.save()
            onDelete()
        } catch {
            context.rollback()
            deleteErrorMessage = error.localizedDescription
            showingDeleteError = true
        }
    }
}

private extension View {
    func diaryDetailCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) {
                Divider()
            }
    }
}
