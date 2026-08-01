import Foundation

/// 暗号化前の論理アーカイブ。ファイルへ平文のまま書き出してはいけない。
struct DiaryArchiveV1: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let formatVersion: Int
    let exportedAt: Date
    let moodEntries: [ArchivedMoodEntry]
    let assessments: [ArchivedMentalHealthAssessment]
    let safetyChecks: [ArchivedSafetyCheck]

    init(
        formatVersion: Int = currentVersion,
        exportedAt: Date = Date(),
        moodEntries: [ArchivedMoodEntry],
        assessments: [ArchivedMentalHealthAssessment],
        safetyChecks: [ArchivedSafetyCheck]
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.moodEntries = moodEntries
        self.assessments = assessments
        self.safetyChecks = safetyChecks
    }

    var counts: DiaryDataCounts {
        DiaryDataCounts(
            moodEntries: moodEntries.count,
            assessments: assessments.count,
            safetyChecks: safetyChecks.count
        )
    }

    func validate() throws {
        guard formatVersion == Self.currentVersion else {
            throw DiaryArchiveValidationError.unsupportedArchiveVersion(formatVersion)
        }
        guard exportedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw DiaryArchiveValidationError.invalidDate
        }
        guard moodEntries.count <= DiaryArchiveLimits.maximumRecordsPerType,
              assessments.count <= DiaryArchiveLimits.maximumRecordsPerType,
              safetyChecks.count <= DiaryArchiveLimits.maximumRecordsPerType else {
            throw DiaryArchiveValidationError.tooManyRecords
        }
        guard Set(moodEntries.map(\.id)).count == moodEntries.count,
              Set(assessments.map(\.id)).count == assessments.count,
              Set(safetyChecks.map(\.id)).count == safetyChecks.count else {
            throw DiaryArchiveValidationError.duplicateIdentifier
        }

        try moodEntries.forEach { try $0.validate() }
        try assessments.forEach { try $0.validate() }
        try safetyChecks.forEach { try $0.validate() }
    }
}

struct ArchivedMoodEntry: Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let mood: String
    let moodScore: Int
    let recordType: String
    let emotions: [String]
    let notes: String
    let activities: [String]
    let gratitude: String
    let reflections: String
    let influences: [String]
    let lifeFactors: [String]

    init(entry: MoodEntry) {
        id = entry.id
        date = entry.date
        mood = entry.mood
        moodScore = entry.moodScore
        recordType = entry.recordType
        emotions = entry.emotions
        notes = entry.notes
        activities = entry.activities
        gratitude = entry.gratitude
        reflections = entry.reflections
        influences = entry.influences
        lifeFactors = entry.lifeFactors
    }

    init(
        id: UUID,
        date: Date,
        mood: String,
        moodScore: Int,
        recordType: String,
        emotions: [String],
        notes: String,
        activities: [String],
        gratitude: String,
        reflections: String,
        influences: [String],
        lifeFactors: [String]
    ) {
        self.id = id
        self.date = date
        self.mood = mood
        self.moodScore = moodScore
        self.recordType = recordType
        self.emotions = emotions
        self.notes = notes
        self.activities = activities
        self.gratitude = gratitude
        self.reflections = reflections
        self.influences = influences
        self.lifeFactors = lifeFactors
    }

    func makeModel() -> MoodEntry {
        let entry = MoodEntry()
        apply(to: entry)
        return entry
    }

    func apply(to entry: MoodEntry) {
        entry.id = id
        entry.date = date
        entry.mood = mood
        entry.moodScore = moodScore
        entry.recordType = recordType
        entry.emotions = emotions
        entry.notes = notes
        entry.activities = activities
        entry.gratitude = gratitude
        entry.reflections = reflections
        entry.influences = influences
        entry.lifeFactors = lifeFactors
    }

    fileprivate func validate() throws {
        guard date.timeIntervalSinceReferenceDate.isFinite else {
            throw DiaryArchiveValidationError.invalidDate
        }
        guard (1...7).contains(moodScore) else {
            throw DiaryArchiveValidationError.invalidMoodScore
        }
        try validateString(mood)
        try validateString(recordType)
        try validateString(notes)
        try validateString(gratitude)
        try validateString(reflections)
        try validateStringArray(emotions)
        try validateStringArray(activities)
        try validateStringArray(influences)
        try validateStringArray(lifeFactors)
    }
}

struct ArchivedMentalHealthAssessment: Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let phq9Score: Int
    let gad7Score: Int
    let phq9Answers: [Int]
    let gad7Answers: [Int]
    let notes: String
    let selectedTests: [String]
    let isPhq9Completed: Bool
    let isGad7Completed: Bool
    let ageGroupInterpretation: String
    let userAge: Int

    init(assessment: MentalHealthAssessment) {
        id = assessment.id
        date = assessment.date
        phq9Score = assessment.phq9Score
        gad7Score = assessment.gad7Score
        phq9Answers = assessment.phq9Answers
        gad7Answers = assessment.gad7Answers
        notes = assessment.notes
        selectedTests = assessment.selectedTests
        isPhq9Completed = assessment.isPhq9Completed
        isGad7Completed = assessment.isGad7Completed
        ageGroupInterpretation = assessment.ageGroupInterpretation
        userAge = assessment.userAge
    }

    init(
        id: UUID,
        date: Date,
        phq9Score: Int,
        gad7Score: Int,
        phq9Answers: [Int],
        gad7Answers: [Int],
        notes: String,
        selectedTests: [String],
        isPhq9Completed: Bool,
        isGad7Completed: Bool,
        ageGroupInterpretation: String,
        userAge: Int
    ) {
        self.id = id
        self.date = date
        self.phq9Score = phq9Score
        self.gad7Score = gad7Score
        self.phq9Answers = phq9Answers
        self.gad7Answers = gad7Answers
        self.notes = notes
        self.selectedTests = selectedTests
        self.isPhq9Completed = isPhq9Completed
        self.isGad7Completed = isGad7Completed
        self.ageGroupInterpretation = ageGroupInterpretation
        self.userAge = userAge
    }

    func makeModel() -> MentalHealthAssessment {
        let assessment = MentalHealthAssessment()
        apply(to: assessment)
        return assessment
    }

    func apply(to assessment: MentalHealthAssessment) {
        assessment.id = id
        assessment.date = date
        assessment.phq9Score = phq9Score
        assessment.gad7Score = gad7Score
        assessment.phq9Answers = phq9Answers
        assessment.gad7Answers = gad7Answers
        assessment.notes = notes
        assessment.selectedTests = selectedTests
        assessment.isPhq9Completed = isPhq9Completed
        assessment.isGad7Completed = isGad7Completed
        assessment.ageGroupInterpretation = ageGroupInterpretation
        assessment.userAge = userAge
    }

    fileprivate func validate() throws {
        guard date.timeIntervalSinceReferenceDate.isFinite else {
            throw DiaryArchiveValidationError.invalidDate
        }
        guard phq9Answers.count <= DiaryArchiveLimits.maximumValuesPerArray,
              gad7Answers.count <= DiaryArchiveLimits.maximumValuesPerArray else {
            throw DiaryArchiveValidationError.tooManyValues
        }
        try validateString(notes)
        try validateString(ageGroupInterpretation)
        try validateStringArray(selectedTests)
    }
}

struct ArchivedSafetyCheck: Codable, Equatable, Sendable {
    let id: UUID
    let date: Date

    init(record: LightSafetyCheckRecord) {
        id = record.id
        date = record.date
    }

    init(id: UUID, date: Date) {
        self.id = id
        self.date = date
    }

    func makeModel() -> LightSafetyCheckRecord {
        let record = LightSafetyCheckRecord(date: date)
        record.id = id
        return record
    }

    func apply(to record: LightSafetyCheckRecord) {
        record.id = id
        record.date = date
    }

    fileprivate func validate() throws {
        guard date.timeIntervalSinceReferenceDate.isFinite else {
            throw DiaryArchiveValidationError.invalidDate
        }
    }
}

struct DiaryDataCounts: Equatable, Sendable {
    let moodEntries: Int
    let assessments: Int
    let safetyChecks: Int

    static let zero = DiaryDataCounts(moodEntries: 0, assessments: 0, safetyChecks: 0)

    var total: Int {
        moodEntries + assessments + safetyChecks
    }
}

enum RestoreConflictPolicy: String, CaseIterable, Identifiable, Sendable {
    case keepCurrent
    case replaceWithBackup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keepCurrent: return "現在のデータを残す"
        case .replaceWithBackup: return "バックアップで置換"
        }
    }
}

struct DiaryArchiveRestorePreview: Equatable, Sendable {
    let archiveCounts: DiaryDataCounts
    let conflictCounts: DiaryDataCounts

    var newRecordCount: Int {
        archiveCounts.total - conflictCounts.total
    }
}

enum DiaryArchiveLimits {
    static let maximumEncryptedFileBytes = 64 * 1_024 * 1_024
    static let maximumRecordsPerType = 100_000
    static let maximumValuesPerArray = 256
    static let maximumStringBytes = 1_048_576
}

enum DiaryArchiveValidationError: Error, Equatable, LocalizedError {
    case unsupportedArchiveVersion(Int)
    case invalidDate
    case tooManyRecords
    case duplicateIdentifier
    case invalidMoodScore
    case tooManyValues
    case stringTooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedArchiveVersion:
            return "このバックアップのバージョンには対応していません。"
        case .invalidDate, .invalidMoodScore, .tooManyValues, .stringTooLarge:
            return "バックアップ内の記録形式を確認できませんでした。"
        case .tooManyRecords:
            return "バックアップ内の記録件数が上限を超えています。"
        case .duplicateIdentifier:
            return "バックアップ内に重複した記録IDがあります。"
        }
    }
}

private func validateString(_ value: String) throws {
    guard value.utf8.count <= DiaryArchiveLimits.maximumStringBytes else {
        throw DiaryArchiveValidationError.stringTooLarge
    }
}

private func validateStringArray(_ values: [String]) throws {
    guard values.count <= DiaryArchiveLimits.maximumValuesPerArray else {
        throw DiaryArchiveValidationError.tooManyValues
    }
    try values.forEach { try validateString($0) }
}
