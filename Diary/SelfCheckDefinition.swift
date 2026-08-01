import SwiftData
import SwiftUI

/// セルフチェック画面で扱うチェックの識別子と、表示に必要な不変メタデータ。
///
/// 利用可否や根拠レベルの見直しは Safety / Self-check Issue で行う。
/// この型は既存画面の挙動を変えず、巨大Viewから定義責務だけを切り離す。
enum SelfCheckType: String, CaseIterable, Hashable {
    case phq9 = "PHQ-9"
    case gad7 = "GAD-7"
    case k6 = "K6"
    case k10 = "K10"
    case mutualLove = "関係性を振り返る"
    case romanticSign = "やりとりを振り返る"
    case smartphoneBrain = "スマホとの付き合い方を振り返る"
    case stressCheck = "職場向けストレスチェック（停止中）"

    static let guidedReflectionTypes: [SelfCheckType] = [
        .mutualLove,
        .romanticSign,
        .smartphoneBrain
    ]

    var displayName: String {
        switch self {
        case .phq9: return "抑うつ症状チェック（PHQ-9）"
        case .gad7: return "不安症状チェック（GAD-7）"
        case .k6: return "心理的苦痛チェック（K6）"
        case .k10: return "心理的苦痛チェック（K10）"
        case .mutualLove: return "関係性を振り返る"
        case .romanticSign: return "やりとりを振り返る"
        case .smartphoneBrain: return "スマホとの付き合い方を振り返る"
        case .stressCheck: return "職場向けストレスチェック（停止中）"
        }
    }

    var description: String {
        switch self {
        case .phq9, .gad7, .k6, .k10:
            return "標準化された質問票のため、現在は新規実行を停止しています。"
        case .mutualLove:
            return "相手の気持ちを決めつけず、自分が感じた出来事を振り返ります（10問）"
        case .romanticSign:
            return "やりとりの中で自分が気づいたことを振り返ります（10問）"
        case .smartphoneBrain:
            return "使った場面や、その後の自分の感覚を振り返ります（12問）"
        case .stressCheck:
            return "職場向けの標準化チェックのため、現在は新規実行を停止しています。"
        }
    }

    var definition: SelfCheckDefinition {
        SelfCheckDefinitionCatalog.definition(for: self)
    }

    var isPaused: Bool {
        !definition.availability.isAvailable
    }

    var pauseReason: String? {
        definition.availability.reason
    }

    /// 危機項目への回答を含む尺度だけが、安全確認を先に必要とする。
    ///
    /// 現在は全標準尺度が停止中のため、この経路は実行されない。
    var requiresSafetyGate: Bool {
        self == .phq9
    }

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

    var category: String {
        switch self {
        case .phq9, .gad7, .k6, .k10: return "メンタルヘルス"
        case .mutualLove, .romanticSign: return "関係性"
        case .smartphoneBrain: return "スマホ利用"
        case .stressCheck: return "ストレス"
        }
    }

    var questionCount: String {
        "\(SelfCheckCatalog.questions(for: self).count)問"
    }

    var systemIcon: String {
        switch category {
        case "メンタルヘルス": return "heart.text.square"
        case "関係性": return "heart.fill"
        case "スマホ利用": return "iphone"
        case "ストレス": return "gauge.high"
        default: return "questionmark.circle"
        }
    }

    var lineIconKind: DiaryLineIconKind {
        switch self {
        case .phq9, .gad7, .k6, .k10: return .journal
        case .mutualLove, .romanticSign: return .cloudSun
        case .smartphoneBrain: return .smallSun
        case .stressCheck: return .cloud
        }
    }
}

/// 質問文、回答選択肢、案内文を一元化するローカルカタログ。
///
/// 文面の根拠監査は別Issueで行うため、ここでは既存値をそのまま移している。
enum SelfCheckCatalog {
    static func questions(for type: SelfCheckType) -> [String] {
        switch type {
        case .phq9:
            return [
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
        case .gad7:
            return [
                "神経質になったり、不安になったり、イライラしたりする",
                "心配するのを止めることができない、またはコントロールできない",
                "さまざまなことを心配しすぎる",
                "リラックスすることが困難",
                "じっとしていられないほど落ち着かない",
                "容易にいらだったり、イライラしたりする",
                "何か恐ろしいことが起こるのではないかと恐怖を感じる"
            ]
        case .k6:
            return [
                "神経過敏に感じましたか",
                "絶望的だと感じましたか",
                "そわそわ、落ち着かなく感じましたか",
                "気分が沈み込んで、何が起こっても気が晴れないように感じましたか",
                "何をするのも骨折りだと感じましたか",
                "自分は価値のない人間だと感じましたか"
            ]
        case .k10:
            return [
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
        case .mutualLove:
            return [
                "一緒にいるとき、自分は安心して話せた",
                "自分の希望や困っていることを伝えられた",
                "相手の話を、決めつけずに聞けた",
                "無理をせず、自分らしくいられる時間があった",
                "連絡の頻度や方法について、自分の希望を伝えられた",
                "嫌なことや境界線を言葉にできた",
                "意見が違うときも、落ち着いて話せた",
                "自分の好きなことや大切なことを共有できた",
                "やりとりの後、自分は尊重されたと感じた",
                "この関係で大切にしたいことを考えられた"
            ]
        case .romanticSign:
            return [
                "会話の中で、目が合うことがあった",
                "自分が送った連絡に返事があった",
                "二人で話す時間があった",
                "以前話した内容が、別の会話でも話題になった",
                "友人や知人を含めて、一緒に話す機会があった",
                "自分の服装や持ち物について言葉を交わした",
                "困った場面で、助けを申し出てもらったことがあった",
                "冗談や楽しかったことを共有した",
                "一緒に過ごす予定について話した",
                "これからの予定について言葉を交わした"
            ]
        case .smartphoneBrain:
            return [
                "手元にないとき、気になったことがある",
                "通知に気づいて、すぐ確認したことがある",
                "食事や会話の途中で画面を見たことがある",
                "眠る直前まで画面を見たことがある",
                "持っていないことに気づいて、不安を感じたことがある",
                "集中したい場面で、画面が気になったことがある",
                "予定より長く使ったと感じたことがある",
                "歩きながら画面を見たことがある",
                "同じサービスを短い間隔で何度も確認したことがある",
                "使い終えたいと思った後も、続けて使ったことがある",
                "画面を見た後、眠る時間が遅くなったことがある",
                "画面を見た後、目や体の疲れを感じたことがある"
            ]
        case .stressCheck:
            return [
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
        }
    }

    static func answerOptions(for type: SelfCheckType) -> [String] {
        switch type {
        case .phq9, .gad7:
            return ["全くない", "数日", "半分以上", "ほぼ毎日"]
        case .k6, .k10:
            return ["全くない", "少しだけ", "時々", "たいてい", "いつも"]
        case .mutualLove, .romanticSign:
            return ["全くない", "たまに", "よくある", "いつも"]
        case .smartphoneBrain:
            return ["全くない", "たまに", "よく", "いつも"]
        case .stressCheck:
            return ["そうだ", "まあそうだ", "やや違う", "違う"]
        }
    }

    static func instruction(for type: SelfCheckType) -> String {
        switch type {
        case .phq9, .gad7:
            return "過去2週間で、以下の問題にどのくらい悩まされましたか？"
        case .k6, .k10:
            return "過去30日間で、以下のことがどのくらいありましたか？"
        case .mutualLove:
            return "最近の関係の中で、自分が実際に経験したことを振り返ります。相手の気持ちは推測しません。"
        case .romanticSign:
            return "最近のやりとりで、実際にあった出来事だけを振り返ります。相手の意図や関係性を判定するものではありません。"
        case .smartphoneBrain:
            return "最近のスマートフォン利用で、自分が気づいた場面を振り返ります。良し悪しや健康状態は判定しません。"
        case .stressCheck:
            return "最近1ヶ月間のあなたの状態について、以下の項目がどのくらい当てはまりますか？"
        }
    }
}

/// 現在停止中の標準尺度だけを識別する型。
/// 独自の振り返りを誤って採点APIへ渡せないよう、SelfCheckTypeとは分離する。
enum StandardizedSelfCheckType {
    case phq9
    case gad7
    case k6
    case k10
    case stressCheck
}

/// 標準尺度の既存採点をUIや永続化から隔離した純粋関数群。
/// 新規実行は、根拠・利用条件・安全導線の検証が終わるまで停止している。
enum SelfCheckScoring {
    static func total(_ answers: [Int]) -> Int {
        answers.reduce(0, +)
    }

    static func interpretation(for type: StandardizedSelfCheckType, score: Int) -> String {
        switch type {
        case .phq9, .k6:
            switch score {
            case 0...4: return "軽微"
            case 5...9: return "軽度"
            case 10...14: return "中等度"
            case 15...19: return "やや重度"
            default: return "重度"
            }
        case .gad7:
            switch score {
            case 0...4: return "軽微"
            case 5...9: return "軽度"
            case 10...14: return "中等度"
            default: return "重度"
            }
        case .k10:
            switch score {
            case 0...7: return "軽微"
            case 8...15: return "軽度"
            case 16...24: return "中等度"
            case 25...30: return "やや重度"
            default: return "重度"
            }
        case .stressCheck:
            switch score {
            case 0...20: return "気づきは少なめ"
            case 21...40: return "いくつか気づきあり"
            case 41...60: return "負担を振り返る材料あり"
            case 61...80: return "相談や休息を考える材料あり"
            default: return "記録を確認"
            }
        }
    }

}

/// 画面の入力状態を、SwiftDataモデルへ直接書き込む前に隔離する値型。
struct SelfCheckResultDraft {
    var selectedTests: Set<SelfCheckType>
    var phq9Answers: [Int]
    var gad7Answers: [Int]
    var k6Answers: [Int]
    var k10Answers: [Int]
    var mutualLoveAnswers: [Int]
    var romanticSignAnswers: [Int]
    var smartphoneBrainAnswers: [Int]
    var stressCheckAnswers: [Int]

    func answers(for type: SelfCheckType) -> [Int] {
        switch type {
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
}

enum SelfCheckSaveError: Error, Equatable {
    case noSelection
    case unavailableTypes([SelfCheckType])
}

/// セルフチェック結果のSwiftData書き込みだけを担当する。
@MainActor
struct MentalHealthAssessmentSaveService {
    var persist: (ModelContext) throws -> Void = { context in
        try context.save()
    }

    @discardableResult
    func save(
        draft: SelfCheckResultDraft,
        in context: ModelContext
    ) throws -> MentalHealthAssessment {
        guard !draft.selectedTests.isEmpty else {
            throw SelfCheckSaveError.noSelection
        }

        let unavailable = draft.selectedTests
            .filter { !$0.definition.availability.isAvailable }
            .sorted { $0.rawValue < $1.rawValue }
        guard unavailable.isEmpty else {
            throw SelfCheckSaveError.unavailableTypes(unavailable)
        }

        let assessment = MentalHealthAssessment()
        let selectedTypes = draft.selectedTests.sorted { $0.rawValue < $1.rawValue }
        assessment.selectedTests = selectedTypes.map(\.rawValue)
        assessment.isPhq9Completed = draft.selectedTests.contains(.phq9)
        assessment.isGad7Completed = draft.selectedTests.contains(.gad7)
        if draft.selectedTests.contains(.phq9) {
            assessment.phq9Answers = draft.phq9Answers
            assessment.phq9Score = SelfCheckScoring.total(draft.phq9Answers)
        }
        if draft.selectedTests.contains(.gad7) {
            assessment.gad7Answers = draft.gad7Answers
            assessment.gad7Score = SelfCheckScoring.total(draft.gad7Answers)
        }
        assessment.notes = selectedTypes
            .map { type in
                SelfCheckSession(type: type, answers: draft.answers(for: type))
                    .makeResult()
                    .factualSummary
            }
            .joined(separator: "\n")

        context.insert(assessment)

        do {
            try persist(context)
            return assessment
        } catch {
            context.delete(assessment)
            throw error
        }
    }

}
