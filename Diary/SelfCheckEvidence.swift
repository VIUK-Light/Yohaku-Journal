import Foundation

/// チェックの根拠の位置づけ。結果の良し悪しや重症度ではない。
enum EvidenceLevel: String, CaseIterable, Equatable {
    case standardizedInstrument
    case guidedReflection

    var title: String {
        switch self {
        case .standardizedInstrument: return "標準尺度"
        case .guidedReflection: return "独自の振り返り"
        }
    }

    var explanation: String {
        switch self {
        case .standardizedInstrument:
            return "原典、対象年齢、採点、利用条件、危機対応を確認してから提供する必要があります。"
        case .guidedReflection:
            return "医療的な診断や心理尺度ではなく、自分が選んだ回答を事実として見返すための問いです。"
        }
    }
}

enum SelfCheckVerificationRequirement: String, CaseIterable, Hashable {
    case originalSource = "原典と日本語版の出典"
    case intendedAge = "対象年齢"
    case responsePeriod = "回答期間"
    case scoring = "採点方法とテストベクトル"
    case usageRights = "利用・転載条件"
    case crisisFlow = "危機回答時の導線"
    case appropriateReview = "臨床表現の適切なレビュー"
}

enum SelfCheckAvailability: Equatable {
    case available
    case verificationRequired(Set<SelfCheckVerificationRequirement>)

    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    var shortLabel: String {
        switch self {
        case .available: return "利用できます"
        case .verificationRequired: return "根拠と安全性を検証中"
        }
    }

    var reason: String? {
        switch self {
        case .available:
            return nil
        case .verificationRequired(let requirements):
            let missing = SelfCheckVerificationRequirement.allCases
                .filter(requirements.contains)
                .map(\.rawValue)
                .joined(separator: "、")
            return "確認が必要な項目: \(missing)"
        }
    }
}

struct SelfCheckDefinition {
    let type: SelfCheckType
    let evidenceLevel: EvidenceLevel
    let availability: SelfCheckAvailability
    let intendedAudience: String
    let responsePeriod: String
    let sourceStatus: String
    let resultGuidance: String
}

enum SelfCheckDefinitionCatalog {
    private static let requiredVerification = Set(SelfCheckVerificationRequirement.allCases)

    static func definition(for type: SelfCheckType) -> SelfCheckDefinition {
        switch type {
        case .phq9, .gad7, .k6, .k10, .stressCheck:
            return SelfCheckDefinition(
                type: type,
                evidenceLevel: .standardizedInstrument,
                availability: .verificationRequired(requiredVerification),
                intendedAudience: "現在確認中",
                responsePeriod: "現在確認中",
                sourceStatus: "出典・採点・利用条件・安全導線の確認が完了していません。",
                resultGuidance: "必要な確認が終わるまで、新しい回答や結果は作成しません。"
            )
        case .mutualLove:
            return SelfCheckDefinition(
                type: type,
                evidenceLevel: .guidedReflection,
                availability: .available,
                intendedAudience: "自分の出来事を振り返りたい人",
                responsePeriod: "最近気づいた出来事",
                sourceStatus: "独自の振り返りであり、診断尺度ではありません。",
                resultGuidance: "この記録は相手の気持ちや関係の答えではありません。自分が安心できた場面や、伝えたいことを整理する材料として使えます。"
            )
        case .romanticSign:
            return SelfCheckDefinition(
                type: type,
                evidenceLevel: .guidedReflection,
                availability: .available,
                intendedAudience: "自分の出来事を振り返りたい人",
                responsePeriod: "最近気づいた出来事",
                sourceStatus: "独自の振り返りであり、診断尺度ではありません。",
                resultGuidance: "相手の考えや気持ちは、この記録から決められません。実際にあったやりとりと、自分がどう感じたかを分けて眺めるために使えます。"
            )
        case .smartphoneBrain:
            return SelfCheckDefinition(
                type: type,
                evidenceLevel: .guidedReflection,
                availability: .available,
                intendedAudience: "自分の出来事を振り返りたい人",
                responsePeriod: "最近気づいた出来事",
                sourceStatus: "独自の振り返りであり、診断尺度ではありません。",
                resultGuidance: "この記録は使い方の良し悪しや健康状態を判定しません。眠り、集中、人との時間など、自分が大切にしたいこととの関係を眺めるために使えます。"
            )
        }
    }
}

struct SelfCheckResponseCount: Identifiable, Equatable {
    let label: String
    let count: Int

    var id: String { label }
}

/// 点数や重症度を持たず、利用者が選んだ回答の件数だけを表す。
struct SelfCheckResult: Equatable {
    let type: SelfCheckType
    let answeredCount: Int
    let totalQuestionCount: Int
    let responseCounts: [SelfCheckResponseCount]

    var unansweredCount: Int {
        max(0, totalQuestionCount - answeredCount)
    }

    /// 保存用の事実ベース要約。合計点、重症度、相手の気持ちの推測を含めない。
    var factualSummary: String {
        let counts = responseCounts
            .map { "\($0.label) \($0.count)件" }
            .joined(separator: "、")
        let unanswered = unansweredCount > 0 ? "、未回答 \(unansweredCount)件" : ""
        return "\(type.rawValue): 回答 \(answeredCount)件（\(counts)\(unanswered)）"
    }
}

/// 1つのチェック中の回答を保持し、事実ベースの結果へ変換する値型。
struct SelfCheckSession {
    let type: SelfCheckType
    var answers: [Int]

    func makeResult() -> SelfCheckResult {
        let options = SelfCheckCatalog.answerOptions(for: type)
        var counts = Array(repeating: 0, count: options.count)
        var answeredCount = 0

        for answer in answers where options.indices.contains(answer) {
            counts[answer] += 1
            answeredCount += 1
        }

        return SelfCheckResult(
            type: type,
            answeredCount: answeredCount,
            totalQuestionCount: SelfCheckCatalog.questions(for: type).count,
            responseCounts: zip(options, counts).map {
                SelfCheckResponseCount(label: $0.0, count: $0.1)
            }
        )
    }
}
