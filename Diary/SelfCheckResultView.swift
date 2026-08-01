import SwiftUI

/// 独自の振り返り結果を、点数や色による評価なしで表示する。
struct SelfCheckObservationCard: View {
    let result: SelfCheckResult
    let guidance: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.type.displayName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DiaryTheme.ink)
                Spacer()
                Text("回答 \(result.answeredCount)/\(result.totalQuestionCount)件")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DiaryTheme.muted)
            }

            ForEach(result.responseCounts) { response in
                HStack(spacing: 10) {
                    Text(response.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(response.count)件")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DiaryTheme.muted)
                }
                .font(.subheadline)
            }

            Divider()

            Text(guidance)
                .font(.caption)
                .foregroundStyle(DiaryTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .diarySurface(padding: 16, radius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        "\(result.type.displayName)。回答\(result.answeredCount)件、未回答\(result.unansweredCount)件。" +
        result.responseCounts.map { "\($0.label)\($0.count)件" }.joined(separator: "、")
    }
}
