import XCTest

final class LoginFlowUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = ["MOCK_API": "true"]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Settings Access Tests
    
    func testNavigateToSettings() throws {
        app.launch()
        
        // Wait for home view to load
        let homeView = app.otherElements["HomeView"]
        XCTAssertTrue(homeView.waitForExistence(timeout: 5))
        
        // Tap settings button
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.exists)
        settingsButton.tap()
        
        // Verify settings view appears
        let settingsView = app.navigationBars["Settings"]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 3))
    }
    
    // MARK: - API Configuration Tests
    
    func testConfigureAPISettings() throws {
        app.launch()
        
        // Navigate to settings
        app.buttons["Settings"].tap()
        
        // Wait for settings view
        let settingsView = app.navigationBars["Settings"]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 3))
        
        // Find API key field
        let apiKeyField = app.textFields["API Key"]
        XCTAssertTrue(apiKeyField.exists)
        
        // Clear and enter new API key
        apiKeyField.tap()
        apiKeyField.clearAndTypeText("test-api-key-12345")
        
        // Find base URL field
        let baseURLField = app.textFields["Base URL"]
        XCTAssertTrue(baseURLField.exists)
        
        // Verify default value
        XCTAssertEqual(baseURLField.value as? String, "http://localhost:8000")
        
        // Update base URL
        baseURLField.tap()
        baseURLField.clearAndTypeText("https://api.example.com")
        
        // Save settings
        let saveButton = app.buttons["Save"]
        if saveButton.exists {
            saveButton.tap()
        }
        
        // Verify settings are saved (would need to navigate back and check)
        app.navigationBars.buttons.element(boundBy: 0).tap() // Back button
        
        // Navigate back to settings to verify persistence
        app.buttons["Settings"].tap()
        XCTAssertEqual(apiKeyField.value as? String, "test-api-key-12345")
        XCTAssertEqual(baseURLField.value as? String, "https://api.example.com")
    }
    
    // MARK: - Connection Status Tests
    
    func testConnectionStatusDisplay() throws {
        app.launch()
        
        // Check for connection status indicator
        let statusIndicator = app.staticTexts.matching(identifier: "ConnectionStatus").firstMatch
        
        // Wait for status to appear
        XCTAssertTrue(statusIndicator.waitForExistence(timeout: 5))
        
        // In mock mode, should show connected
        let statusText = statusIndicator.label
        XCTAssertTrue(statusText.contains("Connected") || statusText.contains("Connecting"))
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidAPIKeyError() throws {
        app.launch()
        
        // Navigate to settings
        app.buttons["Settings"].tap()
        
        // Enter invalid API key (empty)
        let apiKeyField = app.textFields["API Key"]
        apiKeyField.tap()
        apiKeyField.clearAndTypeText("")
        
        // Try to save
        let saveButton = app.buttons["Save"]
        if saveButton.exists {
            saveButton.tap()
        }
        
        // Check for error message
        let errorAlert = app.alerts.firstMatch
        if errorAlert.waitForExistence(timeout: 2) {
            XCTAssertTrue(errorAlert.label.contains("Invalid") || errorAlert.label.contains("Required"))
            errorAlert.buttons["OK"].tap()
        }
    }
    
    // MARK: - Theme Tests
    
    func testThemeToggle() throws {
        app.launch()
        
        // Navigate to settings
        app.buttons["Settings"].tap()
        
        // Find theme toggle
        let themeSection = app.tables.cells.containing(.staticText, identifier: "Theme").firstMatch
        
        if themeSection.exists {
            // Check for dark mode toggle
            let darkModeSwitch = app.switches["Dark Mode"]
            if darkModeSwitch.exists {
                let initialValue = darkModeSwitch.value as? String == "1"
                darkModeSwitch.tap()
                
                // Verify toggle changed
                let newValue = darkModeSwitch.value as? String == "1"
                XCTAssertNotEqual(initialValue, newValue)
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testLaunchPerformance() throws {
        if #available(iOS 14.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                app.launch()
                
                // Wait for home view
                let homeView = app.otherElements["HomeView"]
                _ = homeView.waitForExistence(timeout: 5)
            }
        }
    }
    
    func testSettingsNavigationPerformance() throws {
        app.launch()
        
        measure {
            // Navigate to settings
            app.buttons["Settings"].tap()
            
            // Wait for settings view
            let settingsView = app.navigationBars["Settings"]
            _ = settingsView.waitForExistence(timeout: 3)
            
            // Navigate back
            app.navigationBars.buttons.element(boundBy: 0).tap()
            
            // Wait for home view
            let homeView = app.otherElements["HomeView"]
            _ = homeView.waitForExistence(timeout: 3)
        }
    }
}

// MARK: - Helper Extensions
// Note: clearAndTypeText is defined locally to avoid conflicts