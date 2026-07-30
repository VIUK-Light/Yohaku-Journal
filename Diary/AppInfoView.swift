import SwiftUI

/// アプリの理念、保存方法、安全性、相談先を短く確認できる画面。
/// 機能をもう一度並べるのではなく、必要な説明だけを置く。
struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                overviewSection
                missionSection
                toolsSection
                safetySection
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

            SupportLink(
                title: "こころの健康相談統一ダイヤル",
                subtitle: "0570-064-556",
                description: "地域の公的な心の健康相談窓口につながります。"
            )

            SupportLink(
                title: "よりそいホットライン",
                subtitle: "0120-279-338",
                description: "さまざまな悩みを相談できる窓口です。"
            )
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

private struct SupportLink: View {
    let title: String
    let subtitle: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DiaryTheme.accent)

            Text(subtitle)
                .font(.headline.monospacedDigit())

            Text(description)
                .font(.caption)
                .foregroundStyle(DiaryTheme.muted)
        }
        .padding(.vertical, 3)
    }
}
