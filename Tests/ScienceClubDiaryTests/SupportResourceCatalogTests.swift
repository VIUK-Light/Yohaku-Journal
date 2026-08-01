import XCTest
@testable import Science_Club_Diary

final class SupportResourceCatalogTests: XCTestCase {
    func testSupportCatalogHasUniqueValidatedDestinationsAndOfficialSources() {
        let resources = SupportResourceCatalog.resources

        XCTAssertEqual(Set(resources.map(\.id)).count, resources.count)
        XCTAssertFalse(resources.isEmpty)

        for resource in resources {
            XCTAssertNotNil(resource.destinationURL, resource.id)
            XCTAssertEqual(resource.sourceURL?.scheme, "https", resource.id)
            XCTAssertEqual(resource.lastVerified, SupportResourceCatalog.lastVerified, resource.id)

            switch resource.contactKind {
            case .phone:
                XCTAssertEqual(resource.destinationURL?.scheme, "tel", resource.id)
            case .web:
                XCTAssertEqual(resource.destinationURL?.scheme, "https", resource.id)
            }
        }
    }

    func testOfficialPhoneDetailsMatchVerifiedCatalog() {
        let resources = Dictionary(
            uniqueKeysWithValues: SupportResourceCatalog.resources.map { ($0.id, $0) }
        )

        XCTAssertEqual(resources["inochi-sos"]?.contactLabel, "0120-061-338")
        XCTAssertEqual(resources["inochi-sos"]?.availability, "24時間・365日")
        XCTAssertEqual(resources["yorisoi-hotline"]?.contactLabel, "0120-279-338")
        XCTAssertEqual(resources["yorisoi-hotline"]?.availability, "24時間対応（050は050-3655-0279）")
        XCTAssertEqual(resources["child-sos-24h"]?.contactLabel, "0120-0-78310")
        XCTAssertEqual(resources["childline"]?.contactLabel, "0120-99-7777")
        XCTAssertEqual(resources["public-mental-health"]?.contactLabel, "0570-064-556")
    }

    func testAnonymousChatResourceHasDirectOfficialDestination() {
        let resource = SupportResourceCatalog.resources.first { $0.id == "anata-no-ibasho" }

        XCTAssertEqual(resource?.name, "あなたのいばしょ")
        XCTAssertEqual(resource?.availability, "24時間・365日")
        XCTAssertEqual(resource?.contactKind, .web)
        XCTAssertEqual(resource?.destinationString, "https://talkme.jp/")
        XCTAssertEqual(
            resource?.sourceURLString,
            "https://www.mhlw.go.jp/mamorouyokokoro/soudan/sns/"
        )
    }

    func testNonClinicalReflectionsDoNotRequireSafetyGate() {
        XCTAssertFalse(MentalHealthCheckView.TestType.mutualLove.requiresSafetyGate)
        XCTAssertFalse(MentalHealthCheckView.TestType.romanticSign.requiresSafetyGate)
        XCTAssertFalse(MentalHealthCheckView.TestType.smartphoneBrain.requiresSafetyGate)
    }

    func testStandardizedChecksRequireSafetyGateWhenReenabled() {
        let standardizedChecks: [MentalHealthCheckView.TestType] = [
            .phq9,
            .gad7,
            .k6,
            .k10,
            .stressCheck
        ]

        XCTAssertTrue(standardizedChecks.allSatisfy(\.requiresSafetyGate))
    }
}
