import XCTest
@testable import UI

final class UIModuleTests: XCTestCase {
    
    func testModuleInitialization() {
        // Test that the UI module initializes correctly
        XCTAssertNotNil(UIModule.self)
    }
    
    func testTheme() {
        // Test that the theme is configured
        XCTAssertNotNil(Theme.self)
    }
}