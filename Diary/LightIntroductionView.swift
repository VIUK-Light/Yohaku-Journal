import SwiftUI

/// 初回起動時にだけ表示する、短くスキップ可能な説明。
struct LightIntroductionView: View {
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    principles

                    Button("使い始める", action: onFinish)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .controlSize(.large)
                        .tint(DiaryTheme.primary)

                    Text("あとから「アプリについて」で、保存方法や相談先を確認できます。")
                        .font(.caption)
                        .foregroundStyle(DiaryTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 36)
            }
            .background(DiaryTheme.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("スキップ", action: onFinish)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            DiaryLineIcon(kind: .journal, color: DiaryTheme.primary, size: 58)

            Text("必要なときに、必要なだけ")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(DiaryTheme.ink)

            Text("心の状態を記録したい人を、静かに支えるための無料ツールです。")
                .font(.title3)
                .foregroundStyle(DiaryTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var principles: some View {
        VStack(alignment: .leading, spacing: 18) {
            IntroductionPoint(
                icon: "heart.slash",
                title: "無料・広告なし",
                detail: "課金誘導、ランキング、連続記録の強制はありません。"
            )
            IntroductionPoint(
                icon: "iphone",
                title: "端末内保存が基本",
                detail: "記録内容を広告目的に利用しません。"
            )
            IntroductionPoint(
                icon: "cross.case",
                title: "医療的な診断ではありません",
                detail: "セルフチェックや観察は、自分の記録を振り返るためのものです。"
            )
            IntroductionPoint(
                icon: "hand.raised",
                title: "いつでもやめられます",
                detail: "記録しない日があっても責めず、使い続けることを求めません。"
            )
            IntroductionPoint(
                icon: "person.2",
                title: "相談先を選べます",
                detail: "苦しさがあるときは、家族・先生・専門家・公的な相談窓口につながれます。"
            )
        }
    }
}

private struct IntroductionPoint: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DiaryTheme.accent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(DiaryTheme.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(DiaryTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
