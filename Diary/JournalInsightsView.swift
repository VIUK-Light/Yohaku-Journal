import Charts
import SwiftUI

/// 保存した記録を評価や診断に変換せず、観察できる値として表示する。
struct JournalInsightsView: View {
    let entries: [MoodEntry]

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedRange: JournalInsightRange = .month
    @State private var snapshot = JournalInsightsSnapshot(
        totalEntries: 0,
        averageMood: nil,
        eventTagTypeCount: 0,
        moodTrend: [],
        eventBreakdowns: [],
        omittedEventTagCount: 0
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                rangePicker

                if snapshot.totalEntries == 0 {
                    emptyState
                } else if horizontalSizeClass == .compact {
                    metrics
                    moodTrend
                    eventBreakdown
                } else {
                    metrics
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                        moodTrend
                        eventBreakdown
                    }
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(DiaryTheme.canvas)
        .navigationTitle("観察")
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: refresh)
        .onChange(of: selectedRange) { _, _ in refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("記録を静かに眺める")
                .font(.title2.weight(.bold))
                .foregroundStyle(DiaryTheme.ink)
            Text("ここに表示されるのは、保存した記録の集計です。心理状態の診断や評価ではありません。")
                .font(.subheadline)
                .foregroundStyle(DiaryTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rangePicker: some View {
        Picker("表示期間", selection: $selectedRange) {
            ForEach(JournalInsightRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("観察する期間")
    }

    private var metrics: some View {
        Group {
            if horizontalSizeClass == .compact {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metric(title: "記録数", value: "\(snapshot.totalEntries)件", detail: "この期間")
                    metric(title: "平均気分", value: formatted(snapshot.averageMood), detail: "1〜7の記録")
                    metric(title: "出来事タグ", value: "\(snapshot.eventTagTypeCount)種類", detail: "記録された分類")
                }
            } else {
                HStack(spacing: 12) {
                    metric(title: "記録数", value: "\(snapshot.totalEntries)件", detail: "この期間")
                    metric(title: "平均気分", value: formatted(snapshot.averageMood), detail: "1〜7の記録")
                    metric(title: "出来事タグ", value: "\(snapshot.eventTagTypeCount)種類", detail: "記録された分類")
                }
            }
        }
    }

    private func metric(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(DiaryTheme.muted)
            Text(value).font(.title2.weight(.bold)).foregroundStyle(DiaryTheme.ink)
            Text(detail).font(.caption2).foregroundStyle(DiaryTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(DiaryTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DiaryTheme.line) }
        .accessibilityElement(children: .combine)
    }

    private var moodTrend: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("日ごとの記録", detail: "日単位の平均スコア")

            if snapshot.moodTrend.isEmpty {
                emptyChart("この期間には日ごとのデータがありません。")
            } else {
                Chart(snapshot.moodTrend) { point in
                    LineMark(
                        x: .value("日付", point.date),
                        y: .value("気分", point.averageScore)
                    )
                    .foregroundStyle(DiaryTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    PointMark(
                        x: .value("日付", point.date),
                        y: .value("気分", point.averageScore)
                    )
                    .foregroundStyle(DiaryTheme.accent)
                }
                .chartYScale(domain: 1...7)
                .chartYAxis { AxisMarks(position: .leading, values: [1, 4, 7]) }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
                .frame(height: 220)
                .padding(14)
                .background(DiaryTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DiaryTheme.line) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(moodTrendSummary)
            }
        }
    }

    private var eventBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("出来事ごとの記録", detail: "件数。平均は3件以上のタグだけ表示")

            if snapshot.eventBreakdowns.isEmpty {
                emptyChart("出来事タグの記録はありません。")
            } else {
                VStack(spacing: 0) {
                    ForEach(snapshot.eventBreakdowns) { item in
                        HStack(spacing: 10) {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(item.entryCount)件")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(DiaryTheme.muted)
                            if let averageMood = item.averageMood {
                                Text("平均 \(formatted(averageMood))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(DiaryTheme.muted)
                            }
                        }
                        .padding(.vertical, 10)
                        if item.id != snapshot.eventBreakdowns.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 14)
                .background(DiaryTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DiaryTheme.line) }
                .accessibilityElement(children: .contain)
            }

            if snapshot.omittedEventTagCount > 0 {
                Text("表示は記録数の多い上位8種類です。")
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            DiaryLineIcon(kind: .journal, color: DiaryTheme.muted, size: 38)
            Text("この期間の記録はありません")
                .font(.headline)
                .foregroundStyle(DiaryTheme.ink)
            Text("期間を広げるか、必要なときに記録を追加してください。")
                .font(.subheadline)
                .foregroundStyle(DiaryTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(DiaryTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline.weight(.bold)).foregroundStyle(DiaryTheme.ink)
            Text(detail).font(.caption).foregroundStyle(DiaryTheme.muted)
        }
    }

    private func emptyChart(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(DiaryTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(DiaryTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var moodTrendSummary: String {
        let days = snapshot.moodTrend.count
        return "\(days)日分の記録。日ごとの平均気分を表示しています。"
    }

    private func formatted(_ value: Double?) -> String { value.map { String(format: "%.1f", $0) } ?? "—" }

    private func refresh() {
        snapshot = JournalInsightsCalculator.make(entries: entries, range: selectedRange)
    }
}
