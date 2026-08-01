import Foundation
import SwiftData

/// 利用者が明示的に希望した場合だけ、安全確認を行った日時を保存する。
///
/// 回答内容、選んだ選択肢、日記本文は受け取らないため、保存できない。
@MainActor
struct SafetyCheckSaveService {
    var persist: (ModelContext) throws -> Void = { context in
        try context.save()
    }

    @discardableResult
    func saveCheckDate(
        _ date: Date = Date(),
        in context: ModelContext
    ) throws -> LightSafetyCheckRecord {
        let record = LightSafetyCheckRecord(date: date)
        context.insert(record)

        do {
            try persist(context)
            return record
        } catch {
            context.delete(record)
            throw error
        }
    }
}
