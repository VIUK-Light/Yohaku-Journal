import SwiftUI
import SwiftData

/// アプリの理念、保存方法、安全性、相談先を短く確認できる画面。
/// 機能をもう一度並べるのではなく、必要な説明だけを置く。
struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\LightSafetyCheckRecord.date, order: .reverse)])
    private var safetyRecords: [LightSafetyCheckRecord]
    @State private var showingSafetyRecordDeletion = false
    @State private var showingSafetyRecordError = false

    var body: some View {
        NavigationStack {
            List {
                overviewSection
                missionSection
                toolsSection
                safetySection
                safetyRecordSection
                supportSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("アプリについて")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var overviewSection: some View {
        Section {
            VStack(spacing: 14) {
                DiaryLineIcon(kind: .journal, color: DiaryTheme.accent, size: 52)

                Text("心の記録")
                    .font(.title2.weight(.bold))

                Text("心の状態を記録したい人を、静かに支えるための日記アプリです。")
                    .font(.body)
                    .foregroundStyle(DiaryTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
        .listRowSeparator(.hidden)
    }

    private var missionSection: some View {
        Section("VIUK Lightの考え方") {
            Text("このアプリは、心の状態を記録したい人を静かに支えるための無料ツールです。広告や利用時間を増やすための仕組みではなく、必要なときに必要なだけ使えることを大切にしています。")
                .font(.body)
                .foregroundStyle(DiaryTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                MissionPoint(text: "広告・課金誘導・ランキング・連続記録の強制はありません。")
                MissionPoint(text: "利用者を責めたり、使い続けることを求めたりしません。")
                MissionPoint(text: "困りごとが続くときは、専門家や相談窓口につながることを勧めます。")
            }
            .padding(.vertical, 4)
        }
    }

    private var toolsSection: some View {
        Section("必要なときに使えるもの") {
            InfoRow(
                icon: "book",
                title: "心の健康記事",
                detail: "日記画面のツールメニューから、必要な記事だけ読めます。"
            )

            InfoRow(
                icon: "list.bullet.clipboard",
                title: "セルフチェック",
                detail: "結果を決めつけず、自分の状態を振り返るための参考として使えます。"
            )
        }
    }

    private var safetySection: some View {
        Section("保存と安全性") {
            InfoRow(
                icon: "iphone",
                title: "端末内保存",
                detail: "日記の記録は端末内に保存されます。"
            )

            InfoRow(
                icon: "hand.raised",
                title: "広告目的で利用しません",
                detail: "記録内容を広告や利用時間の最大化のために使いません。"
            )

            InfoRow(
                icon: "cross.case",
                title: "医療的な診断ではありません",
                detail: "セルフチェックの結果は、医療機関による診断や治療の代わりにはなりません。"
            )
        }
    }

    private var supportSection: some View {
        Section("相談先") {
            Text("苦しさや不安が続く場合は、ひとりで抱えず、医療機関・学校や地域の相談窓口などの専門家へ相談してください。緊急の場合は119番、または最寄りの救急外来を利用してください。")
                .font(.body)
                .foregroundStyle(DiaryTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(["public-mental-health", "anata-no-ibasho", "mhlw-support-directory"], id: \.self) { resourceID in
                if let resource = SupportResourceCatalog.resources.first(where: { $0.id == resourceID }) {
                    SupportResourceRow(resource: resource)
                }
            }

            Text("受付時間や接続条件は変わることがあります。最終確認日と公式出典は相談先画面で確認できます。")
                .font(.caption)
                .foregroundStyle(DiaryTheme.muted)
        }
    }

    private var safetyRecordSection: some View {
        Section("安全確認の記録") {
            if safetyRecords.isEmpty {
                Text("安全確認の記録はありません。")
                    .foregroundStyle(DiaryTheme.muted)
            } else {
                Text("保存した場合も、確認を行った日時だけが端末に残ります。回答内容や日記本文は含まれません。")
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)

                ForEach(safetyRecords) { record in
                    HStack {
                        Label("安全確認を実施", systemImage: "checkmark.shield")
                        Spacer()
                        Text(record.date, format: .dateTime.year().month().day())
                            .font(.caption)
                            .foregroundStyle(DiaryTheme.muted)
                    }
                    .swipeActions {
                        Button("削除", role: .destructive) {
                            deleteSafetyRecord(record)
                        }
                    }
                }

                Button("安全確認の記録をすべて削除", role: .destructive) {
                    showingSafetyRecordDeletion = true
                }
            }
        }
        .confirmationDialog(
            "安全確認の記録を削除しますか？",
            isPresented: $showingSafetyRecordDeletion,
            titleVisibility: .visible
        ) {
            Button("すべて削除", role: .destructive) {
                deleteAllSafetyRecords()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除するのは確認日時だけです。日記や既存のセルフチェック記録には影響しません。")
        }
        .alert("削除できませんでした", isPresented: $showingSafetyRecordError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("安全確認の記録は変更されていません。")
        }
    }

    private func deleteSafetyRecord(_ record: LightSafetyCheckRecord) {
        modelContext.delete(record)
        saveSafetyRecordChanges()
    }

    private func deleteAllSafetyRecords() {
        for record in safetyRecords {
            modelContext.delete(record)
        }
        saveSafetyRecordChanges()
    }

    private func saveSafetyRecordChanges() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            showingSafetyRecordError = true
        }
    }
}

private struct MissionPoint: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(DiaryTheme.ink)
        } icon: {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(DiaryTheme.accent)
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(DiaryTheme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
    }
}
