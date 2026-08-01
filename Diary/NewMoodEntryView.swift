import SwiftUI
import SwiftData

/// 新しい日記を作成する画面。
///
/// 最初に必要なのは「今の気分」だけなので、詳細項目は折りたたんでいる。
/// 既存のMoodEntryの保存項目は維持し、入力の順番と見せ方だけを整理している。
struct NewMoodEntryView: View {
    @Environment(\.modelContext) private var context

    @State private var selectedMoodScore = 4
    @State private var selectedRecordType = "今現在の気分"
    @State private var selectedEmotions: Set<String> = []
    @State private var notes = ""
    @State private var activities: Set<String> = []
    @State private var gratitude = ""
    @State private var reflections = ""
    @State private var selectedInfluences: Set<String> = []
    @State private var selectedLifeFactors: Set<String> = []

    @State private var isShowingDetails = false
    @State private var expandedDetails: Set<DetailSection> = []
    @State private var showingDiscardConfirmation = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""
    @State private var showingAdditionalEvents = false
    @State private var customEventTag = ""
    @State private var isSaving = false
    @State private var dailyReflectionConflictID: UUID?
    @FocusState private var focusedField: InputField?

    private let entryToEdit: MoodEntry?
    private let initialRecordType: String
    let onSave: (MoodEntry) -> Void
    let onCancel: () -> Void
    let onDailyReflectionConflict: (UUID) -> Void

    init(
        initialRecordKind: RecordKind = .moment,
        entryToEdit: MoodEntry? = nil,
        onSave: @escaping (MoodEntry) -> Void,
        onCancel: @escaping () -> Void = {},
        onDailyReflectionConflict: @escaping (UUID) -> Void = { _ in }
    ) {
        self.entryToEdit = entryToEdit
        self.initialRecordType = entryToEdit?.recordType ?? initialRecordKind.storageValue
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDailyReflectionConflict = onDailyReflectionConflict

        _selectedMoodScore = State(initialValue: entryToEdit?.moodScore ?? 4)
        _selectedRecordType = State(initialValue: entryToEdit?.recordType ?? initialRecordKind.storageValue)
        _selectedEmotions = State(initialValue: Set(entryToEdit?.emotions ?? []))
        _selectedInfluences = State(initialValue: Set(entryToEdit?.influences ?? []))
        _selectedLifeFactors = State(initialValue: Set(entryToEdit?.lifeFactors ?? []))
        _activities = State(initialValue: Set(entryToEdit?.activities ?? []))
        _notes = State(initialValue: entryToEdit?.notes ?? "")
        _gratitude = State(initialValue: entryToEdit?.gratitude ?? "")
        _reflections = State(initialValue: entryToEdit?.reflections ?? "")
        _isShowingDetails = State(initialValue: entryToEdit.map { entry in
            !entry.emotions.isEmpty ||
            !entry.lifeFactors.isEmpty ||
            !entry.activities.isEmpty ||
            !entry.gratitude.isEmpty ||
            !entry.reflections.isEmpty
        } ?? false)
    }

    private let recordTypes = ["今現在の気分", "今日一日の気分"]
    private let moodLabels = ["非常に不快", "不快", "やや不快", "普通", "やや快適", "快適", "非常に快適"]

    private let emotionOptions = [
        "幸せ", "満足", "楽しい", "誇り", "感謝", "平和", "希望", "興奮",
        "不安", "ストレス", "悲しみ", "怒り", "不満", "疲労", "孤独", "混乱"
    ]

    private let eventOptions = [
        "タスク", "健康", "友達", "家族", "天気", "仕事", "学校", "お金",
        "恋愛", "趣味", "ニュース", "音楽", "食事", "休息"
    ]

    private var primaryEventOptions: [String] {
        Array(eventOptions.prefix(6))
    }

    private var additionalEventOptions: [String] {
        Array(eventOptions.dropFirst(6))
    }

    private var customEventTags: [String] {
        selectedInfluences
            .filter { !eventOptions.contains($0) }
            .sorted()
    }

    private let lifeFactorOptions = ["睡眠", "運動", "日光", "食事", "水分", "瞑想", "読書", "散歩"]
    private let activityOptions = ["勉強", "実験", "運動", "読書", "友人との時間", "家族との時間", "趣味", "休息"]

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 16) {
                    recordTypeSection
                    moodSelectionSection
                    eventSection
                    memoSection

                    if isShowingDetails {
                        detailsSection(scrollProxy: scrollProxy)
                    } else {
                        detailPrompt
                    }
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DiaryTheme.canvas)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                saveBar
            }
        }
        .navigationTitle(entryToEdit == nil ? "新しい記録" : "記録を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル", action: requestDismiss)
            }
        }
        .confirmationDialog(
            "入力を破棄しますか？",
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("入力を破棄", role: .destructive) {
                onCancel()
            }
            Button("続ける", role: .cancel) {}
        } message: {
            Text("入力中の内容は保存されません。")
        }
        .alert("保存できませんでした", isPresented: $showingSaveError) {
            if let dailyReflectionConflictID {
                Button("既存の振り返りを開く") {
                    onDailyReflectionConflict(dailyReflectionConflictID)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private var recordTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(DiaryTheme.muted)
                Text(formattedDate(entryToEdit?.date ?? Date()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DiaryTheme.ink)
                Spacer()
                Text(entryToEdit == nil ? "新しい記録" : "記録を編集")
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
            }

            Divider()

            sectionTitle("記録の種類", systemImage: "clock")

            HStack(spacing: 10) {
                recordTypeChoice(
                    title: "今の気分",
                    subtitle: "今この瞬間",
                    systemImage: "sparkles",
                    value: recordTypes[0]
                )
                recordTypeChoice(
                    title: "今日一日",
                    subtitle: "一日を振り返る",
                    systemImage: "sun.max",
                    value: recordTypes[1]
                )
            }
        }
        .diaryFormCard()
    }

    private func recordTypeChoice(
        title: String,
        subtitle: String,
        systemImage: String,
        value: String
    ) -> some View {
        let isSelected = selectedRecordType == value

        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedRecordType = value
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(isSelected ? DiaryTheme.accent : DiaryTheme.muted)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DiaryTheme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                isSelected ? DiaryTheme.accentSoft : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? DiaryTheme.accent : DiaryTheme.line, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)・\(subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var moodSelectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle(
                    selectedRecordType == "今現在の気分" ? "今の気分は？" : "今日一日の気分は？",
                    systemImage: "face.smiling"
                )
                Spacer()
                Text("\(selectedMoodScore) / 7")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                DiaryLineIcon(
                    kind: .mood(selectedMoodScore),
                    color: DiaryTheme.moodColor(for: selectedMoodScore),
                    size: 48
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(moodLabels[selectedMoodScore - 1])
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DiaryTheme.moodColor(for: selectedMoodScore))
                    Text("スコア \(selectedMoodScore) / 7")
                        .font(.caption)
                        .foregroundStyle(DiaryTheme.muted)
                }

                Spacer()
            }
            .padding(.vertical, 4)

            MoodInputRail(score: $selectedMoodScore, labels: moodLabels)
        }
        .diaryFormCard()
        .id("mood-selection")
    }

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("メモ", systemImage: "note.text")
                Spacer()
                Text("任意")
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
            }

            textEditorField(
                text: $notes,
                prompt: "今の気持ちや出来事を、短くても自由に書けます",
                field: .notes
            )
        }
        .diaryFormCard()
    }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("今日、何があった？", systemImage: "circle.grid.2x2")
                Spacer()
                Text(selectedInfluences.isEmpty ? "任意" : "\(selectedInfluences.count)個")
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
            }

            Text("出来事のタグは、あとで気分の変化と比べるために使います。")
                .font(.caption)
                .foregroundStyle(DiaryTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            tagGrid(options: primaryEventOptions, selection: $selectedInfluences, color: DiaryTheme.orange)

            Button {
                showingAdditionalEvents = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "ellipsis.circle")
                    Text("その他の出来事")
                    Spacer()
                    if !additionalEventOptions.filter(selectedInfluences.contains).isEmpty || !customEventTags.isEmpty {
                        Text("追加済み")
                            .font(.caption)
                            .foregroundStyle(DiaryTheme.orange)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DiaryTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .diaryFormCard()
        .sheet(isPresented: $showingAdditionalEvents) {
            additionalEventsSheet
        }
    }

    private var additionalEventsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("既存のタグ")
                            .font(.headline)
                        tagGrid(
                            options: additionalEventOptions,
                            selection: $selectedInfluences,
                            color: DiaryTheme.orange
                        )
                    }

                    if !customEventTags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("追加したタグ")
                                .font(.headline)
                            tagGrid(
                                options: customEventTags,
                                selection: $selectedInfluences,
                                color: DiaryTheme.accent
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("自由タグを追加")
                            .font(.headline)

                        HStack(spacing: 8) {
                            TextField("例：通院、発表、移動", text: $customEventTag)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(addCustomEventTag)

                            Button("追加", action: addCustomEventTag)
                                .buttonStyle(.borderedProminent)
                                .tint(DiaryTheme.accent)
                                .disabled(customEventTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(20)
            }
            .background(DiaryTheme.canvas)
            .navigationTitle("その他の出来事")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        showingAdditionalEvents = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addCustomEventTag() {
        let value = customEventTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        selectedInfluences.insert(value)
        customEventTag = ""
    }

    private var detailPrompt: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingDetails = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(DiaryTheme.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text("詳細を追加する")
                        .font(.headline)
                        .foregroundStyle(DiaryTheme.ink)
                    Text("感情・生活習慣・活動・振り返りなど。入力はすべて任意です")
                        .font(.caption)
                        .foregroundStyle(DiaryTheme.muted)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DiaryTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("任意の詳細入力を表示します")
    }

    @ViewBuilder
    private func detailsSection(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("詳細入力")
                        .font(.title3.weight(.bold))
                    Text("必要な項目だけ開いて記録できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("閉じる") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingDetails = false
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DiaryTheme.accent)
            }
            .padding(.horizontal, 4)

            detailDisclosure(
                section: .emotions,
                title: "今の感情",
                subtitle: selectedEmotions.isEmpty ? "選択なし" : "\(selectedEmotions.count)個選択",
                systemImage: "sparkles",
                color: DiaryTheme.blue
            ) {
                tagGrid(options: emotionOptions, selection: $selectedEmotions, color: .blue)
            }

            detailDisclosure(
                section: .lifeFactors,
                title: "生活習慣",
                subtitle: selectedLifeFactors.isEmpty ? "選択なし" : "\(selectedLifeFactors.count)個選択",
                systemImage: "leaf.fill",
                color: DiaryTheme.green
            ) {
                tagGrid(options: lifeFactorOptions, selection: $selectedLifeFactors, color: .green)
            }

            detailDisclosure(
                section: .activities,
                title: "今日したこと",
                subtitle: activities.isEmpty ? "選択なし" : "\(activities.count)個選択",
                systemImage: "checkmark.circle",
                color: DiaryTheme.purple
            ) {
                tagGrid(options: activityOptions, selection: $activities, color: .purple)
            }

            detailDisclosure(
                section: .gratitude,
                title: "感謝していること",
                subtitle: gratitude.isEmpty ? "自由記述" : "入力済み",
                systemImage: "heart.fill",
                color: DiaryTheme.accent
            ) {
                textEditorField(
                    text: $gratitude,
                    prompt: "小さなことでも大丈夫です",
                    field: .gratitude
                )
            }

            detailDisclosure(
                section: .reflection,
                title: "今日の振り返り",
                subtitle: reflections.isEmpty ? "自由記述" : "入力済み",
                systemImage: "arrow.clockwise",
                color: DiaryTheme.green
            ) {
                textEditorField(
                    text: $reflections,
                    prompt: "今日気づいたこと、明日の自分へのメモ",
                    field: .reflection
                )
            }
        }
        .id("details")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollProxy.scrollTo("details", anchor: .top)
            }
        }
    }

    private var saveBar: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)

            Button(action: saveEntry) {
                HStack(spacing: 6) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark")
                    }
                    Text(isSaving ? "保存中" : (entryToEdit == nil ? "保存" : "更新"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(DiaryTheme.accent, in: Capsule())
            }
            .disabled(isSaving)
            .accessibilityLabel("日記を保存")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DiaryTheme.surface)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func detailDisclosure<Content: View>(
        section: DetailSection,
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: expandedBinding(for: section)) {
            content()
                .padding(.top, 10)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(DiaryTheme.muted)
        .diaryFormCard()
    }

    private func tagGrid(
        options: [String],
        selection: Binding<Set<String>>,
        color: Color
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.self) { option in
                SelectableButton(
                    label: option,
                    isSelected: selection.wrappedValue.contains(option),
                    backgroundColor: color
                ) {
                    toggle(option, in: selection)
                }
            }
        }
    }

    private func textEditorField(
        text: Binding<String>,
        prompt: String,
        field: InputField
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(prompt)
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }

            TextEditor(text: text)
                .focused($focusedField, equals: field)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 112)
                .padding(10)
        }
        .background(DiaryTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.bold))
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy年M月d日（E） HH:mm"
        return formatter.string(from: date)
    }

    private func expandedBinding(for section: DetailSection) -> Binding<Bool> {
        Binding(
            get: { expandedDetails.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expandedDetails.insert(section)
                } else {
                    expandedDetails.remove(section)
                }
            }
        )
    }

    private func toggle(_ value: String, in selection: Binding<Set<String>>) {
        var values = selection.wrappedValue
        if values.contains(value) {
            values.remove(value)
        } else {
            values.insert(value)
        }
        selection.wrappedValue = values
    }

    private var hasChanges: Bool {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGratitude = gratitude.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReflections = reflections.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let entryToEdit else {
            return selectedMoodScore != 4 ||
                selectedRecordType != initialRecordType ||
                !selectedEmotions.isEmpty ||
                !selectedInfluences.isEmpty ||
                !selectedLifeFactors.isEmpty ||
                !activities.isEmpty ||
                !trimmedNotes.isEmpty ||
                !trimmedGratitude.isEmpty ||
                !trimmedReflections.isEmpty
        }

        return selectedMoodScore != entryToEdit.moodScore ||
            selectedRecordType != entryToEdit.recordType ||
            selectedEmotions.sorted() != entryToEdit.emotions.sorted() ||
            selectedInfluences.sorted() != entryToEdit.influences.sorted() ||
            selectedLifeFactors.sorted() != entryToEdit.lifeFactors.sorted() ||
            activities.sorted() != entryToEdit.activities.sorted() ||
            trimmedNotes != entryToEdit.notes ||
            trimmedGratitude != entryToEdit.gratitude ||
            trimmedReflections != entryToEdit.reflections
    }

    private func requestDismiss() {
        focusedField = nil
        if hasChanges {
            showingDiscardConfirmation = true
        } else {
            onCancel()
        }
    }

    private func saveEntry() {
        guard !isSaving else { return }
        focusedField = nil
        isSaving = true

        do {
            dailyReflectionConflictID = nil
            let draft = JournalEntryDraft(
                recordType: selectedRecordType,
                mood: moodLabels[selectedMoodScore - 1],
                moodScore: selectedMoodScore,
                emotions: selectedEmotions.sorted(),
                influences: selectedInfluences.sorted(),
                lifeFactors: selectedLifeFactors.sorted(),
                notes: notes,
                activities: activities.sorted(),
                gratitude: gratitude,
                reflections: reflections
            )
            let savedEntry = try MoodEntrySaveService.save(
                draft: draft,
                editing: entryToEdit,
                in: context
            )
            onSave(savedEntry)
        } catch JournalEntrySaveError.dailyReflectionAlreadyExists(let existingID) {
            isSaving = false
            dailyReflectionConflictID = existingID
            saveErrorMessage = JournalEntrySaveError.dailyReflectionAlreadyExists(existingID).localizedDescription
            showingSaveError = true
        } catch {
            isSaving = false
            dailyReflectionConflictID = nil
            saveErrorMessage = error.localizedDescription
            showingSaveError = true
        }
    }
}

private struct MoodInputRail: View {
    @Binding var score: Int
    let labels: [String]

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { geometry in
                ZStack {
                    Capsule()
                        .fill(DiaryTheme.line)
                        .frame(height: 4)
                        .padding(.horizontal, 24)

                    HStack(spacing: 0) {
                        ForEach(1...7, id: \.self) { value in
                            let isSelected = score == value
                            let moodColor = DiaryTheme.moodColor(for: value)

                            Button {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    score = value
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? moodColor.opacity(0.14) : Color.clear)
                                        .frame(width: 48, height: 48)

                                    DiaryLineIcon(
                                        kind: .mood(value),
                                        color: isSelected ? moodColor : DiaryTheme.muted,
                                        size: isSelected ? 38 : 28
                                    )
                                }
                                .frame(maxWidth: .infinity, minHeight: 56)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(value) \(labels[value - 1])")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .frame(width: geometry.size.width, height: 64)
            }
            .frame(height: 64)

            HStack {
                Text("つらい")
                Spacer()
                Text("普通")
                Spacer()
                Text("快適")
            }
            .font(.caption)
            .foregroundStyle(DiaryTheme.muted)
        }
    }
}

private enum DetailSection: Hashable {
    case emotions
    case lifeFactors
    case activities
    case gratitude
    case reflection
}

private enum InputField: Hashable {
    case notes
    case gratitude
    case reflection
}

private extension View {
    func diaryFormCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) {
                Divider()
            }
    }
}
