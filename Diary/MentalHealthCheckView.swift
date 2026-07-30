import SwiftUI
import SwiftData

// ユーザーがメンタルヘルス、恋愛、デジタル健康、ストレスに関する診断を行えるビュー
struct MentalHealthCheckView: View {
    // SwiftDataのデータベースコンテキストにアクセスするための環境変数
    @Environment(\.modelContext) private var context
    // ビューを閉じるための環境変数
    @Environment(\.dismiss) private var dismiss
    
    // 選択されたテストのセットを保持する状態変数
    @State private var selectedTests: Set<TestType> = []
    // 実行するテストのキュー（順番）を保持する状態変数
    @State private var testQueue: [TestType] = []
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
    
    // 診断テストの種類を定義する列挙型
    enum TestType: String, CaseIterable {
        case phq9 = "PHQ-9"
        case gad7 = "GAD-7"
        case k6 = "K6"
        case k10 = "K10"
        case mutualLove = "両思い診断"
        case romanticSign = "脈あり診断"
        case smartphoneBrain = "スマホ脳チェック"
        case stressCheck = "ストレスチェック"
        
        // テストの表示名（ローカライズ対応）
        var displayName: String {
            switch self {
            case .phq9: return "抑うつ症状チェック（PHQ-9）"
            case .gad7: return "不安症状チェック（GAD-7）"
            case .k6: return "心理的苦痛チェック（K6）"
            case .k10: return "心理的苦痛チェック（K10）"
            case .mutualLove: return "両思い診断"
            case .romanticSign: return "脈あり診断"
            case .smartphoneBrain: return "スマホ脳チェック"
            case .stressCheck: return "ストレスチェック"
            }
        }
        
        // テストの説明文
        var description: String {
            switch self {
            case .phq9: return "気分の落ち込みや興味の喪失などの抑うつ症状を評価します（9問・約3分）"
            case .gad7: return "不安や心配、緊張などの不安症状を評価します（7問・約2分）"
            case .k6: return "心理的な苦痛やストレスの程度を簡潔に評価します（6問・約2分）"
            case .k10: return "心理的な苦痛やストレスの程度を詳細に評価します（10問・約3分）"
            case .mutualLove: return "お互いの気持ちや関係性を総合的に分析します（10問・約3分）"
            case .romanticSign: return "相手からの好意のサインを客観的に評価します（10問・約3分）"
            case .smartphoneBrain: return "スマートフォン使用が脳に与える影響を評価します（12問・約4分）"
            case .stressCheck: return "職場や日常生活のストレス状況を総合的に評価します（20問・約5分）"
            }
        }
        
        // テストに関連付けられた色
        var color: Color {
            switch self {
            case .phq9: return .blue
            case .gad7: return .purple
            case .k6: return .indigo
            case .k10: return .cyan
            case .mutualLove: return .pink
            case .romanticSign: return .red
            case .smartphoneBrain: return .orange
            case .stressCheck: return .green
            }
        }
        
        // テストのカテゴリ（例: "メンタルヘルス", "恋愛"）
        var category: String {
            switch self {
            case .phq9, .gad7, .k6, .k10: return "メンタルヘルス"
            case .mutualLove, .romanticSign: return "恋愛"
            case .smartphoneBrain: return "デジタル健康"
            case .stressCheck: return "ストレス"
            }
        }
        
        // テストの質問数（文字列）
        var questionCount: String {
            switch self {
            case .phq9: return "9問"
            case .gad7: return "7問"
            case .k6: return "6問"
            case .k10: return "10問"
            case .mutualLove: return "10問"
            case .romanticSign: return "10問"
            case .smartphoneBrain: return "12問"
            case .stressCheck: return "20問"
            }
        }
        
        // カテゴリに対応するシステムアイコン名
        var systemIcon: String {
            switch self.category {
            case "メンタルヘルス": return "heart.text.square"
            case "恋愛": return "heart.fill"
            case "デジタル健康": return "iphone"
            case "ストレス": return "gauge.high"
            default: return "questionmark.circle"
            }
        }
    }
    
    // PHQ-9テストの質問リスト
    private let phq9Questions = [
        "物事に対してほとんど興味がない、または楽しめない",
        "気分が落ち込む、憂うつになる、または絶望的な気持ちになる",
        "寝つきが悪い、途中で目が覚める、または逆に眠りすぎる",
        "疲れた感じがする、または気力がない",
        "あまり食欲がない、または食べ過ぎる",
        "自分はダメな人間だ、または家族を失望させているという気持ちになる",
        "新聞を読む、テレビを見るなどの事に集中することが難しい",
        "動作や話し方が遅くなった、または落ち着かない、そわそわして普段よりも動き回る",
        "死んだ方がましだ、または自分を何らかの方法で傷つけようと思ったことがある"
    ]
    
    // GAD-7テストの質問リスト
    private let gad7Questions = [
        "神経質になったり、不安になったり、イライラしたりする",
        "心配するのを止めることができない、またはコントロールできない",
        "さまざまなことを心配しすぎる",
        "リラックスすることが困難",
        "じっとしていられないほど落ち着かない",
        "容易にいらだったり、イライラしたりする",
        "何か恐ろしいことが起こるのではないかと恐怖を感じる"
    ]
    
    // K6テストの質問リスト
    private let k6Questions = [
        "神経過敏に感じましたか",
        "絶望的だと感じましたか",
        "そわそわ、落ち着かなく感じましたか",
        "気分が沈み込んで、何が起こっても気が晴れないように感じましたか",
        "何をするのも骨折りだと感じましたか",
        "自分は価値のない人間だと感じましたか"
    ]
    
    // K10テストの質問リスト
    private let k10Questions = [
        "疲れきってしまったと感じましたか",
        "神経過敏に感じましたか",
        "そわそわ、落ち着かなく感じましたか",
        "絶望的だと感じましたか",
        "何をするのも骨折りだと感じましたか",
        "価値のない人間だと感じましたか",
        "悲しいと感じましたか",
        "自分がダメな人間だと感じましたか",
        "気分が沈み込んで、何が起こっても気が晴れないように感じましたか",
        "何もかもがうまくいかないと感じましたか"
    ]
    
    // 両思い診断の質問リスト
    private let mutualLoveQuestions = [
        "お互いに相手のことを第一に考えている",
        "一緒にいる時間が自然で心地よい",
        "お互いの将来について話し合ったことがある",
        "相手があなたのことを友人や家族に紹介してくれた",
        "お互いに素の自分を見せることができている",
        "連絡を取り合う頻度がお互いに心地よい",
        "お互いに困った時に最初に相談し合える関係",
        "相手があなたの好きなことや趣味に興味を示してくれる",
        "お互いに相手の幸せを心から願っている",
        "この関係が特別で大切だと感じている"
    ]
    
    // 脈あり診断の質問リスト
    private let romanticSignQuestions = [
        "その人はあなたとの会話中、よく目を見て話してくれる",
        "その人はあなたからの連絡に比較的早く返事をしてくれる",
        "その人はあなたと二人きりになる機会を作ろうとしている",
        "その人はあなたの話をよく覚えていて、後日それについて触れてくれる",
        "その人はあなたのことを友人や知人に話したことがある",
        "その人はあなたの外見や持ち物について褒めてくれることがある",
        "その人はあなたが困っているときに、積極的に助けてくれる",
        "その人はあなたの冗談やユーモアに対して、よく笑ってくれる",
        "その人はあなたと過ごす時間を大切にしているような態度を示す",
        "その人はあなたの将来の予定や計画について関心を示してくれる"
    ]
    
    // スマホ脳チェックの質問リスト
    private let smartphoneBrainQuestions = [
        "スマートフォンを触っていないと落ち着かない",
        "スマートフォンの通知音が聞こえると、すぐに確認してしまう",
        "食事中や人と話している時にもスマートフォンを見てしまう",
        "寝る前にスマートフォンを見る習慣がある",
        "スマートフォンを忘れると不安になる",
        "集中したい時でもスマートフォンが気になってしまう",
        "1日のスマートフォン使用時間が3時間以上である",
        "スマートフォンを見ながら歩くことがある",
        "SNSを頻繁にチェックしてしまう",
        "スマートフォンの使用を減らそうと思っても難しい",
        "スマートフォンが原因で睡眠不足になることがある",
        "スマートフォンを見た後、目の疲れや頭痛を感じることがある"
    ]
    
    // ストレスチェックの質問リスト
    private let stressCheckQuestions = [
        "活気がわいてくる",
        "元気がいっぱいだ",
        "生き生きする",
        "怒りを感じる",
        "内心腹立たしい",
        "イライラしている",
        "ひどく疲れた",
        "へとへとだ",
        "だるい",
        "気がはりつめている",
        "不安だ",
        "落ち着かない",
        "ゆううつだ",
        "何をするのも面倒だ",
        "物事に集中できない",
        "気分が晴れない",
        "仕事が手につかない",
        "悲しいと感じる",
        "めまいがする",
        "体のふしぶしが痛む"
    ]
    
    // 一般的なテストの回答選択肢（例: "全くない"〜"ほぼ毎日"）
    private let answerOptions = ["全くない", "数日", "半分以上", "ほぼ毎日"]
    // 恋愛関連テストの回答選択肢（例: "全くない"〜"いつも"）
    private let loveAnswerOptions = ["全くない", "たまに", "よくある", "いつも"]
    // K6, K10テストの回答選択肢（例: "全くない"〜"いつも"）
    private let k6k10Options = ["全くない", "少しだけ", "時々", "たいてい", "いつも"]
    // スマホ脳チェックの回答選択肢（例: "全くない"〜"いつも"）
    private let smartphoneOptions = ["全くない", "たまに", "よく", "いつも"]
    // ストレスチェックの回答選択肢（例: "そうだ"〜"違う"）
    private let stressOptions = ["そうだ", "まあそうだ", "やや違う", "違う"]
    
    // ビューの本体
    var body: some View {
        // ナビゲーションスタックで画面遷移を管理
        NavigationStack {
            // メインの垂直スタック
            VStack {
                // PHQ-9, GAD-7, K6, K10, ストレスチェックのいずれかが選択されている場合に免責事項を表示
                if selectedTests.contains(.phq9) || selectedTests.contains(.gad7) ||
                   selectedTests.contains(.k6) || selectedTests.contains(.k10) ||
                   selectedTests.contains(.stressCheck) {
                    DisclaimerView() // 免責事項を表示するカスタムビュー
                }
                
                // 現在のステップ（画面の状態）に応じて表示するビューを切り替える
                switch currentStep {
                case 0:
                    testSelectionView // テスト選択画面を表示
                case 1:
                    assessmentView // 評価（質問）画面を表示
                case 2:
                    resultView // 結果表示画面を表示
                default:
                    testSelectionView // デフォルトはテスト選択画面
                }
            }
            .navigationTitle("心理・恋愛・デジタル診断") // ナビゲーションバーのタイトル
            .navigationBarTitleDisplayMode(.inline) // タイトルをインライン（中央揃え）で表示
            .toolbar { // ナビゲーションバーのツールバー設定
                // 左側のツールバーアイテム
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { // 閉じるボタン
                        dismiss() // 現在のビューを閉じる
                    }
                }
                
                // 現在のステップが0より大きい場合（テスト選択画面以外の場合）、戻るボタンを表示
                if currentStep > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("戻る") { // 戻るボタン
                            goBack() // 前のステップまたは前のテストに戻る処理を実行
                        }
                    }
                }
            }
        }
    }
    
    // テスト選択画面のビュー（ScrollViewでスクロール可能）
    @ViewBuilder
    private var testSelectionView: some View {
        ScrollView {
            // テスト選択画面のコンテンツを垂直に配置
            VStack(spacing: 24) {
                // タイトルとサブタイトル
                VStack(spacing: 12) {
                    Text("診断したい項目を選択してください")
                        .font(.title2.bold()) // タイトルを太字、大きめのフォントで表示
                    
                    Text("心の健康、恋愛、デジタル健康、ストレスから選択できます")
                        .font(.subheadline) // サブタイトルを少し小さめのフォントで表示
                        .foregroundColor(.secondary) // 色を二次色（グレー系）に設定
                }
                
                // カテゴリごとにテストカードを表示
                VStack(spacing: 20) {
                    // メンタルヘルスカテゴリのセクション
                    categorySection(title: "メンタルヘルス",
                                  tests: [.phq9, .gad7, .k6, .k10],
                                  icon: "heart.text.square",
                                  color: .blue)
                    
                    // 恋愛診断カテゴリのセクション
                    categorySection(title: "恋愛診断",
                                  tests: [.mutualLove, .romanticSign],
                                  icon: "heart.fill",
                                  color: .pink)
                    
                    // デジタル健康カテゴリのセクション
                    categorySection(title: "デジタル健康",
                                  tests: [.smartphoneBrain],
                                  icon: "iphone",
                                  color: .orange)
                    
                    // ストレスカテゴリのセクション
                    categorySection(title: "ストレス",
                                  tests: [.stressCheck],
                                  icon: "gauge.high",
                                  color: .green)
                }
                
                // 選択されたテストがある場合に、選択数と推定所要時間を表示
                if !selectedTests.isEmpty {
                    VStack(spacing: 8) {
                        Text("選択したテスト: \(selectedTests.count)個")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // estimatedTimeプロパティ（計算プロパティ）を使用して所要時間を表示
                        Text("所要時間: 約\(estimatedTime)分")
                            .font(.caption) // キャプションサイズのフォント
                            .foregroundColor(.blue) // 青色で表示
                    }
                }
                
                // テスト開始ボタン
                Button("選択したテストを開始") {
                    startSelectedTests() // テスト開始処理を呼び出す
                }
                .font(.headline) // 見出しフォント
                .foregroundColor(.white) // 文字色を白に
                .frame(maxWidth: .infinity) // 幅を最大に
                .padding() // 内側のパディング
                // 選択が空の場合はグレー、選択がある場合は青色のグラデーション背景
                .background(selectedTests.isEmpty ? Color.gray.gradient : Color.blue.gradient)
                .cornerRadius(12) // 角を丸くする
                .disabled(selectedTests.isEmpty) // 選択がない場合はボタンを無効化
            }
            .padding() // VStack全体にパディング
        }
    }
    
    // カテゴリごとのテストカードセクションを生成するヘルパー関数
    @ViewBuilder
    private func categorySection(title: String, tests: [TestType], icon: String, color: Color) -> some View {
        // カテゴリセクションの垂直スタック
        VStack(alignment: .leading, spacing: 16) {
            // カテゴリタイトルとアイコン
            HStack {
                Image(systemName: icon) // カテゴリに対応するシステムアイコン
                    .font(.title2) // アイコンのフォントサイズ
                    .foregroundColor(color) // カテゴリの色
                
                Text(title) // カテゴリ名
                    .font(.headline.bold()) // 太字の見出しフォント
                    .foregroundColor(color) // カテゴリの色
                
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
        .background(color.opacity(0.05)) // カテゴリの色を薄めた背景色
        .cornerRadius(16) // 角を丸くする
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
    private var resultView: some View {
        ScrollView { // 結果表示もスクロール可能にする
            // 結果表示コンテンツの垂直スタック
            VStack(spacing: 24) {
                Text("診断結果") // 結果画面のタイトル
                    .font(.largeTitle.bold()) // 大きく太字で表示
                
                // 選択されたテストに基づいて、対応する結果カードを表示
                if selectedTests.contains(.phq9) {
                    ResultCard( // カスタムビュー: 結果カード
                        title: "抑うつ症状（PHQ-9）", // カードタイトル
                        score: phq9Score, // 計算されたスコア
                        maxScore: 27, // 最大スコア
                        interpretation: phq9Interpretation, // 解釈結果
                        color: phq9Color // 結果に対応する色
                    )
                }
                
                if selectedTests.contains(.gad7) {
                    ResultCard(
                        title: "不安症状（GAD-7）",
                        score: gad7Score,
                        maxScore: 21,
                        interpretation: gad7Interpretation,
                        color: gad7Color
                    )
                }
                
                if selectedTests.contains(.k6) {
                    ResultCard(
                        title: "心理的苦痛（K6）",
                        score: k6Score,
                        maxScore: 24,
                        interpretation: k6Interpretation,
                        color: k6Color
                    )
                }
                
                if selectedTests.contains(.k10) {
                    ResultCard(
                        title: "心理的苦痛（K10）",
                        score: k10Score,
                        maxScore: 40,
                        interpretation: k10Interpretation,
                        color: k10Color
                    )
                }
                
                if selectedTests.contains(.mutualLove) {
                    LoveResultCard( // 恋愛結果カード
                        title: "両思い診断",
                        score: mutualLoveScore,
                        maxScore: 40,
                        interpretation: mutualLoveInterpretation,
                        description: mutualLoveDescription, // 詳細な説明
                        color: .pink // 恋愛関連の色
                    )
                }
                
                if selectedTests.contains(.romanticSign) {
                    LoveResultCard(
                        title: "脈あり診断",
                        score: romanticSignScore,
                        maxScore: 40,
                        interpretation: romanticSignInterpretation,
                        description: romanticSignDescription,
                        color: .red
                    )
                }
                
                if selectedTests.contains(.smartphoneBrain) {
                    DigitalHealthResultCard( // デジタル健康結果カード
                        title: "スマホ脳チェック",
                        score: smartphoneBrainScore,
                        maxScore: 48,
                        interpretation: smartphoneBrainInterpretation,
                        description: smartphoneBrainDescription,
                        color: .orange
                    )
                }
                
                if selectedTests.contains(.stressCheck) {
                    StressResultCard( // ストレス結果カード
                        title: "ストレスチェック",
                        score: stressCheckScore,
                        maxScore: 80,
                        interpretation: stressCheckInterpretation,
                        description: stressCheckDescription,
                        color: .green
                    )
                }
                
                // メンタルヘルス関連のテストが選択されている場合に専門家アドバイスを表示
                if selectedTests.contains(.phq9) || selectedTests.contains(.gad7) ||
                   selectedTests.contains(.k6) || selectedTests.contains(.k10) {
                    ProfessionalAdviceView( // カスタムビュー: 専門家アドバイス
                        phq9Score: selectedTests.contains(.phq9) ? phq9Score : nil, // スコアがあれば渡す
                        gad7Score: selectedTests.contains(.gad7) ? gad7Score : nil,
                        k6Score: selectedTests.contains(.k6) ? k6Score : nil,
                        k10Score: selectedTests.contains(.k10) ? k10Score : nil
                    )
                }
                
                // 恋愛関連のテストが選択されている場合に恋愛アドバイスを表示
                if selectedTests.contains(.mutualLove) || selectedTests.contains(.romanticSign) {
                    LoveAdviceView( // カスタムビュー: 恋愛アドバイス
                        mutualLoveScore: selectedTests.contains(.mutualLove) ? mutualLoveScore : nil,
                        romanticSignScore: selectedTests.contains(.romanticSign) ? romanticSignScore : nil
                    )
                }
                
                // デジタル健康テストが選択されている場合にデジタル健康アドバイスを表示
                if selectedTests.contains(.smartphoneBrain) {
                    DigitalHealthAdviceView(smartphoneBrainScore: smartphoneBrainScore) // カスタムビュー: デジタル健康アドバイス
                }
                
                // ストレスチェックが選択されている場合にストレスアドバイスを表示
                if selectedTests.contains(.stressCheck) {
                    StressAdviceView(stressScore: stressCheckScore) // カスタムビュー: ストレスアドバイス
                }
                
                // メンタルヘルス関連のテストが選択されている場合に相談窓口を表示
                if selectedTests.contains(.phq9) || selectedTests.contains(.gad7) ||
                   selectedTests.contains(.k6) || selectedTests.contains(.k10) {
                    ConsultationResourcesView() // カスタムビュー: 相談窓口・リソース
                }
                
                // 結果保存ボタンと新しいテスト開始ボタン
                HStack(spacing: 12) {
                    Button("結果を保存") { // 結果を保存ボタン
                        saveAssessment() // saveAssessment()関数を呼び出す
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.gradient) // 緑色のグラデーション背景
                    .cornerRadius(12)
                    
                    Button("新しいテスト") { // 新しいテストボタン
                        resetForNewTest() // resetForNewTest()関数を呼び出して初期状態に戻す
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1)) // 薄い青色の背景
                    .cornerRadius(12)
                    .overlay( // 外枠線
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 1) // 青色の線
                    )
                }
                .padding(.horizontal) // 水平方向にパディング
            }
            .padding() // VStack全体にパディング
        }
    }
    
    // 現在のテストタイプに応じて、画面に表示する指示テキストを取得する関数
    private func getInstructionText(for testType: TestType) -> String {
        switch testType {
        case .phq9, .gad7: // PHQ-9とGAD-7の場合
            return "過去2週間で、以下の問題にどのくらい悩まされましたか？"
        case .k6, .k10: // K6とK10の場合
            return "過去30日間で、以下のことがどのくらいありましたか？"
        case .mutualLove: // 両思い診断の場合
            return "その人（特別な人）との関係について、以下の項目がどのくらい当てはまりますか？"
        case .romanticSign: // 脈あり診断の場合
            return "その人（気になる人）の行動や態度について、以下の項目がどのくらい当てはまりますか？"
        case .smartphoneBrain: // スマホ脳チェックの場合
            return "スマートフォンの使用について、以下の項目がどのくらい当てはまりますか？"
        case .stressCheck: // ストレスチェックの場合
            return "最近1ヶ月間のあなたの状態について、以下の項目がどのくらい当てはまりますか？"
        }
    }
    
    // 現在のテストタイプに応じて、質問リストを取得する関数
    private func getQuestions(for testType: TestType) -> [String] {
        switch testType {
        case .phq9: return phq9Questions
        case .gad7: return gad7Questions
        case .k6: return k6Questions
        case .k10: return k10Questions
        case .mutualLove: return mutualLoveQuestions
        case .romanticSign: return romanticSignQuestions
        case .smartphoneBrain: return smartphoneBrainQuestions
        case .stressCheck: return stressCheckQuestions
        }
    }
    
    // 現在のテストタイプに応じて、回答配列を取得する関数
    private func getAnswers(for testType: TestType) -> [Int] {
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
    private func getAnswerOptions(for testType: TestType) -> [String] {
        switch testType {
        case .phq9, .gad7: return answerOptions // PHQ-9, GAD-7は共通の選択肢
        case .k6, .k10: return k6k10Options // K6, K10は共通の選択肢
        case .mutualLove, .romanticSign: return loveAnswerOptions // 恋愛系は共通の選択肢
        case .smartphoneBrain: return smartphoneOptions // スマホ脳は独自の選択肢
        case .stressCheck: return stressOptions // ストレスチェックは独自の選択肢
        }
    }
    
    // 指定されたテストタイプ、質問インデックス、選択されたスコアで回答を更新する関数
    private func updateAnswer(for testType: TestType, index: Int, score: Int) {
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
    private var currentTest: TestType? {
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
    
    // PHQ-9テストの合計スコアを計算する計算プロパティ
    private var phq9Score: Int {
        phq9Answers.reduce(0, +) // 回答配列の要素を合計
    }
    
    // GAD-7テストの合計スコアを計算する計算プロパティ
    private var gad7Score: Int {
        gad7Answers.reduce(0, +)
    }
    
    // K6テストの合計スコアを計算する計算プロパティ
    private var k6Score: Int {
        k6Answers.reduce(0, +)
    }
    
    // K10テストの合計スコアを計算する計算プロパティ
    private var k10Score: Int {
        k10Answers.reduce(0, +)
    }
    
    // 両思い診断の合計スコアを計算する計算プロパティ
    private var mutualLoveScore: Int {
        mutualLoveAnswers.reduce(0, +)
    }
    
    // 脈あり診断の合計スコアを計算する計算プロパティ
    private var romanticSignScore: Int {
        romanticSignAnswers.reduce(0, +)
    }
    
    // スマホ脳チェックの合計スコアを計算する計算プロパティ
    private var smartphoneBrainScore: Int {
        smartphoneBrainAnswers.reduce(0, +)
    }
    
    // ストレスチェックの合計スコアを計算する計算プロパティ
    private var stressCheckScore: Int {
        stressCheckAnswers.reduce(0, +)
    }
    
    // PHQ-9スコアに基づいた解釈結果を返す計算プロパティ
    private var phq9Interpretation: String {
        switch phq9Score {
        case 0...4: return "軽微" // 0-4点: 軽微
        case 5...9: return "軽度" // 5-9点: 軽度
        case 10...14: return "中等度" // 10-14点: 中等度
        case 15...19: return "やや重度" // 15-19点: やや重度
        default: return "重度" // 20点以上: 重度
        }
    }
    
    // GAD-7スコアに基づいた解釈結果を返す計算プロパティ
    private var gad7Interpretation: String {
        switch gad7Score {
        case 0...4: return "軽微" // 0-4点: 軽微
        case 5...9: return "軽度" // 5-9点: 軽度
        case 10...14: return "中等度" // 10-14点: 中等度
        default: return "重度" // 15点以上: 重度
        }
    }
    
    // K6スコアに基づいた解釈結果を返す計算プロパティ
    private var k6Interpretation: String {
        switch k6Score {
        case 0...4: return "軽微" // 0-4点: 軽微
        case 5...9: return "軽度" // 5-9点: 軽度
        case 10...14: return "中等度" // 10-14点: 中等度
        case 15...19: return "やや重度" // 15-19点: やや重度
        default: return "重度" // 20点以上: 重度
        }
    }
    
    // K10スコアに基づいた解釈結果を返す計算プロパティ
    private var k10Interpretation: String {
        switch k10Score {
        case 0...7: return "軽微" // 0-7点: 軽微
        case 8...15: return "軽度" // 8-15点: 軽度
        case 16...24: return "中等度" // 16-24点: 中等度
        case 25...30: return "やや重度" // 25-30点: やや重度
        default: return "重度" // 31点以上: 重度
        }
    }
    
    // 両思い診断スコアに基づいた解釈結果を返す計算プロパティ
    private var mutualLoveInterpretation: String {
        switch mutualLoveScore {
        case 0...10: return "友情関係" // 0-10点: 友情関係
        case 11...20: return "好意的関係" // 11-20点: 好意的関係
        case 21...30: return "恋愛関係" // 21-30点: 恋愛関係
        case 31...40: return "両思い" // 31-40点: 両思い
        default: return "測定不能" // それ以外: 測定不能
        }
    }
    
    // 脈あり診断スコアに基づいた解釈結果を返す計算プロパティ
    private var romanticSignInterpretation: String {
        switch romanticSignScore {
        case 0...10: return "脈なし" // 0-10点: 脈なし
        case 11...20: return "友達レベル" // 11-20点: 友達レベル
        case 21...30: return "好意あり" // 21-30点: 好意あり
        case 31...40: return "脈あり" // 31-40点: 脈あり
        default: return "測定不能" // それ以外: 測定不能
        }
    }
    
    // スマホ脳チェックスコアに基づいた解釈結果を返す計算プロパティ
    private var smartphoneBrainInterpretation: String {
        switch smartphoneBrainScore {
        case 0...12: return "健康的" // 0-12点: 健康的
        case 13...24: return "軽度の影響" // 13-24点: 軽度の影響
        case 25...36: return "中等度の影響" // 25-36点: 中等度の影響
        case 37...48: return "重度の影響" // 37-48点: 重度の影響
        default: return "測定不能" // それ以外: 測定不能
        }
    }
    
    // ストレスチェックスコアに基づいた解釈結果を返す計算プロパティ
    private var stressCheckInterpretation: String {
        switch stressCheckScore {
        case 0...20: return "低ストレス" // 0-20点: 低ストレス
        case 21...40: return "軽度ストレス" // 21-40点: 軽度ストレス
        case 41...60: return "中等度ストレス" // 41-60点: 中等度ストレス
        case 61...80: return "高ストレス" // 61-80点: 高ストレス
        default: return "測定不能" // それ以外: 測定不能
        }
    }
    
    // 両思い診断スコアに基づいた詳細な説明文を返す計算プロパティ
    private var mutualLoveDescription: String {
        switch mutualLoveScore {
        case 0...10: return "現在は友情関係のようです。お互いを大切な友達として関係を築いていくことが大切です。"
        case 11...20: return "お互いに好意を持っている関係のようです。時間をかけて関係を深めていくことで、より特別な関係になるかもしれません。"
        case 21...30: return "恋愛関係として成長している段階のようです。お互いの気持ちを確かめ合いながら関係を大切にしていきましょう。"
        case 31...40: return "両思いの関係のようです。お互いを大切に思い合う素晴らしい関係を築いていてください。"
        default: return "" // スコアが範囲外の場合、空文字列を返す
        }
    }
    
    // 脈あり診断スコアに基づいた詳細な説明文を返す計算プロパティ
    private var romanticSignDescription: String {
        switch romanticSignScore {
        case 0...10: return "残念ながら、相手からの恋愛的な好意のサインはあまり見られません。しかし、良い関係を築くことはできるでしょう。"
        case 11...20: return "相手はあなたを良い友達として見ているようです。時間をかけて関係を深めることで、変化があるかもしれません。"
        case 21...30: return "相手はあなたに対して好意を持っているようです。積極的にコミュニケーションを取ることをお勧めします。"
        case 31...40: return "相手はあなたに対して恋愛感情を抱いている可能性が高いです。自信を持って関係を深めてみましょう。"
        default: return ""
        }
    }
    
    // スマホ脳チェックスコアに基づいた詳細な説明文を返す計算プロパティ
    private var smartphoneBrainDescription: String {
        switch smartphoneBrainScore {
        case 0...12: return "スマートフォンを適切に使用できています。現在の使用習慣を維持しましょう。"
        case 13...24: return "スマートフォンの使用に軽度の問題があります。使用時間を意識して調整することをお勧めします。"
        case 25...36: return "スマートフォンの使用が生活に中等度の影響を与えています。デジタルデトックスを検討してみましょう。"
        case 37...48: return "スマートフォンの使用が深刻な影響を与えています。専門家への相談や本格的な使用制限を検討することをお勧めします。"
        default: return ""
        }
    }
    
    // ストレスチェックスコアに基づいた詳細な説明文を返す計算プロパティ
    private var stressCheckDescription: String {
        switch stressCheckScore {
        case 0...20: return "現在のストレスレベルは低く、良好な状態です。現在の生活習慣を維持しましょう。"
        case 21...40: return "軽度のストレスがあります。適度な休息とリラクゼーションを心がけましょう。"
        case 41...60: return "中等度のストレスがあります。ストレス管理の方法を見直し、必要に応じて専門家に相談しましょう。"
        case 61...80: return "高いストレスレベルです。早急にストレス軽減策を講じ、専門家への相談を強くお勧めします。職場や家庭環境の見直しも検討しましょう。"
        default: return ""
        }
    }
    
    // PHQ-9スコアに基づいた結果の色を返す計算プロパティ
    private var phq9Color: Color {
        switch phq9Score {
        case 0...4: return .green // 軽微
        case 5...9: return .yellow // 軽度
        case 10...14: return .orange // 中等度
        default: return .red // やや重度以上
        }
    }
    
    // GAD-7スコアに基づいた結果の色を返す計算プロパティ
    private var gad7Color: Color {
        switch gad7Score {
        case 0...4: return .green
        case 5...9: return .yellow
        case 10...14: return .orange
        default: return .red
        }
    }
    
    // K6スコアに基づいた結果の色を返す計算プロパティ
    private var k6Color: Color {
        switch k6Score {
        case 0...4: return .green
        case 5...9: return .yellow
        case 10...14: return .orange
        default: return .red
        }
    }
    
    // K10スコアに基づいた結果の色を返す計算プロパティ
    private var k10Color: Color {
        switch k10Score {
        case 0...7: return .green // 軽微
        case 8...15: return .yellow // 軽度
        case 16...24: return .orange // 中等度
        default: return .red // やや重度以上
        }
    }
    
    // 選択されたテストを開始する関数
    private func startSelectedTests() {
        // selectedTestsのセットから要素を配列に変換し、testQueueに設定
        testQueue = Array(selectedTests)
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
    }
    
    // 診断結果をSwiftDataに保存する関数
    private func saveAssessment() {
        let assessment = MentalHealthAssessment() // 新しいMentalHealthAssessmentインスタンスを作成
        // 選択されたテストの種類を文字列配列に変換して保存
        assessment.selectedTests = selectedTests.map { $0.rawValue }
        // 各テストが完了したかどうかを保存
        assessment.isPhq9Completed = selectedTests.contains(.phq9)
        assessment.isGad7Completed = selectedTests.contains(.gad7)
        
        // 各テストが選択されている場合、そのスコアと回答を保存
        if selectedTests.contains(.phq9) {
            assessment.phq9Score = phq9Score // PHQ-9スコアを保存
            assessment.phq9Answers = phq9Answers // PHQ-9回答を保存
        }
        
        if selectedTests.contains(.gad7) {
            assessment.gad7Score = gad7Score // GAD-7スコアを保存
            assessment.gad7Answers = gad7Answers // GAD-7回答を保存
        }
        
        // 各テストの結果をメモに追加（スコアと解釈結果）
        if selectedTests.contains(.k6) {
            assessment.notes += "K6スコア: \(k6Score)/24 (\(k6Interpretation))\n"
        }
        
        if selectedTests.contains(.k10) {
            assessment.notes += "K10スコア: \(k10Score)/40 (\(k10Interpretation))\n"
        }
        
        if selectedTests.contains(.mutualLove) {
            assessment.notes += "両思い診断スコア: \(mutualLoveScore)/40 (\(mutualLoveInterpretation))\n"
        }
        
        if selectedTests.contains(.romanticSign) {
            assessment.notes += "脈あり診断スコア: \(romanticSignScore)/40 (\(romanticSignInterpretation))\n"
        }
        
        if selectedTests.contains(.smartphoneBrain) {
            assessment.notes += "スマホ脳チェックスコア: \(smartphoneBrainScore)/48 (\(smartphoneBrainInterpretation))\n"
        }
        
        if selectedTests.contains(.stressCheck) {
            assessment.notes += "ストレスチェックスコア: \(stressCheckScore)/80 (\(stressCheckInterpretation))\n"
        }
        
        context.insert(assessment) // 作成したassessmentオブジェクトをSwiftDataコンテキストに挿入
        do {
            try context.save() // コンテキストの変更をデータベースに保存
            print("✅ 診断結果を保存しました") // 保存成功メッセージをコンソールに出力
        } catch {
            print("❌ 保存エラー: \(error)") // 保存エラーが発生した場合、エラーメッセージをコンソールに出力
        }
    }
}

// テスト選択カードのカスタムビュー
struct TestSelectionCard: View {
    let testType: MentalHealthCheckView.TestType // 表示するテストの種類
    let isSelected: Bool // 選択されているかどうかの状態
    let onTap: () -> Void // タップされた時のアクション
    
    var body: some View {
        Button(action: onTap) { // ボタンとして機能し、タップ時にonTapクロージャを実行
            VStack(alignment: .leading, spacing: 16) {
                HStack { // 表示名と説明文
                    VStack(alignment: .leading, spacing: 4) {
                        Text(testType.displayName) // テストの表示名
                            .font(.headline.bold()) // 太字の見出しフォント
                            .foregroundColor(.primary) // プライマリテキストカラー
                        
                        Text(testType.description) // テストの説明文
                            .font(.subheadline) // サブヘッダフォント
                            .foregroundColor(.secondary) // 二次テキストカラー
                    }
                    
                    Spacer() // 右端に寄せる
                    
                    // 選択状態に応じてチェックマークアイコンを表示
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2) // タイトル2サイズのフォント
                        .foregroundColor(isSelected ? testType.color : .secondary) // 選択時はテストの色、未選択時は二次色
                }
                
                HStack { // カテゴリと質問数
                    Label(testType.category, systemImage: testType.systemIcon) // カテゴリ名とアイコン
                        .font(.caption) // キャプションフォント
                        .foregroundColor(testType.color) // カテゴリの色
                    
                    Spacer() // 右端に寄せる
                    
                    Text(testType.questionCount) // 質問数
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding() // カード内部のパディング
            .background( // 背景設定
                RoundedRectangle(cornerRadius: 12) // 角丸の背景
                    .fill(isSelected ? testType.color.opacity(0.1) : Color(.systemGray6)) // 選択時はテストの色を薄く、未選択時はシステムグレー6
            )
            .overlay( // カードの縁取り
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? testType.color : .clear, lineWidth: 2) // 選択時はテストの色で、太さ2の線、未選択時は線なし
            )
            .scaleEffect(isSelected ? 1.02 : 1.0) // 選択時は少し拡大
            .animation(.easeInOut(duration: 0.15), value: isSelected) // 選択状態の変化にアニメーションを適用
        }
        .buttonStyle(PlainButtonStyle()) // ボタンのデフォルトスタイルを無効化
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

// 結果カードのカスタムビュー（PHQ-9, GAD-7などの一般的な結果表示用）
struct ResultCard: View {
    let title: String // カードのタイトル
    let score: Int // ユーザーのスコア
    let maxScore: Int // 最大スコア
    let interpretation: String // スコアの解釈結果
    let color: Color // 結果の色
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title) // タイトル
                .font(.headline.bold()) // 太字の見出しフォント
            
            Text("\(score)/\(maxScore)") // スコア表示
                .font(.title.bold()) // 太字のタイトルフォント
                .foregroundColor(color) // 結果の色
            
            Text(interpretation) // 解釈結果
                .font(.subheadline)
                .padding(.horizontal, 16) // 水平パディング
                .padding(.vertical, 8) // 垂直パディング
                .background(color.opacity(0.2)) // 結果の色を薄めた背景
                .cornerRadius(20) // 角丸
        }
        .frame(maxWidth: .infinity) // 幅を最大に
        .padding() // カード内部パディング
        .background(.thinMaterial) // 半透明の背景
        .cornerRadius(16) // 角丸
        .overlay( // カードの縁取り
            RoundedRectangle(cornerRadius: 16)
                .stroke(color, lineWidth: 2) // 結果の色で太さ2の線
        )
    }
}

// 恋愛診断の結果カードカスタムビュー
struct LoveResultCard: View {
    let title: String
    let score: Int
    let maxScore: Int
    let interpretation: String
    let description: String // 詳細な説明文
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline.bold())
            
            Text("\(score)/\(maxScore)")
                .font(.title.bold())
                .foregroundColor(color)
            
            Text(interpretation)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color.opacity(0.2))
                .cornerRadius(20)
            
            Text(description) // 詳細な説明文を表示
                .font(.body)
                .multilineTextAlignment(.center) // 中央揃え
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color, lineWidth: 2)
        )
    }
}

// デジタル健康診断の結果カードカスタムビュー
struct DigitalHealthResultCard: View {
    let title: String
    let score: Int
    let maxScore: Int
    let interpretation: String
    let description: String // 詳細な説明文
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline.bold())
            
            Text("\(score)/\(maxScore)")
                .font(.title.bold())
                .foregroundColor(color)
            
            Text(interpretation)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color.opacity(0.2))
                .cornerRadius(20)
            
            Text(description) // 詳細な説明文を表示
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color, lineWidth: 2)
        )
    }
}

// ストレスチェックの結果カードカスタムビュー
struct StressResultCard: View {
    let title: String
    let score: Int
    let maxScore: Int
    let interpretation: String
    let description: String // 詳細な説明文
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline.bold())
            
            Text("\(score)/\(maxScore)")
                .font(.title.bold())
                .foregroundColor(color)
            
            Text(interpretation)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color.opacity(0.2))
                .cornerRadius(20)
            
            Text(description) // 詳細な説明文を表示
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color, lineWidth: 2)
        )
    }
}

// 専門的なアドバイスを表示するビュー
struct ProfessionalAdviceView: View {
    // オプショナルなスコア値
    let phq9Score: Int?
    let gad7Score: Int?
    let k6Score: Int?
    let k10Score: Int?
    
    // アドバイスのテキストを計算するプライベートプロパティ
    private var advice: String {
        // 各テストで中等度以上のスコアかどうかを判定
        let phq9High = (phq9Score ?? 0) >= 10
        let gad7High = (gad7Score ?? 0) >= 10
        let k6High = (k6Score ?? 0) >= 10
        let k10High = (k10Score ?? 0) >= 16
        
        // 各テストで軽度のスコアかどうかを判定
        let phq9Mild = (phq9Score ?? 0) >= 5
        let gad7Mild = (gad7Score ?? 0) >= 5
        let k6Mild = (k6Score ?? 0) >= 5
        let k10Mild = (k10Score ?? 0) >= 8
        
        if phq9High || gad7High || k6High || k10High { // いずれかが中等度以上の場合
            return "スコアが中等度以上です。専門家（精神科医、心理カウンセラー）への相談を強くお勧めします。一人で抱え込まず、適切なサポートを受けることが重要です。"
        } else if phq9Mild || gad7Mild || k6Mild || k10Mild { // いずれかが軽度の場合
            return "軽度の症状が認められます。セルフケアを心がけ、症状が続く場合は専門家にご相談ください。"
        } else { // すべて軽微またはスコアがない場合
            return "現在の状態は良好のようです。引き続き心の健康を維持するためのセルフケアを続けましょう。"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("専門的なアドバイス")
                .font(.headline.bold())
            
            Text(advice) // 計算されたアドバイスを表示
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 幅を最大にし、左揃え
        .padding()
        .background(Color.blue.opacity(0.1)) // 背景色
        .cornerRadius(12) // 角丸
    }
}

// 恋愛アドバイスを表示するビュー
struct LoveAdviceView: View {
    // オプショナルなスコア値
    let mutualLoveScore: Int?
    let romanticSignScore: Int?
    
    // アドバイスのテキストを計算するプライベートプロパティ
    private var advice: String {
        let hasMutualLoveScore = mutualLoveScore != nil // 両思い診断スコアがあるか
        let hasRomanticSignScore = romanticSignScore != nil // 脈あり診断スコアがあるか
        
        if hasMutualLoveScore && hasRomanticSignScore { // 両方のスコアがある場合
            let mutual = mutualLoveScore ?? 0
            let sign = romanticSignScore ?? 0
            
            if mutual >= 31 && sign >= 31 { // 両方とも高スコアの場合
                return "両思い診断と脈あり診断の両方で高スコアです。お互いに深い愛情を抱いている素晴らしい関係のようです。"
            } else if mutual >= 21 && sign >= 21 { // 両方とも中程度以上のスコアの場合
                return "お互いに恋愛感情を抱いており、良好な関係を築いているようです。この関係を大切に育んでください。"
            } else { // それ以外の場合
                return "関係は発展途上のようです。時間をかけて相手との絆を深めていくことが大切です。"
            }
        } else if hasMutualLoveScore { // 両思い診断スコアのみある場合
            return "両思い診断の結果から、関係の現在地が見えてきました。お互いを大切にする気持ちを持ち続けてください。"
        } else if hasRomanticSignScore { // 脈あり診断スコアのみある場合
            return "脈あり診断の結果から、相手の気持ちが推測できました。一つの参考として、自分の気持ちと向き合ってみてください。"
        }
        
        return "恋愛は人それぞれ。あなたらしさを大切にしながら、素敵な関係を築いていってください。" // どのスコアもない場合
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("恋愛アドバイス")
                .font(.headline.bold())
            
            Text(advice) // 計算されたアドバイスを表示
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.pink.opacity(0.1)) // 背景色
        .cornerRadius(12)
    }
}

// デジタル健康アドバイスを表示するビュー
struct DigitalHealthAdviceView: View {
    let smartphoneBrainScore: Int // スマホ脳チェックのスコア
    
    // アドバイスのテキストを計算するプライベートプロパティ
    private var advice: String {
        switch smartphoneBrainScore {
        case 0...12: // 低スコアの場合
            return "素晴らしい！健康的なスマートフォン使用を継続してください。現在の使用習慣を維持し、定期的にデジタルデトックスを行いましょう。"
        case 13...24: // 軽度影響の場合
            return "軽度の影響が見られます。使用時間の制限、就寝前の使用を控える、集中時間にはスマートフォンを別の場所に置くなどの対策を検討しましょう。"
        case 25...36: // 中等度影響の場合
            return "中等度の影響があります。アプリの使用時間制限機能を活用し、定期的なデジタルデトックスを実践し、リアルな活動を増やすことをお勧めします。"
        case 37...48: // 重度影響の場合
            return "深刻な影響が見られます。専門家への相談を検討し、段階的な使用制限、代替活動の充実、家族や友人のサポートを求めることをお勧めします。"
        default: // その他の場合
            return "スマートフォンとの健康的な関係を築くことが重要です。"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("デジタル健康アドバイス")
                .font(.headline.bold())
            
            Text(advice) // 計算されたアドバイスを表示
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.1)) // 背景色
        .cornerRadius(12)
    }
}

// ストレス管理アドバイスを表示するビュー
struct StressAdviceView: View {
    let stressScore: Int // ストレスチェックのスコア
    
    // アドバイスのテキストを計算するプライベートプロパティ
    private var advice: String {
        switch stressScore {
        case 0...20: // 低ストレスの場合
            return "素晴らしい！現在のストレスレベルは低く、良好な状態です。現在の生活習慣やストレス管理方法を維持してください。"
        case 21...40: // 軽度ストレスの場合
            return "軽度のストレスがあります。定期的な運動、十分な睡眠、リラクゼーション活動を取り入れて、ストレスを適切に管理しましょう。"
        case 41...60: // 中等度ストレスの場合
            return "中等度のストレスがあります。ストレス源の特定、時間管理の改善、サポートシステムの活用、必要に応じて専門家への相談を検討しましょう。"
        case 61...80: // 高ストレスの場合
            return "高いストレスレベルです。早急にストレス軽減策を講じ、専門家（カウンセラー、医師）への相談を強くお勧めします。職場や家庭環境の見直しも検討しましょう。"
        default: // その他の場合
            return "ストレスとの上手な付き合い方を身につけることが重要です。"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ストレス管理アドバイス")
                .font(.headline.bold())
            
            Text(advice) // 計算されたアドバイスを表示
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.green.opacity(0.1)) // 背景色
        .cornerRadius(12)
    }
}

// 相談窓口やリソースのリンクを表示するビュー
struct ConsultationResourcesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("相談窓口・リソース")
                .font(.headline.bold())
            
            // 電話相談へのリンク
            Link("こころの健康相談統一ダイヤル（0570-064-556）", destination: URL(string: "tel:0570064556")!)
                .foregroundColor(.blue)
            
            Link("いのちの電話（0570-783-556）", destination: URL(string: "tel:0570783556")!)
                .foregroundColor(.blue)
            
            // 緊急時の注意喚起
            Text("※緊急時は迷わず119番または最寄りの救急外来を受診してください")
                .font(.caption)
                .foregroundColor(.red) // 赤色で強調
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.1)) // 背景色
        .cornerRadius(12)
    }
}

// 医療免責事項を表示するビュー
struct DisclaimerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill") // 注意喚起アイコン
                Text("【重要】医療免責事項") // タイトル
            }
            .font(.headline) // 見出しフォント
            .foregroundColor(.orange) // オレンジ色
            
            // 免責事項の本文
            Text("このセルフチェックは医学的診断に代わるものではありません。結果にかかわらず、心の不調が続く場合や日常生活に支障がある場合は、必ず医師やカウンセラーなどの専門家にご相談ください。")
                .font(.caption) // キャプションフォント
        }
        .padding() // パディング
        .background(Color.orange.opacity(0.1)) // 背景色
        .cornerRadius(10) // 角丸
        .padding(.horizontal) // 水平方向のパディング
    }
}

