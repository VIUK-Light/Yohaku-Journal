import CoreGraphics
import XCTest
@testable import Science_Club_Diary

final class PlatformLayoutTests: XCTestCase {
    func testLegacyPortraitMacWindowUsesLandscapeDefault() {
        XCTAssertEqual(
            DiaryRuntime.normalizedMacWindowSize(for: CGSize(width: 640, height: 900)),
            DiaryRuntime.macWindowDefaultSize
        )
    }

    func testSmallLandscapeMacWindowExpandsToMinimumSize() {
        XCTAssertEqual(
            DiaryRuntime.normalizedMacWindowSize(for: CGSize(width: 900, height: 620)),
            DiaryRuntime.macWindowMinimumSize
        )
    }

    func testUserSizedWindowThatMeetsMinimumIsPreserved() {
        XCTAssertNil(
            DiaryRuntime.normalizedMacWindowSize(for: CGSize(width: 1400, height: 900))
        )
    }
}
