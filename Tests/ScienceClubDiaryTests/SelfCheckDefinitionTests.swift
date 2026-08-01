import Foundation
import SwiftData
import XCTest
@testable import Science_Club_Diary

@MainActor
final class SelfCheckDefinitionTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: MentalHealthAssessment.self,
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

    func testStandardizedChecksRemainUnavailableUntilVerification() {
        for type in SelfCheckType.allCases {
            XCTAssertFalse(type.definition.sourceStatus.isEmpty)
        }
        XCTAssertFalse(SelfCheckType.phq9.definition.availability.isAvailable)
        XCTAssertFalse(SelfCheckType.gad7.definition.availability.isAvailable)
        XCTAssertTrue(SelfCheckType.mutualLove.definition.availability.isAvailable)
        XCTAssertEqual(SelfCheckType.mutualLove.definition.evidenceLevel, .guidedReflection)
    }

    func testOnlyChecksWithCrisisItemsRequireSafetyGate() {
        XCTAssertTrue(SelfCheckType.phq9.requiresSafetyGate)
        XCTAssertFalse(SelfCheckType.gad7.requiresSafetyGate)
        XCTAssertFalse(SelfCheckType.k6.requiresSafetyGate)
        XCTAssertFalse(SelfCheckType.k10.requiresSafetyGate)
        XCTAssertFalse(SelfCheckType.mutualLove.requiresSafetyGate)
        XCTAssertFalse(SelfCheckType.romanticSign.requiresSafetyGate)
        XCTAssertFalse(SelfCheckType.smartphoneBrain.requiresSafetyGate)
        XCTAssertFalse(SelfCheckType.stressCheck.requiresSafetyGate)
    }

    func testSessionProducesFactualResponseCountsWithoutSeverity() {
        let session = SelfCheckSession(
            type: .smartphoneBrain,
            answers: [0, 1, 1, -1, 3]
        )

        let result = session.makeResult()

        XCTAssertEqual(result.answeredCount, 4)
        XCTAssertEqual(result.unansweredCount, 8)
        XCTAssertTrue(result.factualSummary.contains("回答 4件"))
        XCTAssertFalse(result.factualSummary.contains("重度"))
    }

    func testAssessmentSaveServiceKeepsAnswersAndUsesFactBasedNotes() throws {
        let draft = SelfCheckResultDraft(
            selectedTests: [.mutualLove],
            phq9Answers: [],
            gad7Answers: [],
            k6Answers: [],
            k10Answers: [],
            mutualLoveAnswers: [0, 1, 2],
            romanticSignAnswers: [],
            smartphoneBrainAnswers: [],
            stressCheckAnswers: []
        )

        let assessment = try MentalHealthAssessmentSaveService().save(draft: draft, in: context)

        XCTAssertEqual(assessment.selectedTests, [SelfCheckType.mutualLove.rawValue])
        XCTAssertTrue(assessment.notes.contains("回答 3件"))
        XCTAssertFalse(assessment.notes.contains("スコア"))
    }

    func testSafetyCheckServiceStoresOnlyTheConfirmationDate() throws {
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let record = try SafetyCheckSaveService().saveCheckDate(date, in: context)

        XCTAssertEqual(record.date, date)
        let fetched = try context.fetch(FetchDescriptor<LightSafetyCheckRecord>())
        XCTAssertEqual(fetched.count, 1)
    }
}
