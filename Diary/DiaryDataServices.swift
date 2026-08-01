import Foundation
import SwiftData

struct DiaryRestoreResult: Equatable, Sendable {
    let inserted: DiaryDataCounts
    let replaced: DiaryDataCounts
}

enum DiaryDataServiceError: Error, Equatable, LocalizedError {
    case duplicateLocalIdentifier
    case unreadableFile
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .duplicateLocalIdentifier:
            return "端末内に同じIDの記録が複数あります。安全に復元できないため、データは変更していません。"
        case .unreadableFile:
            return "選んだバックアップファイルを読み込めませんでした。"
        case .fileTooLarge:
            return "バックアップファイルが大きすぎるため、安全に読み込めません。"
        }
    }
}

/// SwiftDataと値型アーカイブの境界。暗号処理はSwiftDataモデルを直接受け取らない。
@MainActor
enum DiaryArchiveDataService {
    typealias ContextSaver = (ModelContext) throws -> Void

    static func counts(in context: ModelContext) throws -> DiaryDataCounts {
        DiaryDataCounts(
            moodEntries: try context.fetchCount(FetchDescriptor<MoodEntry>()),
            assessments: try context.fetchCount(FetchDescriptor<MentalHealthAssessment>()),
            safetyChecks: try context.fetchCount(FetchDescriptor<LightSafetyCheckRecord>())
        )
    }

    static func makeArchive(
        in context: ModelContext,
        exportedAt: Date = Date()
    ) throws -> DiaryArchiveV1 {
        if context.hasChanges {
            try context.save()
        }

        var moodDescriptor = FetchDescriptor<MoodEntry>(
            sortBy: [SortDescriptor(\MoodEntry.date, order: .forward)]
        )
        moodDescriptor.fetchLimit = DiaryArchiveLimits.maximumRecordsPerType + 1
        var assessmentDescriptor = FetchDescriptor<MentalHealthAssessment>(
            sortBy: [SortDescriptor(\MentalHealthAssessment.date, order: .forward)]
        )
        assessmentDescriptor.fetchLimit = DiaryArchiveLimits.maximumRecordsPerType + 1
        var safetyDescriptor = FetchDescriptor<LightSafetyCheckRecord>(
            sortBy: [SortDescriptor(\LightSafetyCheckRecord.date, order: .forward)]
        )
        safetyDescriptor.fetchLimit = DiaryArchiveLimits.maximumRecordsPerType + 1

        let moodEntries = try context.fetch(moodDescriptor)
        let assessments = try context.fetch(assessmentDescriptor)
        let safetyChecks = try context.fetch(safetyDescriptor)
        guard moodEntries.count <= DiaryArchiveLimits.maximumRecordsPerType,
              assessments.count <= DiaryArchiveLimits.maximumRecordsPerType,
              safetyChecks.count <= DiaryArchiveLimits.maximumRecordsPerType else {
            throw DiaryArchiveValidationError.tooManyRecords
        }

        let archive = DiaryArchiveV1(
            exportedAt: exportedAt,
            moodEntries: moodEntries.map(ArchivedMoodEntry.init(entry:)),
            assessments: assessments.map(ArchivedMentalHealthAssessment.init(assessment:)),
            safetyChecks: safetyChecks.map(ArchivedSafetyCheck.init(record:))
        )
        try archive.validate()
        return archive
    }

    static func preview(
        archive: DiaryArchiveV1,
        in context: ModelContext
    ) throws -> DiaryArchiveRestorePreview {
        try archive.validate()
        let localMoodIDs = try uniqueIDs(
            context.fetch(FetchDescriptor<MoodEntry>()).map(\.id)
        )
        let localAssessmentIDs = try uniqueIDs(
            context.fetch(FetchDescriptor<MentalHealthAssessment>()).map(\.id)
        )
        let localSafetyIDs = try uniqueIDs(
            context.fetch(FetchDescriptor<LightSafetyCheckRecord>()).map(\.id)
        )

        return DiaryArchiveRestorePreview(
            archiveCounts: archive.counts,
            conflictCounts: DiaryDataCounts(
                moodEntries: archive.moodEntries.lazy.filter { localMoodIDs.contains($0.id) }.count,
                assessments: archive.assessments.lazy.filter { localAssessmentIDs.contains($0.id) }.count,
                safetyChecks: archive.safetyChecks.lazy.filter { localSafetyIDs.contains($0.id) }.count
            )
        )
    }

    static func restore(
        archive: DiaryArchiveV1,
        conflictPolicy: RestoreConflictPolicy = .keepCurrent,
        in context: ModelContext,
        persist: ContextSaver = { try $0.save() }
    ) throws -> DiaryRestoreResult {
        try archive.validate()
        if context.hasChanges {
            try context.save()
        }

        let localMoodEntries = try context.fetch(FetchDescriptor<MoodEntry>())
        let localAssessments = try context.fetch(FetchDescriptor<MentalHealthAssessment>())
        let localSafetyChecks = try context.fetch(FetchDescriptor<LightSafetyCheckRecord>())
        let moodByID = try uniqueModels(localMoodEntries, id: \.id)
        let assessmentByID = try uniqueModels(localAssessments, id: \.id)
        let safetyByID = try uniqueModels(localSafetyChecks, id: \.id)

        let previousAutosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = previousAutosave }

        var insertedMood = 0
        var insertedAssessments = 0
        var insertedSafety = 0
        var replacedMood = 0
        var replacedAssessments = 0
        var replacedSafety = 0

        do {
            for archived in archive.moodEntries {
                if let current = moodByID[archived.id] {
                    if conflictPolicy == .replaceWithBackup {
                        archived.apply(to: current)
                        replacedMood += 1
                    }
                } else {
                    context.insert(archived.makeModel())
                    insertedMood += 1
                }
            }

            for archived in archive.assessments {
                if let current = assessmentByID[archived.id] {
                    if conflictPolicy == .replaceWithBackup {
                        archived.apply(to: current)
                        replacedAssessments += 1
                    }
                } else {
                    context.insert(archived.makeModel())
                    insertedAssessments += 1
                }
            }

            for archived in archive.safetyChecks {
                if let current = safetyByID[archived.id] {
                    if conflictPolicy == .replaceWithBackup {
                        archived.apply(to: current)
                        replacedSafety += 1
                    }
                } else {
                    context.insert(archived.makeModel())
                    insertedSafety += 1
                }
            }

            try persist(context)
        } catch {
            context.rollback()
            throw error
        }

        return DiaryRestoreResult(
            inserted: DiaryDataCounts(
                moodEntries: insertedMood,
                assessments: insertedAssessments,
                safetyChecks: insertedSafety
            ),
            replaced: DiaryDataCounts(
                moodEntries: replacedMood,
                assessments: replacedAssessments,
                safetyChecks: replacedSafety
            )
        )
    }

    static func deleteAll(
        in context: ModelContext,
        persist: ContextSaver = { try $0.save() }
    ) throws -> DiaryDataCounts {
        if context.hasChanges {
            try context.save()
        }

        let moodEntries = try context.fetch(FetchDescriptor<MoodEntry>())
        let assessments = try context.fetch(FetchDescriptor<MentalHealthAssessment>())
        let safetyChecks = try context.fetch(FetchDescriptor<LightSafetyCheckRecord>())
        let deletedCounts = DiaryDataCounts(
            moodEntries: moodEntries.count,
            assessments: assessments.count,
            safetyChecks: safetyChecks.count
        )

        let previousAutosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = previousAutosave }

        do {
            moodEntries.forEach(context.delete)
            assessments.forEach(context.delete)
            safetyChecks.forEach(context.delete)
            try persist(context)
            return deletedCounts
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func uniqueIDs(_ ids: [UUID]) throws -> Set<UUID> {
        let result = Set(ids)
        guard result.count == ids.count else {
            throw DiaryDataServiceError.duplicateLocalIdentifier
        }
        return result
    }

    private static func uniqueModels<Model>(
        _ models: [Model],
        id keyPath: KeyPath<Model, UUID>
    ) throws -> [UUID: Model] {
        var result: [UUID: Model] = [:]
        for model in models {
            let identifier = model[keyPath: keyPath]
            guard result[identifier] == nil else {
                throw DiaryDataServiceError.duplicateLocalIdentifier
            }
            result[identifier] = model
        }
        return result
    }
}

enum DiaryArchiveFileReader {
    static func readEncryptedData(from url: URL) throws -> Data {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else {
                throw DiaryDataServiceError.unreadableFile
            }
            if let size = values.fileSize,
               size > DiaryArchiveLimits.maximumEncryptedFileBytes {
                throw DiaryDataServiceError.fileTooLarge
            }
            let data = try Data(contentsOf: url, options: [.uncached])
            guard data.count <= DiaryArchiveLimits.maximumEncryptedFileBytes else {
                throw DiaryDataServiceError.fileTooLarge
            }
            return data
        } catch let error as DiaryDataServiceError {
            throw error
        } catch {
            throw DiaryDataServiceError.unreadableFile
        }
    }
}

struct DiaryFileProtectionReport: Equatable, Sendable {
    let storeURL: URL
    let isProtected: Bool
    let warning: String?
}

enum DiaryFileProtectionError: Error, Equatable, LocalizedError {
    case protectionCouldNotBeConfirmed

    var errorDescription: String? {
        switch self {
        case .protectionCouldNotBeConfirmed:
            return "OSから完全保護の適用を確認できませんでした。"
        }
    }
}

enum DiaryFileProtectionService {
    static func prepareDefaultStore() -> DiaryFileProtectionReport {
        prepareStore(at: ModelConfiguration().url)
    }

    static func prepareStore(at storeURL: URL) -> DiaryFileProtectionReport {
        do {
            try applyCompleteProtectionToStore(at: storeURL)
            return DiaryFileProtectionReport(
                storeURL: storeURL,
                isProtected: true,
                warning: nil
            )
        } catch {
            return DiaryFileProtectionReport(
                storeURL: storeURL,
                isProtected: false,
                warning: "端末内ファイルの追加保護を確認できませんでした: \(error.localizedDescription)"
            )
        }
    }

    static func refreshProtection(at storeURL: URL) -> DiaryFileProtectionReport {
        do {
            try applyCompleteProtectionToStore(at: storeURL)
            return DiaryFileProtectionReport(
                storeURL: storeURL,
                isProtected: true,
                warning: nil
            )
        } catch {
            return DiaryFileProtectionReport(
                storeURL: storeURL,
                isProtected: false,
                warning: "端末内ファイルの追加保護を確認できませんでした: \(error.localizedDescription)"
            )
        }
    }

    static func applyCompleteProtection(to url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let protection = attributes[.protectionKey]
        let isComplete = (protection as? FileProtectionType) == .complete
            || (protection as? String) == FileProtectionType.complete.rawValue
        guard isComplete else {
            throw DiaryFileProtectionError.protectionCouldNotBeConfirmed
        }
    }

    private static func applyCompleteProtectionToStore(at storeURL: URL) throws {
        let directory = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        try applyCompleteProtection(to: directory)

        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for file in files where file.lastPathComponent.hasPrefix(storeURL.lastPathComponent) {
            try applyCompleteProtection(to: file)
        }
    }
}
