import Charts
import Foundation
import SwiftData
import SwiftUI

/// 日記を「記録」と「観察」に分けて扱う作業画面。
///
/// iPhoneではタブ、iPad/Macではサイドバーを使うが、保存されるデータと操作の意味は共通にする。
struct MoodJournalView: View {
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)])
    private var moodEntries: [MoodEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var compactWorkspace: JournalWorkspace = .record
    @State private var compactPath: [JournalDestination] = []
    @State private var splitSelection: JournalSelection? = .record
    @State private var regularRoute: RegularRoute = .record
    @State private var editorReturnRoute: RegularRoute = .record
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    @State private var showingArticles = false
    @State private var showingMentalHealthCheck = false
    @State private var showingAppInfo = false
    @State private var entryPendingDeletion: MoodEntry?
    @State private var showingDeletionError = false
    @State private var deletionErrorMessage = ""

    private enum JournalWorkspace: Hashable {
        case record
        case observe
    }

    private enum JournalDestination: Hashable {
        case new
        case detail(UUID)
        case edit(UUID)
    }

    private enum JournalSelection: Hashable {
        case record
        case observe
        case entry(UUID)
    }

    private enum RegularRoute {
        case record
        case observe
        case new
        case detail(UUID)
        case edit(UUID)
    }

    var body: some View {
        ZStack {
            DiaryTheme.canvas
                .ignoresSafeArea()

            GeometryReader { geometry in
                Group {
                    if horizontalSizeClass == .compact {
                        compactShell
                    } else {
                        splitShell(for: geometry.size)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(
            minWidth: DiaryRuntime.isMacWindow ? 1024 : 0,
            minHeight: DiaryRuntime.isMacWindow ? 700 : 0
        )
    }

    private var compactShell: some View {
        journalChrome(
            NavigationStack(path: $compactPath) {
                TabView(selection: $compactWorkspace) {
                    JournalRecordView(
                        entries: moodEntries,
                        showsRecentEntries: true,
                        onNew: { compactPath.append(.new) },
                        onEditToday: { compactPath.append(.edit($0.id)) },
                        onSelect: { compactPath.append(.detail($0.id)) },
                        onDelete: requestDeletion
                    )
                    .tabItem {
                        Label("記録", systemImage: "square.and.pencil")
                    }
                    .tag(JournalWorkspace.record)

                    JournalInsightsView(entries: moodEntries)
                        .tabItem {
                            Label("観察", systemImage: "chart.xyaxis.line")
                        }
                        .tag(JournalWorkspace.observe)
                }
                .navigationDestination(for: JournalDestination.self) { destination in
                    compactDestination(destination)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func splitShell(for size: CGSize) -> some View {
        journalChrome(
            NavigationSplitView(columnVisibility: $columnVisibility) {
                splitSidebar
            } detail: {
                regularDetail
            }
            .navigationSplitViewStyle(.automatic)
            .onAppear {
                updateSplitVisibility(for: size)
            }
            .onChange(of: size) { _, newSize in
                updateSplitVisibility(for: newSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func journalChrome<Content: View>(_ content: Content) -> some View {
        content
            .toolbar {
                if showsRootToolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showingAppInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("アプリについて")
                    }

                    if horizontalSizeClass != .compact && columnVisibility == .detailOnly {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Menu {
                                Button {
                                    selectWorkspace(.record)
                                } label: {
                                    Label("記録", systemImage: "square.and.pencil")
                                }

                                Button {
                                    selectWorkspace(.observe)
                                } label: {
                                    Label("観察", systemImage: "chart.xyaxis.line")
                                }
                            } label: {
                                Image(systemName: "square.grid.2x2")
                            }
                            .accessibilityLabel("表示を切り替える")
                        }
                    }

                    if shouldShowNewEntryShortcut {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                startNewEntry(returnTo: horizontalSizeClass == .compact ? nil : .observe)
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("新しい記録を作成")
                        }
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
    }

    private var splitSidebar: some View {
        List(selection: $splitSelection) {
            Section("ワークスペース") {
                Label("記録", systemImage: "square.and.pencil")
                    .tag(JournalSelection.record)

                Label("観察", systemImage: "chart.xyaxis.line")
                    .tag(JournalSelection.observe)
            }

            Section("最近の記録") {
                if moodEntries.isEmpty {
                    Text("まだ記録がありません")
                        .font(.subheadline)
                        .foregroundStyle(DiaryTheme.muted)
                } else {
                    ForEach(moodEntries) { entry in
                        MoodEntryRow(entry: entry)
                            .tag(JournalSelection.entry(entry.id))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    requestDeletion(entry)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        .onChange(of: splitSelection) { _, selection in
            guard let selection else { return }

            switch selection {
            case .record:
                regularRoute = .record
            case .observe:
                regularRoute = .observe
            case .entry(let id):
                regularRoute = .detail(id)
            }
        }
    }

    @ViewBuilder
    private var regularDetail: some View {
        switch regularRoute {
        case .record:
            recordWorkspace(showsRecentEntries: columnVisibility == .detailOnly)
        case .observe:
            JournalInsightsView(entries: moodEntries)
        case .new:
            NewMoodEntryView(
                onSave: finishRegularSave,
                onCancel: cancelRegularEditor
            )
        case .detail(let id):
            if let entry = entry(for: id) {
                MoodEntryDetailView(
                    entry: entry,
                    onEdit: { startEditing(entry) },
                    onDelete: {
                        regularRoute = .record
                        splitSelection = .record
                    }
                )
            } else {
                recordWorkspace(showsRecentEntries: columnVisibility == .detailOnly)
            }
        case .edit(let id):
            if let entry = entry(for: id) {
                NewMoodEntryView(
                    entryToEdit: entry,
                    onSave: finishRegularSave,
                    onCancel: cancelRegularEditor
                )
            } else {
                recordWorkspace(showsRecentEntries: columnVisibility == .detailOnly)
            }
        }
    }

    @ViewBuilder
    private func compactDestination(_ destination: JournalDestination) -> some View {
        switch destination {
        case .new:
            NewMoodEntryView(
                onSave: finishCompactSave,
                onCancel: cancelCompactEditor
            )
        case .detail(let id):
            if let entry = entry(for: id) {
                MoodEntryDetailView(
                    entry: entry,
                    onEdit: { compactPath.append(.edit(id)) },
                    onDelete: { removeLastCompactDestination() }
                )
            } else {
                JournalRecordView(
                    entries: moodEntries,
                    showsRecentEntries: true,
                    onNew: { compactPath.append(.new) },
                    onEditToday: { compactPath.append(.edit($0.id)) },
                    onSelect: { compactPath.append(.detail($0.id)) },
                    onDelete: requestDeletion
                )
            }
        case .edit(let id):
            if let entry = entry(for: id) {
                NewMoodEntryView(
                    entryToEdit: entry,
                    onSave: finishCompactSave,
                    onCancel: cancelCompactEditor
                )
            } else {
                JournalRecordView(
                    entries: moodEntries,
                    showsRecentEntries: true,
                    onNew: { compactPath.append(.new) },
                    onEditToday: { compactPath.append(.edit($0.id)) },
                    onSelect: { compactPath.append(.detail($0.id)) },
                    onDelete: requestDeletion
                )
            }
        }
    }

    private func recordWorkspace(showsRecentEntries: Bool) -> some View {
        JournalRecordView(
            entries: moodEntries,
            showsRecentEntries: showsRecentEntries,
            onNew: { startNewEntry(returnTo: .record) },
            onEditToday: { startEditing($0) },
            onSelect: { selectRegularEntry($0) },
            onDelete: requestDeletion
        )
    }

    private var showsRootToolbar: Bool {
        if horizontalSizeClass == .compact {
            return compactPath.isEmpty
        }

        switch regularRoute {
        case .record, .observe:
            return true
        case .new, .detail, .edit:
            return false
        }
    }

    private var shouldShowNewEntryShortcut: Bool {
        if horizontalSizeClass == .compact {
            return compactWorkspace == .observe
        }

        if case .observe = regularRoute {
            return true
        }
        return false
    }

    private func entry(for id: UUID) -> MoodEntry? {
        moodEntries.first { $0.id == id }
    }

    private func selectWorkspace(_ workspace: JournalWorkspace) {
        switch workspace {
        case .record:
            regularRoute = .record
            splitSelection = .record
        case .observe:
            regularRoute = .observe
            splitSelection = .observe
        }
    }

    private func selectRegularEntry(_ entry: MoodEntry) {
        splitSelection = .entry(entry.id)
        regularRoute = .detail(entry.id)
    }

    private func startNewEntry(returnTo route: RegularRoute?) {
        if horizontalSizeClass == .compact {
            compactPath.append(.new)
            return
        }

        editorReturnRoute = route ?? .record
        regularRoute = .new
        splitSelection = nil
    }

    private func startEditing(_ entry: MoodEntry) {
        if horizontalSizeClass == .compact {
            compactPath.append(.edit(entry.id))
            return
        }

        editorReturnRoute = .detail(entry.id)
        regularRoute = .edit(entry.id)
        splitSelection = .entry(entry.id)
    }

    private func finishCompactSave(_ entry: MoodEntry) {
        removeLastCompactDestination()

        if compactPath.last != .detail(entry.id) {
            compactPath.append(.detail(entry.id))
        }
    }

    private func cancelCompactEditor() {
        removeLastCompactDestination()
    }

    private func removeLastCompactDestination() {
        guard !compactPath.isEmpty else { return }
        compactPath.removeLast()
    }

    private func finishRegularSave(_ entry: MoodEntry) {
        regularRoute = .detail(entry.id)
        splitSelection = .entry(entry.id)
    }

    private func cancelRegularEditor() {
        regularRoute = editorReturnRoute

        switch editorReturnRoute {
        case .detail(let id), .edit(let id):
            splitSelection = .entry(id)
        case .observe:
            splitSelection = .observe
        default:
            splitSelection = .record
        }
    }

    private func updateSplitVisibility(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        columnVisibility = size.width < size.height ? .detailOnly : .all
    }

    private func requestDeletion(_ entry: MoodEntry) {
        entryPendingDeletion = entry
    }

    private func deletePendingEntry() {
        guard let entry = entryPendingDeletion else { return }
        let deletedID = entry.id

        modelContext.delete(entry)
        do {
            try modelContext.save()

            if case .detail(let id) = regularRoute, id == deletedID {
                regularRoute = .record
                splitSelection = .record
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

// MARK: - Record workspace

struct JournalRecordView: View {
    let entries: [MoodEntry]
    let showsRecentEntries: Bool
    let onNew: () -> Void
    let onEditToday: (MoodEntry) -> Void
    let onSelect: (MoodEntry) -> Void
    let onDelete: (MoodEntry) -> Void

    private var todayEntry: MoodEntry? {
        let calendar = Calendar.current
        return entries.first { calendar.isDate($0.date, inSameDayAs: Date()) }
    }

    var body: some View {
        List {
            Section {
                todayPanel
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(DiaryTheme.canvas)
            }

            if showsRecentEntries {
                Section("最近の記録") {
                    if entries.isEmpty {
                        Text("まだ記録がありません")
                            .font(.subheadline)
                            .foregroundStyle(DiaryTheme.muted)
                            .listRowBackground(DiaryTheme.canvas)
                    } else {
                        ForEach(entries) { entry in
                            Button {
                                onSelect(entry)
                            } label: {
                                MoodEntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(DiaryTheme.surface)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Label("削除", systemImage: "trash")
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
        .navigationTitle("記録")
        .navigationBarTitleDisplayMode(.large)
    }

    private var todayPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(DiaryTheme.ink)
                    Text(todayEntry == nil ? "まだ記録していません" : "今日の記録があります")
                        .font(.subheadline)
                        .foregroundStyle(DiaryTheme.muted)
                }

                Spacer()

                DiaryLineIcon(
                    kind: .mood(todayEntry?.moodScore ?? 4),
                    color: todayEntry.map { DiaryTheme.moodColor(for: $0.moodScore) } ?? DiaryTheme.muted,
                    size: 48
                )
            }

            if let todayEntry {
                HStack(spacing: 10) {
                    Text(todayEntry.mood)
                        .font(.headline)
                        .foregroundStyle(DiaryTheme.moodColor(for: todayEntry.moodScore))
                    Text("・")
                        .foregroundStyle(DiaryTheme.muted)
                    Text("今日の記録")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DiaryTheme.muted)
                }
            }

            Button {
                if let todayEntry {
                    onEditToday(todayEntry)
                } else {
                    onNew()
                }
            } label: {
                Label(
                    todayEntry == nil ? "今の気分を記録" : "今日の記録を編集",
                    systemImage: todayEntry == nil ? "plus" : "pencil"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .controlSize(.large)
            .tint(DiaryTheme.primary)

            Text("必要なときに、必要なだけ使えます。")
                .font(.caption)
                .foregroundStyle(DiaryTheme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: 680, alignment: .leading)
        .padding(.vertical, 8)
    }
}

// MARK: - Observation workspace

enum JournalInsightRange: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "7日"
        case .month: return "30日"
        case .quarter: return "90日"
        case .all: return "すべて"
        }
    }

    var dayCount: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .all: return nil
        }
    }
}

struct MoodTrendPoint: Identifiable {
    let date: Date
    let averageScore: Double
    let entryCount: Int

    var id: Date { date }
}

struct EventBreakdown: Identifiable {
    let name: String
    let entryCount: Int
    let averageMood: Double

    var id: String { name }
}

struct JournalInsights {
    let totalEntries: Int
    let averageMood: Double?
    let moodTrend: [MoodTrendPoint]
    let eventBreakdowns: [EventBreakdown]
}

private struct MoodDayAggregate {
    var totalScore = 0
    var count = 0

    mutating func add(score: Int) {
        totalScore += score
        count += 1
    }
}

private struct EventAggregate {
    var totalScore = 0
    var count = 0

    mutating func add(score: Int) {
        totalScore += score
        count += 1
    }
}

/// 記録を一度だけ走査し、グラフに必要な小さな値だけを返す。
struct JournalInsightsCalculator {
    static func make(
        entries: [MoodEntry],
        range: JournalInsightRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> JournalInsights {
        let today = calendar.startOfDay(for: now)
        let endDate = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let startDate: Date

        if let dayCount = range.dayCount {
            startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        } else {
            startDate = entries.map { calendar.startOfDay(for: $0.date) }.min() ?? today
        }

        var totalEntries = 0
        var totalMoodScore = 0
        var moodByDay: [Date: MoodDayAggregate] = [:]
        var events: [String: EventAggregate] = [:]

        for entry in entries where entry.date >= startDate && entry.date < endDate {
            totalEntries += 1
            totalMoodScore += entry.moodScore

            let day = calendar.startOfDay(for: entry.date)
            moodByDay[day, default: MoodDayAggregate()].add(score: entry.moodScore)

            for event in Set(entry.influences) where !event.isEmpty {
                events[event, default: EventAggregate()].add(score: entry.moodScore)
            }
        }

        let trend = moodByDay.keys.sorted().compactMap { day -> MoodTrendPoint? in
            guard let aggregate = moodByDay[day], aggregate.count > 0 else { return nil }
            return MoodTrendPoint(
                date: day,
                averageScore: Double(aggregate.totalScore) / Double(aggregate.count),
                entryCount: aggregate.count
            )
        }

        let eventBreakdowns = events.map { name, aggregate in
            EventBreakdown(
                name: name,
                entryCount: aggregate.count,
                averageMood: Double(aggregate.totalScore) / Double(aggregate.count)
            )
        }
        .sorted {
            if $0.entryCount == $1.entryCount {
                return $0.name < $1.name
            }
            return $0.entryCount > $1.entryCount
        }

        return JournalInsights(
            totalEntries: totalEntries,
            averageMood: totalEntries == 0 ? nil : Double(totalMoodScore) / Double(totalEntries),
            moodTrend: trend,
            eventBreakdowns: eventBreakdowns
        )
    }
}

struct JournalInsightsView: View {
    let entries: [MoodEntry]

    @State private var selectedRange: JournalInsightRange = .month
    @State private var insights = JournalInsights(
        totalEntries: 0,
        averageMood: nil,
        moodTrend: [],
        eventBreakdowns: []
    )

    private var dataRevision: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)

        for entry in entries {
            hasher.combine(entry.id)
            hasher.combine(entry.date)
            hasher.combine(entry.moodScore)
            for event in entry.influences {
                hasher.combine(event)
            }
        }

        return hasher.finalize()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                rangePicker

                if insights.totalEntries == 0 {
                    emptyRangeView
                } else {
                    summarySection
                    moodTrendSection
                    eventBreakdownSection
                    safetyNote
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .background(DiaryTheme.canvas)
        .navigationTitle("観察")
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: refreshInsights)
        .onChange(of: selectedRange) { _, _ in
            refreshInsights()
        }
        .onChange(of: dataRevision) { _, _ in
            refreshInsights()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自分の記録を観察する")
                .font(.title2.weight(.bold))
                .foregroundStyle(DiaryTheme.ink)

            Text("気分と出来事の記録を並べて、自分で変化を眺められます。ここに表示されるのは、保存した記録から分かる事実だけです。")
                .font(.subheadline)
                .foregroundStyle(DiaryTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rangePicker: some View {
        Picker("観察期間", selection: $selectedRange) {
            ForEach(JournalInsightRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("観察期間")
    }

    private var summarySection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            insightMetric(title: "記録数", value: "\(insights.totalEntries)件", caption: "この期間")
            insightMetric(title: "平均気分", value: insights.averageMood.map(formatAverage) ?? "—", caption: "1〜7の記録")
            insightMetric(title: "出来事タグ", value: "\(insights.eventBreakdowns.count)種類", caption: "記録された分類")
        }
    }

    private func insightMetric(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DiaryTheme.muted)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(DiaryTheme.ink)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(DiaryTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DiaryTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DiaryTheme.line, lineWidth: 1)
        }
    }

    private var moodTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("気分の推移", detail: "日ごとの平均スコア")

            if insights.moodTrend.isEmpty {
                emptyChartMessage("この期間には日ごとの気分データがありません。")
            } else {
                Chart(insights.moodTrend) { point in
                    AreaMark(
                        x: .value("日付", point.date),
                        y: .value("気分", point.averageScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DiaryTheme.accent.opacity(0.24), DiaryTheme.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("日付", point.date),
                        y: .value("気分", point.averageScore)
                    )
                    .foregroundStyle(DiaryTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("日付", point.date),
                        y: .value("気分", point.averageScore)
                    )
                    .foregroundStyle(DiaryTheme.accent)
                }
                .chartYScale(domain: 1...7)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [1, 4, 7]) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(dash: [3, 3]))
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(DiaryTheme.accentSoft.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(height: 230)
                .padding(16)
                .background(DiaryTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DiaryTheme.line, lineWidth: 1)
                }
            }
        }
    }

    private var eventBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("出来事ごとの記録", detail: "タグが付いた記録の件数と平均")

            if insights.eventBreakdowns.isEmpty {
                emptyChartMessage("出来事タグが付いた記録はありません。記録画面でタグを追加すると、ここで比べられます。")
            } else {
                let visibleBreakdowns = Array(insights.eventBreakdowns.prefix(8))

                Chart(visibleBreakdowns) { breakdown in
                    BarMark(
                        x: .value("記録数", breakdown.entryCount),
                        y: .value("出来事", breakdown.name)
                    )
                    .foregroundStyle(DiaryTheme.accent)
                    .annotation(position: .trailing, alignment: .center) {
                        Text("\(breakdown.entryCount)件・平均\(formatAverage(breakdown.averageMood))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DiaryTheme.muted)
                    }
                }
                .chartXScale(domain: 0...max(1, (visibleBreakdowns.map(\.entryCount).max() ?? 1) + 1))
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisGridLine(stroke: StrokeStyle(dash: [3, 3]))
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: CGFloat(max(190, visibleBreakdowns.count * 42)))
                .padding(16)
                .background(DiaryTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DiaryTheme.line, lineWidth: 1)
                }

                if insights.eventBreakdowns.count > visibleBreakdowns.count {
                    Text("表示は記録数の多い上位8種類です。")
                        .font(.caption)
                        .foregroundStyle(DiaryTheme.muted)
                }
            }
        }
    }

    private var emptyRangeView: some View {
        VStack(alignment: .leading, spacing: 8) {
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

    private func emptyChartMessage(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(DiaryTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(DiaryTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var safetyNote: some View {
        Text("この画面は、保存された記録を整理して眺めるためのものです。心理状態の診断や評価ではありません。")
            .font(.caption)
            .foregroundStyle(DiaryTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(DiaryTheme.ink)
            Text(detail)
                .font(.caption)
                .foregroundStyle(DiaryTheme.muted)
        }
    }

    private func refreshInsights() {
        insights = JournalInsightsCalculator.make(entries: entries, range: selectedRange)
    }

    private func formatAverage(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

// MARK: - Shared timeline row

struct MoodEntryRow: View {
    let entry: MoodEntry

    var body: some View {
        HStack(spacing: 12) {
            DiaryLineIcon(
                kind: .mood(entry.moodScore),
                color: DiaryTheme.moodColor(for: entry.moodScore),
                size: 30
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mood)
                    .font(.headline)
                    .foregroundStyle(DiaryTheme.ink)
                Text(entry.recordType)
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)

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

            VStack(alignment: .trailing, spacing: 4) {
                Text(japaneseDateTimeString(from: entry.date))
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private func japaneseDateTimeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
