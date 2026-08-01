import SwiftUI

/// 相談先を、診断結果やスコアから独立して確認できる共通画面。
struct SupportResourcesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                introductionSection

                ForEach(SupportUrgency.allCases, id: \.self) { urgency in
                    Section(urgency.sectionTitle) {
                        ForEach(SupportResourceCatalog.resources(for: urgency)) { resource in
                            SupportResourceRow(resource: resource)
                        }
                    }
                }

                sourceSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("相談先")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var introductionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("ひとりで決めなくて大丈夫です", systemImage: "person.2")
                    .font(.headline)
                    .foregroundStyle(DiaryTheme.ink)

                Text("話しやすい家族、先生、保健室、スクールカウンセラーなどに声をかける方法もあります。ここにある窓口を使うかどうかは、自分で選べます。")
                    .font(.subheadline)
                    .foregroundStyle(DiaryTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Text("このアプリは回答から状態を診断せず、自動通報・自動発信もしません。電話やWebサイトは、選んだときだけ開きます。")
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    private var sourceSection: some View {
        Section("情報について") {
            Text("窓口の受付時間や接続条件は変わることがあります。電話がつながらない場合は、公式一覧から別の方法を選んでください。")
                .font(.caption)
                .foregroundStyle(DiaryTheme.muted)

            Text("最終確認日: \(SupportResourceCatalog.lastVerified)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(DiaryTheme.muted)
        }
    }
}

struct SupportResourceRow: View {
    let resource: SupportResource

    var body: some View {
        Group {
            if let destination = resource.destinationURL {
                Link(destination: destination) {
                    rowContent
                }
            } else {
                rowContent
                    .foregroundStyle(DiaryTheme.muted)
                    .accessibilityHint("リンクを開けません")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(resource.contactKind == .phone ? "選ぶと電話画面を開きます" : "選ぶとWebサイトを開きます")
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: resource.contactKind.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(
                    resource.urgency == .immediate ? DiaryTheme.emergency : DiaryTheme.accent
                )
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 5) {
                Text(resource.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DiaryTheme.ink)

                Text(resource.summary)
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Text(resource.contactLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        resource.urgency == .immediate ? DiaryTheme.emergency : DiaryTheme.accent
                    )

                Text("\(resource.audience)・\(resource.availability)")
                    .font(.caption2)
                    .foregroundStyle(DiaryTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// 危機回答の直後に、画面を移動せず確認できる短い相談先一覧。
struct CompactSupportResourcesView: View {
    private let resources = Array(
        SupportResourceCatalog.resources(for: .immediate).prefix(2)
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(resources) { resource in
                SupportResourceRow(resource: resource)
            }

            if let directory = SupportResourceCatalog.resources
                .first(where: { $0.id == "mhlw-support-directory" }),
               let destination = directory.destinationURL {
                Link("ほかの相談方法を見る", destination: destination)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DiaryTheme.accent)
            }
        }
    }
}
