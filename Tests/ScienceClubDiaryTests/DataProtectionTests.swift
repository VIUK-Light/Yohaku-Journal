import Foundation
import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import Science_Club_Diary

final class DiaryArchiveCryptoTests: XCTestCase {
    private let password = "correct horse battery staple"

    func testPBKDF2HMACSHA256MatchesKnownVectors() throws {
        let salt = Data("salt".utf8)

        let once = try DiaryArchiveCrypto.deriveKeyData(
            password: "password",
            salt: salt,
            iterations: 1,
            keyByteCount: 32
        )
        let twice = try DiaryArchiveCrypto.deriveKeyData(
            password: "password",
            salt: salt,
            iterations: 2,
            keyByteCount: 32
        )

        XCTAssertEqual(
            once.hexString,
            "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"
        )
        XCTAssertEqual(
            twice.hexString,
            "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43"
        )
    }

    func testEncryptedArchiveRoundTripsAndRecordsSecurityParameters() async throws {
        let archive = makeArchive()

        let encrypted = try await DiaryArchiveCrypto.encrypt(
            archive: archive,
            password: password
        )
        let metadata = try DiaryArchiveCrypto.metadata(from: encrypted)
        let decrypted = try await DiaryArchiveCrypto.decrypt(
            encryptedData: encrypted,
            password: password
        )

        XCTAssertNotEqual(encrypted, try JSONEncoder().encode(archive))
        for secret in ["暗号化するメモ", "話せたこと", "事実ベースの振り返り"] {
            XCTAssertNil(
                encrypted.range(of: Data(secret.utf8)),
                "平文「\(secret)」が暗号化データに残っています。"
            )
        }
        XCTAssertEqual(metadata.formatVersion, 1)
        XCTAssertEqual(metadata.kdfAlgorithm, "PBKDF2-HMAC-SHA256")
        XCTAssertEqual(metadata.iterations, 600_000)
        XCTAssertEqual(metadata.cipher, "AES-256-GCM")
        XCTAssertEqual(decrypted, archive)
    }

    func testDecryptionPasswordPolicyKeepsLegacyShortPasswordsReadable() throws {
        XCTAssertNoThrow(try DiaryArchivePasswordPolicy.validateForDecryption("short"))
        XCTAssertThrowsError(
            try DiaryArchivePasswordPolicy.validateForDecryption(
                String(repeating: "a", count: DiaryArchivePasswordPolicy.maximumUTF8ByteCount + 1)
            )
        ) { error in
            XCTAssertEqual(error as? DiaryArchiveCryptoError, .passwordTooLong)
        }
    }

    func testWrongPasswordDoesNotReturnPlaintext() async throws {
        let encrypted = try await DiaryArchiveCrypto.encrypt(
            archive: makeArchive(),
            password: password
        )

        do {
            _ = try await DiaryArchiveCrypto.decrypt(
                encryptedData: encrypted,
                password: "this password is incorrect"
            )
            XCTFail("誤ったパスワードで復号できてはいけません")
        } catch {
            XCTAssertEqual(error as? DiaryArchiveCryptoError, .authenticationFailed)
        }
    }

    func testCiphertextTamperingIsDetected() async throws {
        let encrypted = try await DiaryArchiveCrypto.encrypt(
            archive: makeArchive(),
            password: password
        )
        let tampered = try tamperWithCiphertext(in: encrypted)

        do {
            _ = try await DiaryArchiveCrypto.decrypt(
                encryptedData: tampered,
                password: password
            )
            XCTFail("改ざんされた暗号文を復号できてはいけません")
        } catch {
            XCTAssertTrue(error is DiaryArchiveCryptoError)
        }
    }

    func testUnsupportedArchiveVersionIsRejectedBeforeEncryption() throws {
        let archive = DiaryArchiveV1(
            formatVersion: 99,
            moodEntries: [],
            assessments: [],
            safetyChecks: []
        )

        XCTAssertThrowsError(try archive.validate()) { error in
            XCTAssertEqual(
                error as? DiaryArchiveValidationError,
                .unsupportedArchiveVersion(99)
            )
        }
    }

    func testAssessmentValidationRejectsEachInvalidBoundaryIndividually() {
        let invalidCases: [(String, ArchivedMentalHealthAssessment, DiaryArchiveValidationError)] = [
            ("PHQ回答 -1", makeAssessment(phq9Answers: [-1]), .invalidAssessmentValue),
            ("PHQ回答 4", makeAssessment(phq9Answers: [4]), .invalidAssessmentValue),
            ("GAD回答 -1", makeAssessment(gad7Answers: [-1]), .invalidAssessmentValue),
            ("GAD回答 4", makeAssessment(gad7Answers: [4]), .invalidAssessmentValue),
            ("PHQスコア -1", makeAssessment(phq9Score: -1), .invalidAssessmentValue),
            ("PHQスコア 28", makeAssessment(phq9Score: 28), .invalidAssessmentValue),
            ("GADスコア -1", makeAssessment(gad7Score: -1), .invalidAssessmentValue),
            ("GADスコア 22", makeAssessment(gad7Score: 22), .invalidAssessmentValue),
            (
                "PHQ完了なのに回答なし",
                makeAssessment(isPhq9Completed: true),
                .invalidAssessmentValue
            ),
            (
                "PHQスコアと回答合計が不一致",
                makeAssessment(
                    phq9Score: 1,
                    phq9Answers: Array(repeating: 0, count: 9),
                    isPhq9Completed: true
                ),
                .invalidAssessmentValue
            ),
            (
                "GAD完了なのに回答なし",
                makeAssessment(isGad7Completed: true),
                .invalidAssessmentValue
            ),
            (
                "GADスコアと回答合計が不一致",
                makeAssessment(
                    gad7Score: 1,
                    gad7Answers: Array(repeating: 0, count: 7),
                    isGad7Completed: true
                ),
                .invalidAssessmentValue
            )
        ]

        for (name, assessment, expectedError) in invalidCases {
            XCTContext.runActivity(named: name) { _ in
                XCTAssertThrowsError(try validate(assessment)) { error in
                    XCTAssertEqual(error as? DiaryArchiveValidationError, expectedError)
                }
            }
        }
    }

    func testAssessmentValidationAcceptsValidBoundaries() throws {
        let validCases = [
            makeAssessment(
                phq9Score: 0,
                phq9Answers: Array(repeating: 0, count: 9),
                isPhq9Completed: true
            ),
            makeAssessment(
                phq9Score: 27,
                phq9Answers: Array(repeating: 3, count: 9),
                isPhq9Completed: true
            ),
            makeAssessment(
                gad7Score: 0,
                gad7Answers: Array(repeating: 0, count: 7),
                isGad7Completed: true
            ),
            makeAssessment(
                gad7Score: 21,
                gad7Answers: Array(repeating: 3, count: 7),
                isGad7Completed: true
            )
        ]

        for assessment in validCases {
            XCTAssertNoThrow(try validate(assessment))
        }
    }

    func testAssessmentArrayLimitIsValidatedIndividually() {
        let tooManyValues = Array(
            repeating: 0,
            count: DiaryArchiveLimits.maximumValuesPerArray + 1
        )

        XCTAssertThrowsError(
            try validate(makeAssessment(phq9Answers: tooManyValues))
        ) { error in
            XCTAssertEqual(error as? DiaryArchiveValidationError, .tooManyValues)
        }
        XCTAssertThrowsError(
            try validate(makeAssessment(gad7Answers: tooManyValues))
        ) { error in
            XCTAssertEqual(error as? DiaryArchiveValidationError, .tooManyValues)
        }
    }

    func testCancellationPreventsEncryptionResult() async throws {
        let gate = EncryptionStartGate()
        let archive = makeArchive()
        let encryptionPassword = password
        let operation = Task.detached(priority: .userInitiated) {
            await gate.wait()
            return try await DiaryArchiveCrypto.encrypt(
                archive: archive,
                password: encryptionPassword
            )
        }

        operation.cancel()
        await gate.open()

        do {
            _ = try await operation.value
            XCTFail("キャンセル済みの暗号化結果が返ってはいけません")
        } catch is CancellationError {
            // 期待するキャンセル結果。
        } catch {
            XCTFail("想定外のエラー: \(error)")
        }
    }

    func testCancellationPreventsDecryptionResult() async throws {
        let gate = EncryptionStartGate()
        let operation = Task.detached(priority: .userInitiated) {
            await gate.wait()
            return try await DiaryArchiveCrypto.decrypt(
                encryptedData: Data(),
                password: "short"
            )
        }

        operation.cancel()
        await gate.open()

        do {
            _ = try await operation.value
            XCTFail("キャンセル済みの復号結果が返ってはいけません")
        } catch is CancellationError {
            // 期待するキャンセル結果。
        } catch {
            XCTFail("想定外のエラー: \(error)")
        }
    }

    func testVisuallyEquivalentCanonicalPasswordsDeriveSameKey() throws {
        let composed = "café password phrase"
        let decomposed = "cafe\u{301} password phrase"
        let salt = Data(repeating: 7, count: 16)

        let first = try DiaryArchiveCrypto.deriveKeyData(
            password: composed,
            salt: salt,
            iterations: 2,
            keyByteCount: 32
        )
        let second = try DiaryArchiveCrypto.deriveKeyData(
            password: decomposed,
            salt: salt,
            iterations: 2,
            keyByteCount: 32
        )

        XCTAssertEqual(first, second)
    }

    private func makeArchive() -> DiaryArchiveV1 {
        let date = Date(timeIntervalSince1970: 1_785_484_800)
        return DiaryArchiveV1(
            exportedAt: date,
            moodEntries: [
                ArchivedMoodEntry(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    date: date,
                    mood: "やや快適",
                    moodScore: 5,
                    recordType: "瞬間記録",
                    emotions: ["安心"],
                    notes: "暗号化するメモ",
                    activities: ["散歩"],
                    gratitude: "話せたこと",
                    reflections: "急がず振り返った",
                    influences: ["天気"],
                    lifeFactors: ["睡眠"]
                )
            ],
            assessments: [
                ArchivedMentalHealthAssessment(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    date: date,
                    phq9Score: 0,
                    gad7Score: 0,
                    phq9Answers: [],
                    gad7Answers: [],
                    notes: "事実ベースの振り返り",
                    selectedTests: ["スマホ利用の振り返り"],
                    isPhq9Completed: false,
                    isGad7Completed: false,
                    ageGroupInterpretation: "",
                    userAge: 0
                )
            ],
            safetyChecks: [
                ArchivedSafetyCheck(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    date: date
                )
            ]
        )
    }

    private func makeAssessment(
        phq9Score: Int = 0,
        gad7Score: Int = 0,
        phq9Answers: [Int] = [],
        gad7Answers: [Int] = [],
        isPhq9Completed: Bool = false,
        isGad7Completed: Bool = false
    ) -> ArchivedMentalHealthAssessment {
        ArchivedMentalHealthAssessment(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_785_484_800),
            phq9Score: phq9Score,
            gad7Score: gad7Score,
            phq9Answers: phq9Answers,
            gad7Answers: gad7Answers,
            notes: "",
            selectedTests: [],
            isPhq9Completed: isPhq9Completed,
            isGad7Completed: isGad7Completed,
            ageGroupInterpretation: "",
            userAge: 0
        )
    }

    private func validate(_ assessment: ArchivedMentalHealthAssessment) throws {
        try DiaryArchiveV1(
            exportedAt: assessment.date,
            moodEntries: [],
            assessments: [assessment],
            safetyChecks: []
        ).validate()
    }

    private func tamperWithCiphertext(in data: Data) throws -> Data {
        guard var text = String(data: data, encoding: .utf8),
              let markerRange = text.range(of: "\"ciphertext\":\"") else {
            throw TestError.cannotTamper
        }
        let payloadIndex = markerRange.upperBound
        guard payloadIndex < text.endIndex else {
            throw TestError.cannotTamper
        }
        let replacement: Character = text[payloadIndex] == "A" ? "B" : "A"
        text.replaceSubrange(payloadIndex...payloadIndex, with: String(replacement))
        guard let result = text.data(using: .utf8) else {
            throw TestError.cannotTamper
        }
        return result
    }

    private enum TestError: Error {
        case cannotTamper
    }
}

private actor EncryptionStartGate {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        if isOpen {
            return
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
final class DiaryArchiveDataServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: MoodEntry.self,
            MentalHealthAssessment.self,
            LightSafetyCheckRecord.self,
            configurations: configuration
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    func testArchiveCapturesAndRestoresAllPersistedModelTypes() throws {
        let identifiers = try insertOneOfEach()
        let archive = try DiaryArchiveDataService.makeArchive(in: context)

        let destination = try makeContainer()
        let destinationContext = ModelContext(destination)
        let result = try DiaryArchiveDataService.restore(
            archive: archive,
            in: destinationContext
        )

        XCTAssertEqual(archive.counts, DiaryDataCounts(moodEntries: 1, assessments: 1, safetyChecks: 1))
        XCTAssertEqual(result.inserted, archive.counts)
        XCTAssertEqual(result.replaced, .zero)

        let restoredMood = try XCTUnwrap(destinationContext.fetch(FetchDescriptor<MoodEntry>()).first)
        let restoredAssessment = try XCTUnwrap(
            destinationContext.fetch(FetchDescriptor<MentalHealthAssessment>()).first
        )
        let restoredSafety = try XCTUnwrap(
            destinationContext.fetch(FetchDescriptor<LightSafetyCheckRecord>()).first
        )
        XCTAssertEqual(restoredMood.id, identifiers.mood)
        XCTAssertEqual(restoredMood.notes, "端末内のメモ")
        XCTAssertEqual(restoredAssessment.id, identifiers.assessment)
        XCTAssertEqual(restoredAssessment.selectedTests, ["スマホ利用の振り返り"])
        XCTAssertEqual(restoredSafety.id, identifiers.safety)
    }

    func testPreviewAndDefaultRestoreKeepCurrentConflicts() throws {
        let conflictID = UUID()
        let local = makeMoodEntry(id: conflictID, notes: "現在の記録")
        context.insert(local)
        try context.save()
        let archive = DiaryArchiveV1(
            moodEntries: [
                archivedMood(id: conflictID, notes: "バックアップ側"),
                archivedMood(id: UUID(), notes: "新しい記録")
            ],
            assessments: [],
            safetyChecks: []
        )

        let preview = try DiaryArchiveDataService.preview(archive: archive, in: context)
        let result = try DiaryArchiveDataService.restore(archive: archive, in: context)
        let entries = try context.fetch(FetchDescriptor<MoodEntry>())

        XCTAssertEqual(preview.conflictCounts.moodEntries, 1)
        XCTAssertEqual(preview.newRecordCount, 1)
        XCTAssertEqual(result.inserted.moodEntries, 1)
        XCTAssertEqual(result.replaced.moodEntries, 0)
        XCTAssertEqual(entries.first(where: { $0.id == conflictID })?.notes, "現在の記録")
    }

    func testExplicitReplaceUpdatesConflictWithoutCreatingDuplicate() throws {
        let conflictID = UUID()
        context.insert(makeMoodEntry(id: conflictID, notes: "現在の記録"))
        try context.save()
        let archive = DiaryArchiveV1(
            moodEntries: [archivedMood(id: conflictID, notes: "バックアップ側")],
            assessments: [],
            safetyChecks: []
        )

        let result = try DiaryArchiveDataService.restore(
            archive: archive,
            conflictPolicy: .replaceWithBackup,
            in: context
        )
        let entries = try context.fetch(FetchDescriptor<MoodEntry>())

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.notes, "バックアップ側")
        XCTAssertEqual(result.replaced.moodEntries, 1)
    }

    func testRestoreFailureRollsBackInsertionsAndReplacements() throws {
        let conflictID = UUID()
        context.insert(makeMoodEntry(id: conflictID, notes: "保存済み"))
        try context.save()
        let archive = DiaryArchiveV1(
            moodEntries: [
                archivedMood(id: conflictID, notes: "置換予定"),
                archivedMood(id: UUID(), notes: "追加予定")
            ],
            assessments: [],
            safetyChecks: []
        )

        XCTAssertThrowsError(
            try DiaryArchiveDataService.restore(
                archive: archive,
                conflictPolicy: .replaceWithBackup,
                in: context,
                persist: { _ in throw TestError.forcedFailure }
            )
        )

        let entries = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, conflictID)
        XCTAssertEqual(entries.first?.notes, "保存済み")
    }

    func testDeleteFailureRestoresEveryModelType() throws {
        _ = try insertOneOfEach()

        XCTAssertThrowsError(
            try DiaryArchiveDataService.deleteAll(
                in: context,
                persist: { _ in throw TestError.forcedFailure }
            )
        )

        XCTAssertEqual(
            try DiaryArchiveDataService.counts(in: context),
            DiaryDataCounts(moodEntries: 1, assessments: 1, safetyChecks: 1)
        )
    }

    func testDeleteAllCommitsAllTypesTogether() throws {
        _ = try insertOneOfEach()

        let deleted = try DiaryArchiveDataService.deleteAll(in: context)

        XCTAssertEqual(deleted, DiaryDataCounts(moodEntries: 1, assessments: 1, safetyChecks: 1))
        XCTAssertEqual(try DiaryArchiveDataService.counts(in: context), .zero)
    }

    private func insertOneOfEach() throws -> (mood: UUID, assessment: UUID, safety: UUID) {
        let mood = makeMoodEntry(id: UUID(), notes: "端末内のメモ")
        let assessment = MentalHealthAssessment()
        assessment.id = UUID()
        assessment.selectedTests = ["スマホ利用の振り返り"]
        assessment.notes = "事実ベースの振り返り"
        let safety = LightSafetyCheckRecord(date: Date(timeIntervalSince1970: 1_785_484_800))
        safety.id = UUID()
        context.insert(mood)
        context.insert(assessment)
        context.insert(safety)
        try context.save()
        return (mood.id, assessment.id, safety.id)
    }

    private func makeMoodEntry(id: UUID, notes: String) -> MoodEntry {
        archivedMood(id: id, notes: notes).makeModel()
    }

    private func archivedMood(id: UUID, notes: String) -> ArchivedMoodEntry {
        ArchivedMoodEntry(
            id: id,
            date: Date(timeIntervalSince1970: 1_785_484_800),
            mood: "普通",
            moodScore: 4,
            recordType: "瞬間記録",
            emotions: [],
            notes: notes,
            activities: [],
            gratitude: "",
            reflections: "",
            influences: [],
            lifeFactors: []
        )
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: MoodEntry.self,
            MentalHealthAssessment.self,
            LightSafetyCheckRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private enum TestError: Error {
        case forcedFailure
    }
}

@MainActor
final class AppLockControllerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "AppLockControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testEnableBackgroundUnlockAndDisableUseDeviceAuthentication() async {
        var authenticationCount = 0
        let client = DeviceOwnerAuthenticationClient { _ in
            authenticationCount += 1
        }
        let controller = AppLockController(
            defaults: defaults,
            authenticationClient: client
        )

        let didEnable = await controller.enableLock()
        XCTAssertTrue(didEnable)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertFalse(controller.isLocked)

        controller.protectForBackground()
        XCTAssertTrue(controller.isLocked)
        XCTAssertTrue(controller.isPrivacyShieldVisible)

        let didUnlock = await controller.authenticateForUnlock()
        XCTAssertTrue(didUnlock)
        XCTAssertFalse(controller.isLocked)
        XCTAssertFalse(controller.isPrivacyShieldVisible)

        let didDisable = await controller.disableLock()
        XCTAssertTrue(didDisable)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(authenticationCount, 3)
        XCTAssertFalse(defaults.bool(forKey: AppLockController.defaultsKey))
    }

    func testFailedEnableDoesNotPersistOrLeaveBlockingShield() async {
        let client = DeviceOwnerAuthenticationClient { _ in
            throw DeviceOwnerAuthenticationError.passcodeNotSet
        }
        let controller = AppLockController(
            defaults: defaults,
            authenticationClient: client
        )

        let didEnable = await controller.enableLock()
        XCTAssertFalse(didEnable)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertFalse(controller.isLocked)
        XCTAssertFalse(controller.isPrivacyShieldVisible)
        XCTAssertEqual(
            controller.errorMessage,
            DeviceOwnerAuthenticationError.passcodeNotSet.errorDescription
        )
    }

    func testPreviouslyEnabledLockStartsProtected() {
        defaults.set(true, forKey: AppLockController.defaultsKey)

        let controller = AppLockController(
            defaults: defaults,
            authenticationClient: DeviceOwnerAuthenticationClient { _ in }
        )

        XCTAssertTrue(controller.isEnabled)
        XCTAssertTrue(controller.isLocked)
        XCTAssertTrue(controller.isPrivacyShieldVisible)
    }

    func testFailedUnlockKeepsPrivacyShieldVisible() async {
        defaults.set(true, forKey: AppLockController.defaultsKey)
        let controller = AppLockController(
            defaults: defaults,
            authenticationClient: DeviceOwnerAuthenticationClient { _ in
                throw DeviceOwnerAuthenticationError.failed
            }
        )

        let didUnlock = await controller.authenticateForUnlock()

        XCTAssertFalse(didUnlock)
        XCTAssertTrue(controller.isLocked)
        XCTAssertTrue(controller.isPrivacyShieldVisible)
    }

    func testBackgroundInvalidatesPendingUnlockResult() async {
        defaults.set(true, forKey: AppLockController.defaultsKey)
        let gate = AuthenticationGate()
        let controller = AppLockController(
            defaults: defaults,
            authenticationClient: DeviceOwnerAuthenticationClient { _ in
                try await gate.wait()
            }
        )

        let unlockTask = Task { @MainActor in
            await controller.authenticateForUnlock()
        }
        await gate.waitUntilStarted()

        controller.protectForBackground()
        await gate.succeed()

        let didUnlock = await unlockTask.value
        XCTAssertFalse(didUnlock)
        XCTAssertTrue(controller.isLocked)
        XCTAssertTrue(controller.isPrivacyShieldVisible)
    }
}

private actor AuthenticationGate {
    private var continuation: CheckedContinuation<Void, Error>?

    func wait() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilStarted() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func succeed() {
        continuation?.resume()
        continuation = nil
    }
}

final class AppDataProtectionConfigurationTests: XCTestCase {
    func testAppBundleDeclaresFaceIDReasonAndBackupType() throws {
        let bundle = Bundle.main
        XCTAssertEqual(
            bundle.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") as? String,
            "日記の記録を開くためにFace IDを使用します。"
        )

        let declarations = try XCTUnwrap(
            bundle.object(forInfoDictionaryKey: "UTExportedTypeDeclarations")
                as? [[String: Any]]
        )
        let backupType = try XCTUnwrap(
            declarations.first { declaration in
                declaration["UTTypeIdentifier"] as? String
                    == UTType.yohakuJournalBackup.identifier
            },
            "UTExportedTypeDeclarations にバックアップ用UTIがありません。"
        )
        let tags = try XCTUnwrap(
            backupType["UTTypeTagSpecification"] as? [String: Any]
        )
        XCTAssertEqual(
            backupType["UTTypeDescription"] as? String,
            "Science Club Diary 暗号化バックアップ"
        )
        XCTAssertEqual(
            tags["public.filename-extension"] as? [String],
            ["yohakubackup"]
        )
        XCTAssertEqual(
            tags["public.mime-type"] as? [String],
            ["application/vnd.viuk.scienceclub.diary.backup"]
        )
    }

    func testCompleteFileProtectionCanBeAppliedAndReadBack() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiaryProtectionTests-\(UUID().uuidString)")
        let file = directory.appendingPathComponent("protected.data")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("protected".utf8).write(to: file)

#if targetEnvironment(simulator)
        do {
            try DiaryFileProtectionService.applyCompleteProtection(to: file)
            try assertCompleteProtection(at: file)
        } catch {
            guard let protectionError = error as? DiaryFileProtectionError,
                  protectionError == .protectionCouldNotBeConfirmed else {
                throw error
            }
            throw XCTSkip("Simulatorは.completeファイル保護を再現しません。実機で検証してください。")
        }
#else
        try DiaryFileProtectionService.applyCompleteProtection(to: file)
        try assertCompleteProtection(at: file)
#endif
    }

    func testStoreProtectionDoesNotReportSuccessBeforeStoreExists() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiaryStoreProtectionTests-\(UUID().uuidString)")
        let store = directory.appendingPathComponent("Diary.store")
        defer { try? FileManager.default.removeItem(at: directory) }

        let report = DiaryFileProtectionService.prepareStore(at: store)

        XCTAssertFalse(report.isProtected)
        XCTAssertTrue(report.warning?.contains("保存ファイルがまだ作成されていない") == true)
    }

    private func assertCompleteProtection(at url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let protection = attributes[.protectionKey]
        let isComplete = (protection as? FileProtectionType) == .complete
            || (protection as? String) == FileProtectionType.complete.rawValue
        XCTAssertTrue(isComplete)
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
