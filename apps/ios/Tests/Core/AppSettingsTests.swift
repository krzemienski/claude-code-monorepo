import XCTest
@testable import ClaudeCode

final class AppSettingsTests: XCTestCase {
    
    var sut: AppSettings!
    
    override func setUp() {
        super.setUp()
        // Clear UserDefaults for clean state
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        sut = AppSettings.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Base URL Tests
    
    func testDefaultBaseURL() {
        XCTAssertEqual(sut.baseURL, "http://localhost:8000")
    }
    
    func testSetBaseURL() {
        let newURL = "https://api.claudecode.com"
        sut.baseURL = newURL
        XCTAssertEqual(sut.baseURL, newURL)
        
        // Verify persistence
        let freshSettings = AppSettings()
        XCTAssertEqual(freshSettings.baseURL, newURL)
    }
    
    func testValidateBaseURL() {
        XCTAssertTrue(sut.validateURL("http://localhost:8000"))
        XCTAssertTrue(sut.validateURL("https://api.example.com"))
        XCTAssertTrue(sut.validateURL("http://192.168.1.1:3000"))
        
        XCTAssertFalse(sut.validateURL(""))
        XCTAssertFalse(sut.validateURL("not-a-url"))
        XCTAssertFalse(sut.validateURL("ftp://server.com"))
    }
    
    // MARK: - API Key Tests
    
    func testAPIKeyStorage() {
        let testKey = "test-api-key-12345"
        sut.apiKey = testKey
        
        // Should be stored in keychain, not UserDefaults
        XCTAssertEqual(sut.apiKey, testKey)
        
        // Verify keychain persistence
        let freshSettings = AppSettings()
        XCTAssertEqual(freshSettings.apiKey, testKey)
    }
    
    func testAPIKeyDeletion() {
        sut.apiKey = "test-key"
        XCTAssertNotNil(sut.apiKey)
        
        sut.apiKey = nil
        XCTAssertNil(sut.apiKey)
    }
    
    func testHasValidConfiguration() {
        // No API key
        sut.apiKey = nil
        XCTAssertFalse(sut.hasValidConfiguration)
        
        // With API key but invalid URL
        sut.apiKey = "test-key"
        sut.baseURL = "invalid-url"
        XCTAssertFalse(sut.hasValidConfiguration)
        
        // Valid configuration
        sut.baseURL = "http://localhost:8000"
        sut.apiKey = "test-key"
        XCTAssertTrue(sut.hasValidConfiguration)
    }
    
    // MARK: - Onboarding Tests
    
    func testOnboardingCompletion() {
        XCTAssertFalse(sut.hasCompletedOnboarding)
        
        sut.hasCompletedOnboarding = true
        XCTAssertTrue(sut.hasCompletedOnboarding)
        
        // Verify persistence
        let freshSettings = AppSettings()
        XCTAssertTrue(freshSettings.hasCompletedOnboarding)
    }
    
    // MARK: - Notification Tests
    
    func testNotificationSettings() {
        XCTAssertTrue(sut.notificationsEnabled) // Default
        
        sut.notificationsEnabled = false
        XCTAssertFalse(sut.notificationsEnabled)
        
        // Verify persistence
        let freshSettings = AppSettings()
        XCTAssertFalse(freshSettings.notificationsEnabled)
    }
    
    // MARK: - Reset Tests
    
    func testResetSettings() {
        // Set custom values
        sut.baseURL = "https://custom.api.com"
        sut.apiKey = "custom-key"
        sut.hasCompletedOnboarding = true
        sut.notificationsEnabled = false
        
        // Reset
        sut.reset()
        
        // Verify defaults restored
        XCTAssertEqual(sut.baseURL, "http://localhost:8000")
        XCTAssertNil(sut.apiKey)
        XCTAssertFalse(sut.hasCompletedOnboarding)
        XCTAssertTrue(sut.notificationsEnabled)
    }
}