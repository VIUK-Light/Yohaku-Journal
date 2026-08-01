import Foundation
import SwiftData
import SwiftUI

/// 日記のルート画面。
///
/// 「記録」と「観察」を分け、編集状態は子画面に閉じ込める。
/// iPhoneではタブ、iPad/Macの広い画面ではサイドバーを使う。
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
    @State private var newRecordKind: RecordKind = .moment
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    @State private var showingArticles = false
    @State private var showingMentalHealthCheck = false
    @State private var showingSupportResources = false
    @State private var showingAppInfo = false
    @State private var entryPendingDeletion: MoodEntry?
    @State private var showingDeletionError = false
    @State private var deletionErrorMessage = ""

    private enum JournalWorkspace: Hashable {
        case record
        case observe
    }

    private enum JournalDestination: Hashable {
        case new(RecordKind)
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
    }

    private var compactShell: some View {
        journalChrome(
            NavigationStack(path: $compactPath) {
                TabView(selection: $compactWorkspace) {
                    JournalRecordView(
                        entries: moodEntries,
                        showsRecentEntries: true,
                        onCreate: { compactPath.append(.new($0)) },
                        onEdit: { compactPath.append(.edit($0.id)) },
                        onSelect: { compactPath.append(.detail($0.id)) },
                        onDelete: requestDeletion
                    )
                    .tabItem { Label("記録", systemImage: "square.and.pencil") }
                    .tag(JournalWorkspace.record)

                    JournalInsightsView(entries: moodEntries)
                        .tabItem { Label("観察", systemImage: "chart.xyaxis.line") }
                        .tag(JournalWorkspace.observe)
                }
                .navigationDestination(for: JournalDestination.self) { destination in
                    compactDestination(destination)
                }
            }
        )
    }

    private func splitShell(for size: CGSize) -> some View {
        journalChrome(
            NavigationSplitView(columnVisibility: $columnVisibility) {
                splitSidebar
            } detail: {
                regularDetail
            }
            .navigationSplitViewStyle(.balanced)
            .onAppear { updateSplitVisibility(for: size) }
            .onChange(of: size) { _, newSize in updateSplitVisibility(for: newSize) }
        )
    }

    private func journalChrome<Content: View>(_ content: Content) -> some View {
        content
            .toolbar {
                if showsRootToolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { showingAppInfo = true } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("アプリについて")
                    }

                    if horizontalSizeClass != .compact && columnVisibility == .detailOnly {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Menu {
                                Button { selectWorkspace(.record) } label: {
                                    Label("記録", systemImage: "square.and.pencil")
                                }
                                Button { selectWorkspace(.observe) } label: {
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
                            Button { startNewEntry(kind: .moment, returnTo: .observe) } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("新しい記録を作成")
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button { showingArticles = true } label: {
                                Label("心の健康記事", systemImage: "book")
                            }
                            Button { showingMentalHealthCheck = true } label: {
                                Label("セルフチェック", systemImage: "list.bullet.clipboard")
                            }

                            Button {
                                showingSupportResources = true
                            } label: {
                                Label("相談先", systemImage: "person.2")
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
            .sheet(isPresented: $showingSupportResources) {
                SupportResourcesView()
            }
            .sheet(isPresented: $showingAppInfo) {
                AppInfoView()
            }
            .confirmationDialog(
                "この記録を削除しますか？",
                isPresented: Binding(
                    get: { entryPendingDeletion != nil },
                    set: { if !$0 { entryPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) { deletePendingEntry() }
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
                Label("記録", systemImage: "square.and.pencil").tag(JournalSelection.record)
                Label("観察", systemImage: "chart.xyaxis.line").tag(JournalSelection.observe)
            }

            Section("最近の記録") {
                if moodEntries.isEmpty {
                    Text("まだ記録がありません")
                        .font(.subheadline)
                        .foregroundStyle(DiaryTheme.muted)
                } else {
                    ForEach(moodEntries.prefix(30)) { entry in
                        MoodEntryRow(entry: entry)
                            .tag(JournalSelection.entry(entry.id))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { requestDeletion(entry) } label: {
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
            case .record: regularRoute = .record
            case .observe: regularRoute = .observe
            case .entry(let id): regularRoute = .detail(id)
            }
        }
    }

    @ViewBuilder
    private var regularDetail: some View {
        switch regularRoute {
        case .record:
            JournalRecordView(
                entries: moodEntries,
                showsRecentEntries: columnVisibility == .detailOnly,
                onCreate: { startNewEntry(kind: $0, returnTo: .record) },
                onEdit: startEditing,
                onSelect: selectRegularEntry,
                onDelete: requestDeletion
            )
        case .observe:
            JournalInsightsView(entries: moodEntries)
        case .new:
            NewMoodEntryView(
                initialRecordKind: newRecordKind,
                onSave: finishRegularSave,
                onCancel: cancelRegularEditor,
                onDailyReflectionConflict: openRegularConflict
            )
        case .detail(let id):
            if let entry = entry(for: id) {
                MoodEntryDetailView(
                    entry: entry,
                    onEdit: { startEditing(entry) },
                    onDelete: { regularRoute = .record; splitSelection = .record }
                )
            } else {
                EmptyView()
            }
        case .edit(let id):
            if let entry = entry(for: id) {
                NewMoodEntryView(
                    entryToEdit: entry,
                    onSave: finishRegularSave,
                    onCancel: cancelRegularEditor,
                    onDailyReflectionConflict: openRegularConflict
                )
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func compactDestination(_ destination: JournalDestination) -> some View {
        switch destination {
        case .new(let kind):
            NewMoodEntryView(
                initialRecordKind: kind,
                onSave: finishCompactSave,
                onCancel: cancelCompactEditor,
                onDailyReflectionConflict: openCompactConflict
            )
        case .detail(let id):
            if let entry = entry(for: id) {
                MoodEntryDetailView(
                    entry: entry,
                    onEdit: { compactPath.append(.edit(id)) },
                    onDelete: removeLastCompactDestination
                )
            } else {
                EmptyView()
            }
        case .edit(let id):
            if let entry = entry(for: id) {
                NewMoodEntryView(
                    entryToEdit: entry,
                    onSave: finishCompactSave,
                    onCancel: cancelCompactEditor,
                    onDailyReflectionConflict: openCompactConflict
                )
            } else {
                EmptyView()
            }
        }
    }

    private var showsRootToolbar: Bool {
        if horizontalSizeClass == .compact { return compactPath.isEmpty }
        switch regularRoute {
        case .record, .observe: return true
        case .new, .detail, .edit: return false
        }
    }

    private var shouldShowNewEntryShortcut: Bool {
        if horizontalSizeClass == .compact { return compactWorkspace == .observe }
        if case .observe = regularRoute { return true }
        return false
    }

    private func entry(for id: UUID) -> MoodEntry? { moodEntries.first { $0.id == id } }

    private func selectWorkspace(_ workspace: JournalWorkspace) {
        switch workspace {
        case .record: regularRoute = .record; splitSelection = .record
        case .observe: regularRoute = .observe; splitSelection = .observe
        }
    }

    private func selectRegularEntry(_ entry: MoodEntry) {
        splitSelection = .entry(entry.id)
        regularRoute = .detail(entry.id)
    }

    private func startNewEntry(kind: RecordKind, returnTo route: RegularRoute?) {
        if horizontalSizeClass == .compact {
            compactPath.append(.new(kind))
        } else {
            newRecordKind = kind
            editorReturnRoute = route ?? .record
            regularRoute = .new
            splitSelection = nil
        }
    }

    private func startEditing(_ entry: MoodEntry) {
        if horizontalSizeClass == .compact {
            compactPath.append(.edit(entry.id))
        } else {
            editorReturnRoute = .detail(entry.id)
            regularRoute = .edit(entry.id)
            splitSelection = .entry(entry.id)
        }
    }

    private func finishCompactSave(_ entry: MoodEntry) {
        removeLastCompactDestination()
        compactPath.append(.detail(entry.id))
    }

    private func cancelCompactEditor() { removeLastCompactDestination() }

    private func removeLastCompactDestination() {
        guard !compactPath.isEmpty else { return }
        compactPath.removeLast()
    }

    private func finishRegularSave(_ entry: MoodEntry) {
        regularRoute = .detail(entry.id)
        splitSelection = .entry(entry.id)
    }

    private func openRegularConflict(_ id: UUID) {
        guard entry(for: id) != nil else { return }
        regularRoute = .detail(id)
        splitSelection = .entry(id)
    }

    private func openCompactConflict(_ id: UUID) {
        guard entry(for: id) != nil else { return }
        removeLastCompactDestination()
        compactPath.append(.detail(id))
    }

    private func cancelRegularEditor() {
        regularRoute = editorReturnRoute
        switch editorReturnRoute {
        case .detail(let id), .edit(let id): splitSelection = .entry(id)
        case .observe: splitSelection = .observe
        default: splitSelection = .record
        }
    }

    private func updateSplitVisibility(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        // Mac Catalystはウィンドウを横長の2カラムとして扱う。縦長の保存状態や
        // 一時的なGeometryReaderの値で、起動直後にdetailOnlyへ落ちないようにする。
        if DiaryRuntime.isMacWindow {
            columnVisibility = .all
            return
        }

        columnVisibility = size.width < size.height ? .detailOnly : .all
    }

    private func requestDeletion(_ entry: MoodEntry) { entryPendingDeletion = entry }

    private func deletePendingEntry() {
        guard let entry = entryPendingDeletion else { return }
        let deletedID = entry.id
        do {
            try MoodEntryDeletionService.delete(entry, in: modelContext)
            entryPendingDeletion = nil
            if case .detail(let id) = regularRoute, id == deletedID {
                regularRoute = .record
                splitSelection = .record
            }
        } catch {
            entryPendingDeletion = nil
            deletionErrorMessage = error.localizedDescription
            showingDeletionError = true
        }
    }
}
