import XCTest

final class ChatFlowUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = [
            "BASE_URL": "http://localhost:8000",
            "MOCK_API": "false"
        ]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Onboarding Tests
    
    func testFirstLaunchShowsOnboarding() throws {
        // Given: First launch
        
        // Then: Onboarding view should be visible
        XCTAssertTrue(app.staticTexts["Welcome to Claude Code"].exists)
        XCTAssertTrue(app.buttons["Get Started"].exists)
    }
    
    func testOnboardingConfiguresSettings() throws {
        // Given: Onboarding screen
        let getStartedButton = app.buttons["Get Started"]
        getStartedButton.tap()
        
        // When: Configure settings
        let baseURLField = app.textFields["Base URL"]
        XCTAssertTrue(baseURLField.exists)
        baseURLField.tap()
        baseURLField.clearAndType("http://localhost:8000")
        
        let apiKeyField = app.secureTextFields["API Key"]
        XCTAssertTrue(apiKeyField.exists)
        apiKeyField.tap()
        apiKeyField.typeText("test-api-key")
        
        // Then: Save and continue
        app.buttons["Save & Continue"].tap()
        XCTAssertTrue(app.tabBars.buttons["Chat"].exists)
    }
    
    // MARK: - Tab Navigation Tests
    
    func testTabBarNavigation() throws {
        // Given: Main app screen
        skipOnboardingIfNeeded()
        
        // When/Then: Navigate through tabs
        let tabBar = app.tabBars.firstMatch
        
        // Chat tab
        tabBar.buttons["Chat"].tap()
        XCTAssertTrue(app.navigationBars["Chat"].exists)
        
        // Projects tab
        tabBar.buttons["Projects"].tap()
        XCTAssertTrue(app.navigationBars["Projects"].exists)
        
        // Files tab
        tabBar.buttons["Files"].tap()
        XCTAssertTrue(app.navigationBars["Files"].exists)
        
        // Analytics tab
        tabBar.buttons["Analytics"].tap()
        XCTAssertTrue(app.navigationBars["Analytics"].exists)
        
        // Settings tab
        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }
    
    // MARK: - Chat Flow Tests
    
    func testSendingChatMessage() throws {
        // Given: Chat screen
        skipOnboardingIfNeeded()
        app.tabBars.buttons["Chat"].tap()
        
        // When: Send a message
        let messageField = app.textFields["Message"]
        XCTAssertTrue(messageField.exists)
        messageField.tap()
        messageField.typeText("Hello, Claude!")
        
        let sendButton = app.buttons["Send"]
        XCTAssertTrue(sendButton.exists)
        sendButton.tap()
        
        // Then: Message appears in chat
        let sentMessage = app.staticTexts["Hello, Claude!"]
        XCTAssertTrue(sentMessage.waitForExistence(timeout: 5))
        
        // And: Response is received
        let responseIndicator = app.activityIndicators["Typing"]
        XCTAssertTrue(responseIndicator.waitForExistence(timeout: 2))
    }
    
    func testStreamingResponse() throws {
        // Given: Chat with active conversation
        skipOnboardingIfNeeded()
        app.tabBars.buttons["Chat"].tap()
        
        // When: Send a message that triggers streaming
        let messageField = app.textFields["Message"]
        messageField.tap()
        messageField.typeText("Count to 5")
        app.buttons["Send"].tap()
        
        // Then: Streaming indicator appears
        let streamingIndicator = app.progressIndicators["StreamingProgress"]
        XCTAssertTrue(streamingIndicator.waitForExistence(timeout: 2))
        
        // And: Content updates incrementally
        let partialResponse = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '1'"))
        XCTAssertTrue(partialResponse.firstMatch.waitForExistence(timeout: 5))
    }
    
    // MARK: - Session Management Tests
    
    func testCreatingNewSession() throws {
        // Given: Chat screen
        skipOnboardingIfNeeded()
        app.tabBars.buttons["Chat"].tap()
        
        // When: Create new session
        app.navigationBars["Chat"].buttons["New Session"].tap()
        
        let sessionNameField = app.textFields["Session Name"]
        XCTAssertTrue(sessionNameField.exists)
        sessionNameField.tap()
        sessionNameField.typeText("Test Session")
        
        app.buttons["Create"].tap()
        
        // Then: New session is active
        XCTAssertTrue(app.navigationBars["Test Session"].exists)
    }
    
    func testSwitchingBetweenSessions() throws {
        // Given: Multiple sessions
        skipOnboardingIfNeeded()
        createTestSession(named: "Session 1")
        createTestSession(named: "Session 2")
        
        // When: Switch sessions
        app.navigationBars.buttons["Sessions"].tap()
        app.cells["Session 1"].tap()
        
        // Then: Session 1 is active
        XCTAssertTrue(app.navigationBars["Session 1"].exists)
        
        // When: Switch to Session 2
        app.navigationBars.buttons["Sessions"].tap()
        app.cells["Session 2"].tap()
        
        // Then: Session 2 is active
        XCTAssertTrue(app.navigationBars["Session 2"].exists)
    }
    
    // MARK: - MCP Tools Tests
    
    func testEnablingMCPTools() throws {
        // Given: Session with MCP configuration
        skipOnboardingIfNeeded()
        app.tabBars.buttons["Chat"].tap()
        
        // When: Open tools configuration
        app.navigationBars.buttons["Tools"].tap()
        
        // Then: Tool list is displayed
        XCTAssertTrue(app.staticTexts["Available Tools"].exists)
        XCTAssertTrue(app.switches["Filesystem"].exists)
        XCTAssertTrue(app.switches["Bash Commands"].exists)
        
        // When: Enable a tool
        let filesystemSwitch = app.switches["Filesystem"]
        filesystemSwitch.tap()
        
        // Then: Tool is enabled
        XCTAssertEqual(filesystemSwitch.value as? String, "1")
    }
    
    func testToolPriorityReordering() throws {
        // Given: Tools configuration screen
        skipOnboardingIfNeeded()
        app.tabBars.buttons["Chat"].tap()
        app.navigationBars.buttons["Tools"].tap()
        
        // Enable multiple tools
        app.switches["Filesystem"].tap()
        app.switches["Bash Commands"].tap()
        
        // When: Reorder tools (drag and drop)
        let bashCell = app.cells["Bash Commands"]
        let filesystemCell = app.cells["Filesystem"]
        
        bashCell.press(forDuration: 1.0, thenDragTo: filesystemCell)
        
        // Then: Order is updated
        let firstCell = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstCell.staticTexts["Bash Commands"].exists)
    }
    
    // MARK: - Analytics Tests
    
    func testAnalyticsDashboard() throws {
        // Given: Analytics screen
        skipOnboardingIfNeeded()
        app.tabBars.buttons["Analytics"].tap()
        
        // Then: Dashboard elements are visible
        XCTAssertTrue(app.staticTexts["Total Sessions"].exists)
        XCTAssertTrue(app.staticTexts["Messages Sent"].exists)
        XCTAssertTrue(app.staticTexts["Tokens Used"].exists)
        XCTAssertTrue(app.staticTexts["Response Time"].exists)
        
        // And: Chart is displayed
        XCTAssertTrue(app.otherElements["UsageChart"].exists)
    }
    
    // MARK: - Settings Tests
    
    func testChangingTheme() throws {
        // Given: Settings screen
        skipOnboardingIfNeeded()
        app.tabBars.buttons["Settings"].tap()
        
        // When: Change theme
        app.cells["Appearance"].tap()
        app.buttons["Dark"].tap()
        
        // Then: Theme is applied
        // This would need visual verification or checking specific UI elements
        XCTAssertTrue(app.buttons["Dark"].isSelected)
    }
    
    func testExportingChatHistory() throws {
        // Given: Settings screen with chat history
        skipOnboardingIfNeeded()
        createTestSession(named: "Export Test")
        sendTestMessage("Test message for export")
        
        app.tabBars.buttons["Settings"].tap()
        
        // When: Export chat history
        app.cells["Export Chat History"].tap()
        app.buttons["Export as JSON"].tap()
        
        // Then: Export dialog appears
        XCTAssertTrue(app.alerts["Export Successful"].exists)
        app.alerts.buttons["OK"].tap()
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() throws {
        // Given: No network connection
        app.launchEnvironment = [
            "NETWORK_CONDITION": "offline"
        ]
        app.launch()
        skipOnboardingIfNeeded()
        
        // When: Try to send a message
        app.tabBars.buttons["Chat"].tap()
        let messageField = app.textFields["Message"]
        messageField.tap()
        messageField.typeText("Test message")
        app.buttons["Send"].tap()
        
        // Then: Error alert is shown
        let errorAlert = app.alerts["Connection Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(errorAlert.staticTexts["Unable to connect to server"].exists)
        
        errorAlert.buttons["Retry"].tap()
    }
    
    func testRateLimitHandling() throws {
        // Given: Rate limit scenario
        skipOnboardingIfNeeded()
        app.tabBars.buttons["Chat"].tap()
        
        // When: Send many messages quickly
        for i in 1...10 {
            sendTestMessage("Message \(i)")
        }
        
        // Then: Rate limit warning appears
        let rateLimitAlert = app.alerts["Rate Limit"]
        if rateLimitAlert.waitForExistence(timeout: 5) {
            XCTAssertTrue(rateLimitAlert.staticTexts["Please slow down"].exists)
            rateLimitAlert.buttons["OK"].tap()
        }
    }
    
    // MARK: - Helper Methods
    
    private func skipOnboardingIfNeeded() {
        if app.staticTexts["Welcome to Claude Code"].exists {
            app.buttons["Skip"].tap()
        }
    }
    
    private func createTestSession(named name: String) {
        app.tabBars.buttons["Chat"].tap()
        app.navigationBars.buttons["New Session"].tap()
        
        let sessionNameField = app.textFields["Session Name"]
        sessionNameField.tap()
        sessionNameField.typeText(name)
        app.buttons["Create"].tap()
    }
    
    private func sendTestMessage(_ message: String) {
        let messageField = app.textFields["Message"]
        messageField.tap()
        messageField.typeText(message)
        app.buttons["Send"].tap()
        
        // Wait for message to appear
        _ = app.staticTexts[message].waitForExistence(timeout: 2)
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    func clearAndType(_ text: String) {
        guard let stringValue = self.value as? String else {
            self.typeText(text)
            return
        }
        
        self.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}