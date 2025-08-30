import XCTest
@testable import ClaudeCodeFeatures

final class FeaturesModuleTests: XCTestCase {
    
    func testFeaturesModuleInitialization() {
        // Given
        let module = FeaturesModule.shared
        
        // When
        module.initialize()
        
        // Then
        XCTAssertNotNil(module)
    }
    
    func testHomeViewCreation() {
        // Add tests for HomeView
    }
    
    func testSessionsViewCreation() {
        // Add tests for SessionsView
    }
}