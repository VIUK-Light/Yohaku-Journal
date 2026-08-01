import Foundation

/// SwiftDataの既存`recordType`文字列を変更せず、安全に扱うための内部型。
enum RecordKind: String, CaseIterable, Identifiable, Hashable {
    case moment
    case dailyReflection

    var id: Self { self }

    var title: String {
        switch self {
        case .moment: return "今の気分"
        case .dailyReflection: return "一日振り返り"
        }
    }

    var subtitle: String {
        switch self {
        case .moment: return "その瞬間を何度でも記録"
        case .dailyReflection: return "一日につき1件"
        }
    }

    /// 新規保存で使う文字列。既存スキーマと旧バージョンの読み込み互換を維持する。
    var storageValue: String {
        switch self {
        case .moment: return "今現在の気分"
        case .dailyReflection: return "今日一日の気分"
        }
    }

    init(storedValue: String) {
        let normalized = storedValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")

        switch normalized {
        case "今日一日の気分", "今日1日の気分", "一日の振り返り", "1日の振り返り", "一日振り返り":
            self = .dailyReflection
        case "今現在の気分", "今の気分", "現在の気分", "瞬間記録":
            self = .moment
        default:
            // 未知の旧値を破壊せず読み込むため、制約の少ない瞬間記録として扱う。
            self = .moment
        }
    }
}

extension MoodEntry {
    var recordKind: RecordKind {
        RecordKind(storedValue: recordType)
    }
}
