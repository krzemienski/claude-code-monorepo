import XCTest
@testable import ClaudeCodeCore

final class CoreModuleTests: XCTestCase {
    
    func testCoreModuleInitialization() {
        // Given
        let module = CoreModule.shared
        
        // When
        module.initialize()
        
        // Then
        XCTAssertNotNil(module)
    }
    
    func testAPIClientConfiguration() {
        // Add tests for APIClient
    }
    
    func testKeychainService() {
        // Add tests for KeychainService
    }
}