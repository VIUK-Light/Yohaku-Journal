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
}
