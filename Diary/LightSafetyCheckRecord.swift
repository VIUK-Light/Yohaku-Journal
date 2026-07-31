import Foundation
import SwiftData

/// 安全確認を行った事実だけを記録する軽量モデル。
/// 回答内容や日記本文は保存しない。
@Model
final class LightSafetyCheckRecord {
    var id = UUID()
    var date = Date()

    init(date: Date = Date()) {
        self.date = date
    }
}
