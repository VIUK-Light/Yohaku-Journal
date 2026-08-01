import SwiftUI
import SwiftData

// ユーザーがメンタルヘルス、恋愛、デジタル健康、ストレスに関する診断を行えるビュー
struct MentalHealthCheckView: View {
    // SwiftDataのデータベースコンテキストにアクセスするための環境変数
    @Environment(\.modelContext) private var context
    // ビューを閉じるための環境変数
    @Environment(\.dismiss) private var dismiss
    
    // 選択されたテストのセットを保持する状態変数
    @State private var selectedTests: Set<SelfCheckType> = []
    // 実行するテストのキュー（順番）を保持する状態変数
    @State private var testQueue: [SelfCheckType] = []
    // 現在実行中のテストのインデックス
    @State private var currentTestIndex = 0
    // 現在のビューの状態（0: テスト選択、1: 評価中、2: 結果表示）
    @State private var currentStep = 0
    
    // 各テストの回答を保持する状態変数。初期値は-1（未回答）
    @State private var phq9Answers: [Int] = Array(repeating: -1, count: 9)
    @State private var gad7Answers: [Int] = Array(repeating: -1, count: 7)
    @State private var k6Answers: [Int] = Array(repeating: -1, count: 6)
    @State private var k10Answers: [Int] = Array(repeating: -1, count: 10)
    @State private var mutualLoveAnswers: [Int] = Array(repeating: -1, count: 10)
    @State private var romanticSignAnswers: [Int] = Array(repeating: -1, count: 10)
    @State private var smartphoneBrainAnswers: [Int] = Array(repeating: -1, count: 12)
    @State private var stressCheckAnswers: [Int] = Array(repeating: -1, count: 20)
    // 自由記述のメモを保持する状態変数
    @State private var notes = ""
    // 危機項目を含む標準尺度を開始するときだけ表示する安全確認。
    // 非臨床の振り返りでは回答を強制しない。回答内容は保存しない。
    @State private var safetyGateCompleted = true
    @State private var safetyResponse: SafetyResponse?
    @State private var saveSafetyCheck = false
    @State private var showingSupportResources = false
    @State private var safetySaveError = false
    @State private var assessmentSaveError = false

    private enum SafetyResponse: String, CaseIterable, Identifiable {
        case notNow = "今はない"
        case unsure = "少しある／よくわからない"
        case present = "ある"

        var id: String { rawValue }
    }
    
    // 定義・根拠・利用可否はSelfCheckDefinition.swiftに集約する。
    // Viewは表示と入力イベントだけを担当する。
    typealias TestType = SelfCheckType
    
    // PHQ-9テストの質問リスト
    
    // ビューの本体
    var body: some View {
        NavigationStack {
            Group {
                if safetyGateCompleted {
                    switch currentStep {
                    case 0: testSelectionView
                    case 1: assessmentView
                    case 2: resultView
                    default: testSelectionView
                    }
                } else {
                    safetyGateView
                }
            }
            .navigationTitle("セルフチェック")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss() // 現在のビューを閉じる
                    }
                }
                if safetyGateCompleted && currentStep > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("戻る") {
                            goBack() // 前のステップまたは前のテストに戻る処理を実行
                        }
                    }
                }
            }
            .alert("保存できませんでした", isPresented: $assessmentSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("回答内容は画面に残っています。空き容量や端末の状態を確認して、もう一度保存できます。")
            }
        }
    }

    private var safetyGateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("始める前に、安全確認", systemImage: "checkmark.shield")
                    .font(.title2.weight(.semibold))

                Text("答えたくない場合は、ここで閉じても大丈夫です。回答内容は保存しません。")
                    .foregroundStyle(.secondary)

                Text("今、自分を傷つけたい気持ちや、消えてしまいたい気持ちはありますか？")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(SafetyResponse.allCases) { response in
                        Button {
                            safetyResponse = response
                            showingSupportResources = response != .notNow
                        } label: {
                            HStack {
                                Text(response.rawValue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: safetyResponse == response ? "checkmark.circle.fill" : "circle")
                            }
                            .font(.body.weight(.medium))
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.bordered)
                        .tint(safetyResponse == response ? DiaryTheme.accent : .secondary)
                        .accessibilityAddTraits(safetyResponse == response ? .isSelected : [])
                    }
                }

                if safetyResponse == .unsure || safetyResponse == .present {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("今すぐひとりで抱えなくて大丈夫です。家族・先生・保健室・信頼できる大人に声をかけることも選べます。")
                            .fixedSize(horizontal: false, vertical: true)

                        Button(showingSupportResources ? "相談先を閉じる" : "相談先を見る") {
                            showingSupportResources.toggle()
                        }
                        .buttonStyle(.borderedProminent)

                        if showingSupportResources {
                            CompactSupportResourcesView()
                        }
                    }
                    .padding()
                    .background(DiaryTheme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Toggle("安全確認を行ったことだけを端末に保存する（回答内容は保存しません）", isOn: $saveSafetyCheck)
                    .font(.subheadline)

                if safetySaveError {
                    Text("端末への保存に失敗しました。回答内容は保存されていません。保存せずに続けることはできます。")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                VStack(spacing: 10) {
                    Button("続ける") {
                        completeSafetyGate()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(safetyResponse == nil)

                    Button("いったん閉じる") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
    }

    private func completeSafetyGate() {
        guard safetyResponse != nil else { return }
        safetySaveError = false

        if saveSafetyCheck {
            do {
                _ = try SafetyCheckSaveService().saveCheckDate(in: context)
            } catch {
                safetySaveError = true
                return
            }
        }

        safetyGateCompleted = true
        beginSelectedTests()
    }
    
    // テスト選択画面のビュー（ScrollViewでスクロール可能）
    @ViewBuilder
    private var testSelectionView: some View {
        ScrollView {
            // テスト選択画面のコンテンツを垂直に配置
            VStack(spacing: 24) {
                // タイトルとサブタイトル
                VStack(spacing: 12) {
                    Text("振り返りたいものを選択してください")
                        .font(.title2.bold()) // タイトルを太字、大きめのフォントで表示
                    
                    Text("結果で決めつけず、自分の気づきを整理するために使えます")
                        .font(.subheadline) // サブタイトルを少し小さめのフォントで表示
                        .foregroundColor(.secondary) // 色を二次色（グレー系）に設定
                }
                
                // カテゴリごとにテストカードを表示
                VStack(spacing: 20) {
                    // メンタルヘルスカテゴリのセクション
                    categorySection(title: "心の振り返り",
                                  tests: [.phq9, .gad7, .k6, .k10])
                    
                    // 恋愛診断カテゴリのセクション
                    categorySection(title: "関係性の振り返り",
                                  tests: [.mutualLove, .romanticSign])
                    
                    // デジタル健康カテゴリのセクション
                    categorySection(title: "スマホとの付き合い方",
                                  tests: [.smartphoneBrain])
                    
                    // ストレスカテゴリのセクション
                    categorySection(title: "職場向けチェック",
                                  tests: [.stressCheck])
                }
                
                // 選択されたテストがある場合に、選択数と推定所要時間を表示
                if !selectedTests.isEmpty {
                    VStack(spacing: 8) {
                        Text("選択したテスト: \(selectedTests.count)個")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // estimatedTimeプロパティ（計算プロパティ）を使用して所要時間を表示
                        Text("必要な時間: 約\(estimatedTime)分")
                            .font(.caption) // キャプションサイズのフォント
                            .foregroundColor(DiaryTheme.primary)
                    }
                }
                
                // テスト開始ボタン
                Button("選択した振り返りを開始") {
                    startSelectedTests() // テスト開始処理を呼び出す
                }
                .font(.headline) // 見出しフォント
                .foregroundColor(.white) // 文字色を白に
                .frame(maxWidth: .infinity) // 幅を最大に
                .padding() // 内側のパディング
                // 選択が空の場合はグレー、選択がある場合は青色のグラデーション背景
                .background(selectedTests.isEmpty ? DiaryTheme.muted : DiaryTheme.primary)
                .cornerRadius(12) // 角を丸くする
                .disabled(selectedTests.isEmpty) // 選択がない場合はボタンを無効化
            }
            .padding() // VStack全体にパディング
        }
    }
    
    // カテゴリごとのテストカードセクションを生成するヘルパー関数
    @ViewBuilder
    private func categorySection(title: String, tests: [SelfCheckType]) -> some View {
        // カテゴリセクションの垂直スタック
        VStack(alignment: .leading, spacing: 16) {
            // カテゴリタイトルとアイコン
            HStack(spacing: 10) {
                if let kind = tests.first?.lineIconKind {
                    DiaryLineIcon(kind: kind, color: DiaryTheme.primary, size: 28)
                }
                
                Text(title) // カテゴリ名
                    .font(.headline.bold()) // 太字の見出しフォント
                    .foregroundColor(DiaryTheme.ink)
                
                Spacer() // 右端に寄せる
            }
            
            // 各テストタイプに対するTestSelectionCardを表示
            VStack(spacing: 12) {
                ForEach(tests, id: \.self) { testType in
                    TestSelectionCard( // カスタムビュー: テスト選択カード
                        testType: testType, // テストの種類
                        isSelected: selectedTests.contains(testType) // 選択されているかどうかの状態
                    ) {
                        // タップ時のアクション（テストの選択/解除）
                        if testType.isPaused {
                            return
                        }
                        if selectedTests.contains(testType) {
                            selectedTests.remove(testType) // 選択解除
                        } else {
                            selectedTests.insert(testType) // 選択
                        }
                    }
                }
            }
        }
        .padding() // セクションの内側にパディング
        .background(DiaryTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DiaryTheme.line, lineWidth: 1)
        }
    }
    
    // 評価（質問）画面のビュー
    @ViewBuilder
    private var assessmentView: some View {
        VStack {
            // 現在のテストが存在する場合のみ表示
            if let currentTest = currentTest {
                // 進捗表示と現在のテスト名
                HStack {
                    // 現在のテストインデックスと総テスト数
                    Text("進捗: \(currentTestIndex + 1)/\(testQueue.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer() // 右端に寄せる
                    Text("\(currentTest.displayName)") // 現在のテスト名
                        .font(.subheadline)
                        .foregroundColor(currentTest.color) // テストの色で表示
                }
                .padding(.horizontal) // 水平方向にパディング
                
                // 進捗バー
                ProgressView(value: Double(currentTestIndex + 1), total: Double(testQueue.count))
                    .padding() // パディング
                
                // 現在のテストの表示名
                Text(currentTest.displayName)
                    .font(.title2.bold()) // 太字、大きめのフォント
                    .foregroundColor(currentTest.color) // テストの色
                    .padding() // パディング
                
                // 現在のテストに対する指示テキスト
                Text(getInstructionText(for: currentTest))
                    .font(.subheadline) // サブフォント
                    .foregroundColor(.secondary) // 二次色
                    .padding(.horizontal) // 水平方向にパディング
                
                // 質問カードのリスト（ScrollViewでスクロール可能）
                ScrollView {
                    LazyVStack(spacing: 20) { // LazyVStackで効率的に表示
                        // 現在のテストに関する質問、回答、選択肢を取得
                        let questions = getQuestions(for: currentTest)
                        let answers = getAnswers(for: currentTest)
                        let options = getAnswerOptions(for: currentTest)
                        
                        // 各質問に対してQuestionCardを表示
                        ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                            QuestionCard( // カスタムビュー: 質問カード
                                questionNumber: index + 1, // 質問番号（1から開始）
                                questionText: question, // 質問文
                                selectedAnswer: answers[index], // 現在選択されている回答（初期値-1）
                                answerOptions: options, // 回答選択肢
                                color: currentTest.color // テストの色
                            ) { selectedScore in
                                // 回答が選択された時のコールバック
                                updateAnswer(for: currentTest, index: index, score: selectedScore) // 回答を更新
                            }
                        }
                    }
                    .padding() // LazyVStack全体にパディング
                }
                
                // 次のステップ（テスト）へ進むボタン
                Button(action: nextStep) { // nextStep()関数を呼び出す
                    // 最後のテストであれば「結果を表示」、そうでなければ「次のテストへ」というテキストを表示
                    Text(isLastTest ? "結果を表示" : "次のテストへ")
                        .font(.headline) // 見出しフォント
                        .foregroundColor(.white) // 文字色を白に
                        .frame(maxWidth: .infinity) // 幅を最大に
                        .padding() // 内側パディング
                        // canProceed（次へ進める状態）がtrueならテストの色、そうでなければグレーのグラデーション背景
                        .background(canProceed ? currentTest.color.gradient : Color.gray.gradient)
                        .cornerRadius(12) // 角を丸くする
                }
                .disabled(!canProceed) // canProceedがfalseの場合、ボタンを無効化
                .padding() // ボタンのパディング
            }
        }
    }
    
    // 結果表示画面のビュー
    @ViewBuilder
    /// 独自チェックは診断カードではなく、回答内容を眺める事実ベースの結果にする。
    @ViewBuilder
    private var resultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("振り返りの記録")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(SelfCheckType.guidedReflectionTypes, id: \.self) { type in
                    if selectedTests.contains(type) {
                        SelfCheckObservationCard(
                            result: makeResult(for: type),
                            guidance: type.definition.resultGuidance
                        )
                    }
                }

                if selectedTests.contains(where: { $0.definition.evidenceLevel == .standardizedInstrument }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("標準尺度は現在利用できません")
                            .font(.headline)
                        Text("出典、対象年齢、採点方法、利用条件、安全導線の確認が終わるまで、新しい結果は作成しません。")
                            .font(.subheadline)
                            .foregroundStyle(DiaryTheme.muted)
                    }
                    .diarySurface(padding: 16, radius: 16)
                }

                Text("ここに表示されるのは、選択した回答を整理したものです。病名、重症度、他人の気持ちを決めるものではありません。")
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button("結果を保存") { saveAssessment() }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DiaryTheme.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("新しい振り返り") { resetForNewTest() }
                        .font(.headline)
                        .foregroundStyle(DiaryTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DiaryTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private func makeResult(for type: SelfCheckType) -> SelfCheckResult {
        SelfCheckSession(type: type, answers: getAnswers(for: type)).makeResult()
    }
    
    // 現在のテストタイプに応じて、画面に表示する指示テキストを取得する関数
    private func getInstructionText(for testType: SelfCheckType) -> String {
        SelfCheckCatalog.instruction(for: testType)
    }
    
    // 現在のテストタイプに応じて、質問リストを取得する関数
    private func getQuestions(for testType: SelfCheckType) -> [String] {
        SelfCheckCatalog.questions(for: testType)
    }
    
    // 現在のテストタイプに応じて、回答配列を取得する関数
    private func getAnswers(for testType: SelfCheckType) -> [Int] {
        switch testType {
        case .phq9: return phq9Answers
        case .gad7: return gad7Answers
        case .k6: return k6Answers
        case .k10: return k10Answers
        case .mutualLove: return mutualLoveAnswers
        case .romanticSign: return romanticSignAnswers
        case .smartphoneBrain: return smartphoneBrainAnswers
        case .stressCheck: return stressCheckAnswers
        }
    }
    
    // 現在のテストタイプに応じて、回答選択肢の配列を取得する関数
    private func getAnswerOptions(for testType: SelfCheckType) -> [String] {
        SelfCheckCatalog.answerOptions(for: testType)
    }
    
    // 指定されたテストタイプ、質問インデックス、選択されたスコアで回答を更新する関数
    private func updateAnswer(for testType: SelfCheckType, index: Int, score: Int) {
        switch testType {
        case .phq9:
            phq9Answers[index] = score // PHQ-9の該当インデックスの回答を更新
        case .gad7:
            gad7Answers[index] = score // GAD-7の該当インデックスの回答を更新
        case .k6:
            k6Answers[index] = score // K6の該当インデックスの回答を更新
        case .k10:
            k10Answers[index] = score // K10の該当インデックスの回答を更新
        case .mutualLove:
            mutualLoveAnswers[index] = score // 両思い診断の該当インデックスの回答を更新
        case .romanticSign:
            romanticSignAnswers[index] = score // 脈あり診断の該当インデックスの回答を更新
        case .smartphoneBrain:
            smartphoneBrainAnswers[index] = score // スマホ脳チェックの該当インデックスの回答を更新
        case .stressCheck:
            stressCheckAnswers[index] = score // ストレスチェックの該当インデックスの回答を更新
        }
    }
    
    // 現在実行中のテストタイプを返す計算プロパティ
    private var currentTest: SelfCheckType? {
        // currentTestIndexがtestQueueの範囲内であれば、そのインデックスのテストタイプを返す
        guard currentTestIndex < testQueue.count else { return nil } // 範囲外ならnil
        return testQueue[currentTestIndex]
    }
    
    // 現在実行中のテストが最後のテストかどうかを判定する計算プロパティ
    private var isLastTest: Bool {
        currentTestIndex == testQueue.count - 1 // 現在のインデックスが最後のインデックスと等しいか
    }
    
    // 次のステップ（テスト）に進むことができるかどうかを判定する計算プロパティ
    private var canProceed: Bool {
        guard let currentTest = currentTest else { return false } // 現在のテストがなければfalse
        let answers = getAnswers(for: currentTest) // 現在のテストの回答配列を取得
        // 回答配列に-1（未回答）が含まれていない場合、trueを返す
        return !answers.contains(-1)
    }
    
    // 選択されたテストの合計所要時間（分）を計算する計算プロパティ
    private var estimatedTime: Int {
        var time = 0 // 合計時間を初期化
        // 各テストが選択されているか確認し、所要時間を加算
        if selectedTests.contains(.phq9) { time += 3 }
        if selectedTests.contains(.gad7) { time += 2 }
        if selectedTests.contains(.k6) { time += 2 }
        if selectedTests.contains(.k10) { time += 3 }
        if selectedTests.contains(.mutualLove) { time += 3 }
        if selectedTests.contains(.romanticSign) { time += 3 }
        if selectedTests.contains(.smartphoneBrain) { time += 4 }
        if selectedTests.contains(.stressCheck) { time += 5 }
        return time // 合計時間を返す
    }
    
    // 選択されたテストを開始する。危機項目を含む尺度だけ安全確認を先に表示する。
    private func startSelectedTests() {
        if selectedTests.contains(where: \.requiresSafetyGate) {
            safetyGateCompleted = false
            safetyResponse = nil
            showingSupportResources = false
            safetySaveError = false
            return
        }

        beginSelectedTests()
    }

    private func beginSelectedTests() {
        // 一時停止中のチェックが状態に残っていても、実行キューには入れない。
        testQueue = selectedTests.filter { !$0.isPaused }
        guard !testQueue.isEmpty else { return }
        // 現在のテストインデックスをリセット
        currentTestIndex = 0
        // ステップを評価中（1）に更新
        currentStep = 1
    }
    
    // 次のステップ（テストまたは結果表示）に進む関数
    private func nextStep() {
        if isLastTest { // もし最後のテストなら
            currentStep = 2 // ステップを結果表示（2）に更新
        } else { // 最後でなければ
            currentTestIndex += 1 // 現在のテストインデックスを1増やす
        }
    }
    
    // 前のステップまたは前のテストに戻る関数
    private func goBack() {
        if currentStep == 1 && currentTestIndex > 0 { // 評価中で、最初のテストでなければ
            currentTestIndex -= 1 // 前のテストに戻る
        } else if currentStep == 1 && currentTestIndex == 0 { // 評価中で、最初のテストなら
            currentStep = 0 // ステップをテスト選択（0）に戻す
        } else if currentStep == 2 { // 結果表示画面の場合
            currentStep = 1 // ステップを評価中（1）に戻す
            currentTestIndex = testQueue.count - 1 // 最後のテストのインデックスに設定（結果表示から戻った場合）
        }
    }
    
    // 新しいテストのために状態をリセットする関数
    private func resetForNewTest() {
        selectedTests.removeAll() // 選択されたテストをクリア
        testQueue.removeAll() // テストキューをクリア
        currentTestIndex = 0 // 現在のテストインデックスをリセット
        currentStep = 0 // ステップをテスト選択（0）にリセット
        // 各テストの回答配列を初期値（-1）でリセット
        phq9Answers = Array(repeating: -1, count: 9)
        gad7Answers = Array(repeating: -1, count: 7)
        k6Answers = Array(repeating: -1, count: 6)
        k10Answers = Array(repeating: -1, count: 10)
        mutualLoveAnswers = Array(repeating: -1, count: 10)
        romanticSignAnswers = Array(repeating: -1, count: 10)
        smartphoneBrainAnswers = Array(repeating: -1, count: 12)
        stressCheckAnswers = Array(repeating: -1, count: 20)
        notes = "" // メモをクリア
        safetyGateCompleted = true
        safetyResponse = nil
        showingSupportResources = false
        saveSafetyCheck = false
        safetySaveError = false
    }
    
    // 診断結果をSwiftDataに保存する関数
    private func saveAssessment() {
        assessmentSaveError = false
        let draft = SelfCheckResultDraft(
            selectedTests: selectedTests,
            phq9Answers: phq9Answers,
            gad7Answers: gad7Answers,
            k6Answers: k6Answers,
            k10Answers: k10Answers,
            mutualLoveAnswers: mutualLoveAnswers,
            romanticSignAnswers: romanticSignAnswers,
            smartphoneBrainAnswers: smartphoneBrainAnswers,
            stressCheckAnswers: stressCheckAnswers
        )

        do {
            _ = try MentalHealthAssessmentSaveService().save(draft: draft, in: context)
        } catch {
            // 保存に失敗しても回答配列はViewのStateに残るため、再試行できる。
            assessmentSaveError = true
        }
    }
}

// テスト選択カードのカスタムビュー
struct TestSelectionCard: View {
    let testType: SelfCheckType // 表示するテストの種類
    let isSelected: Bool // 選択されているかどうかの状態
    let onTap: () -> Void // タップされた時のアクション
    
    var body: some View {
        Button(action: onTap) { // ボタンとして機能し、タップ時にonTapクロージャを実行
            VStack(alignment: .leading, spacing: 16) {
                HStack { // 表示名と説明文
                    DiaryLineIcon(
                        kind: testType.lineIconKind,
                        color: testType.isPaused ? DiaryTheme.muted : DiaryTheme.primary,
                        size: 30
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(testType.displayName) // テストの表示名
                            .font(.headline.bold()) // 太字の見出しフォント
                            .foregroundColor(.primary) // プライマリテキストカラー
                        
                    Text(testType.description) // テストの説明文
                        .font(.subheadline) // サブヘッダフォント
                        .foregroundColor(.secondary) // 二次テキストカラー

                    if testType.isPaused {
                        Text("現在は利用できません")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    }
                    
                    Spacer() // 右端に寄せる
                    
                    // 選択状態に応じてチェックマークアイコンを表示
                    Image(systemName: testType.isPaused ? "pause.circle" : (isSelected ? "checkmark.circle.fill" : "circle"))
                        .font(.title2) // タイトル2サイズのフォント
                        .foregroundColor(isSelected ? DiaryTheme.primary : DiaryTheme.muted)
                }
                
                HStack { // カテゴリと質問数
                    Text(testType.category)
                        .font(.caption) // キャプションフォント
                        .foregroundColor(DiaryTheme.muted)
                    
                    Spacer() // 右端に寄せる
                    
                    Text(testType.questionCount) // 質問数
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding() // カード内部のパディング
            .background( // 背景設定
                RoundedRectangle(cornerRadius: 12) // 角丸の背景
                    .fill(isSelected ? DiaryTheme.primary.opacity(0.12) : DiaryTheme.elevatedSurface)
            )
            .overlay( // カードの縁取り
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? DiaryTheme.primary : DiaryTheme.line, lineWidth: isSelected ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle()) // ボタンのデフォルトスタイルを無効化
        .disabled(testType.isPaused)
        .opacity(testType.isPaused ? 0.58 : 1)
        .accessibilityHint(testType.pauseReason ?? "タップして選択または選択解除")
    }
}

// 質問カードのカスタムビュー
struct QuestionCard: View {
    let questionNumber: Int // 質問番号
    let questionText: String // 質問文
    let selectedAnswer: Int // 現在選択されている回答のインデックス (-1は未回答)
    let answerOptions: [String] // 回答選択肢の配列
    let color: Color // テストに関連付けられた色
    let onAnswerSelected: (Int) -> Void // 回答が選択されたときに呼び出されるクロージャ
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(questionNumber). \(questionText)") // 質問番号と質問文を表示
                .font(.headline) // 見出しフォント
            
            // 回答選択肢を2列グリッドで表示
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                // 各回答選択肢に対してボタンを作成
                ForEach(Array(answerOptions.enumerated()), id: \.offset) { index, option in
                    Button {
                        onAnswerSelected(index) // ボタンがタップされたら、選択された回答のインデックスを渡してクロージャを実行
                    } label: {
                        Text(option) // 回答選択肢のテキスト
                            .font(.subheadline) // サブヘッダフォント
                            .foregroundColor(selectedAnswer == index ? .white : .primary) // 選択されている回答は白、それ以外はプライマリカラー
                            .padding() // 内側パディング
                            .frame(maxWidth: .infinity) // 幅を最大に
                            .background( // 背景設定
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedAnswer == index ? color : Color(.systemGray6)) // 選択時はテストの色、それ以外はシステムグレー6
                            )
                            .overlay( // 縁取り
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedAnswer == index ? color : .clear, lineWidth: 2) // 選択時はテストの色、それ以外は線なし
                            )
                            .scaleEffect(selectedAnswer == index ? 1.05 : 1.0) // 選択時は少し拡大
                            .animation(.easeInOut(duration: 0.15), value: selectedAnswer) // 選択状態の変化にアニメーション適用
                    }
                }
            }
        }
        .padding() // カード内部のパディング
        .background(Color.white) // 背景を白に
        .cornerRadius(12) // 角を丸くする
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2) // 影を追加
    }
}

// 自己観察の位置づけを表示するビュー
struct DisclaimerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill") // 注意喚起アイコン
                Text("自己観察について") // タイトル
            }
            .font(.headline) // 見出しフォント
            .foregroundColor(.orange) // オレンジ色
            
            // 免責事項の本文
            Text("この画面は医療的な診断や評価を行うものではありません。結果を理由に自分を責めず、気になる状態が続く場合は、家族・先生・相談窓口・医療機関など、話しやすい相手へ相談してください。")
                .font(.caption) // キャプションフォント
        }
        .padding() // パディング
        .background(Color.orange.opacity(0.1)) // 背景色
        .cornerRadius(10) // 角丸
        .padding(.horizontal) // 水平方向のパディング
    }
}
