import XCTest

// MARK: - Core User Flow UI Tests
final class CoreFlowTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launchEnvironment = [
            "API_BASE_URL": "http://localhost:8000",
            "USE_MOCK_DATA": "true"
        ]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
            
            // Wait for main screen
            let homeTab = app.tabBars.buttons["Home"]
            XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        }
    }
    
    func testInitialLaunchFlow() throws {
        app.launch()
        
        // Verify tab bar is present
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible")
        
        // Verify all tabs are present
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
        XCTAssertTrue(app.tabBars.buttons["Projects"].exists)
        XCTAssertTrue(app.tabBars.buttons["Sessions"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
        
        // Verify home screen is default
        XCTAssertTrue(app.navigationBars["Dashboard"].exists)
    }
    
    // MARK: - Authentication Flow Tests
    
    func testAuthenticationFlow() throws {
        app.launch()
        
        // Navigate to settings
        app.tabBars.buttons["Settings"].tap()
        
        // Find API key field
        let apiKeyField = app.textFields["API Key"]
        XCTAssertTrue(apiKeyField.waitForExistence(timeout: 3))
        
        // Clear and enter new API key
        apiKeyField.tap()
        apiKeyField.clearAndTypeText("test-api-key-12345")
        
        // Find base URL field
        let baseURLField = app.textFields["Base URL"]
        XCTAssertTrue(baseURLField.exists)
        
        // Save settings
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        
        // Verify success message or navigation
        let successAlert = app.alerts["Settings Saved"]
        if successAlert.waitForExistence(timeout: 2) {
            successAlert.buttons["OK"].tap()
        }
    }
    
    func testInvalidAPIKeyHandling() throws {
        app.launch()
        
        // Navigate to settings
        app.tabBars.buttons["Settings"].tap()
        
        // Enter invalid API key
        let apiKeyField = app.textFields["API Key"]
        apiKeyField.tap()
        apiKeyField.clearAndTypeText("")
        
        // Try to save
        app.buttons["Save"].tap()
        
        // Verify error is shown
        let errorText = app.staticTexts["API key is required"]
        XCTAssertTrue(errorText.waitForExistence(timeout: 2))
    }
    
    // MARK: - Project Management Flow Tests
    
    func testCreateProjectFlow() throws {
        app.launch()
        
        // Navigate to projects
        app.tabBars.buttons["Projects"].tap()
        
        // Tap create button
        let createButton = app.navigationBars.buttons["Add"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        createButton.tap()
        
        // Fill in project details
        let nameField = app.textFields["Project Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Test Project")
        
        let descriptionField = app.textViews["Description"]
        if descriptionField.exists {
            descriptionField.tap()
            descriptionField.typeText("This is a test project for UI testing")
        }
        
        // Create project
        app.buttons["Create"].tap()
        
        // Verify project appears in list
        let projectCell = app.cells.containing(.staticText, identifier: "Test Project").firstMatch
        XCTAssertTrue(projectCell.waitForExistence(timeout: 5))
    }
    
    func testSelectProjectFlow() throws {
        app.launch()
        
        // Navigate to projects
        app.tabBars.buttons["Projects"].tap()
        
        // Wait for project list
        let projectsList = app.tables.firstMatch
        XCTAssertTrue(projectsList.waitForExistence(timeout: 3))
        
        // Select first project if exists
        if app.cells.count > 0 {
            app.cells.firstMatch.tap()
            
            // Verify project detail view or selection state
            let backButton = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(backButton.exists || app.staticTexts["Selected"].exists)
        }
    }
    
    // MARK: - Session Management Flow Tests
    
    func testCreateSessionFlow() throws {
        app.launch()
        
        // Navigate to sessions
        app.tabBars.buttons["Sessions"].tap()
        
        // Create new session
        let createButton = app.navigationBars.buttons["Add"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        createButton.tap()
        
        // Select model
        let modelPicker = app.pickers["Model"]
        if modelPicker.waitForExistence(timeout: 2) {
            modelPicker.pickerWheels.firstMatch.adjust(toPickerWheelValue: "GPT-4")
        }
        
        // Enter session title
        let titleField = app.textFields["Session Title"]
        if titleField.exists {
            titleField.tap()
            titleField.typeText("Test Chat Session")
        }
        
        // Create session
        app.buttons["Create Session"].tap()
        
        // Verify navigation to chat
        let chatView = app.otherElements["ChatView"]
        XCTAssertTrue(chatView.waitForExistence(timeout: 5) || app.textViews["MessageInput"].exists)
    }
    
    func testChatInteractionFlow() throws {
        app.launch()
        
        // Navigate to sessions
        app.tabBars.buttons["Sessions"].tap()
        
        // Select or create a session
        if app.cells.count > 0 {
            app.cells.firstMatch.tap()
        } else {
            // Create new session if none exist
            app.navigationBars.buttons["Add"].tap()
            app.buttons["Create Session"].tap()
        }
        
        // Wait for chat view
        let messageInput = app.textViews["MessageInput"]
        XCTAssertTrue(messageInput.waitForExistence(timeout: 5))
        
        // Type a message
        messageInput.tap()
        messageInput.typeText("Hello, this is a test message")
        
        // Send message
        let sendButton = app.buttons["Send"]
        XCTAssertTrue(sendButton.exists)
        sendButton.tap()
        
        // Verify message appears
        let messageCell = app.cells.containing(.staticText, identifier: "Hello, this is a test message").firstMatch
        XCTAssertTrue(messageCell.waitForExistence(timeout: 5))
    }
    
    // MARK: - MCP Server Management Tests
    
    func testMCPServerToggle() throws {
        app.launch()
        
        // Navigate to MCP settings (might be in Settings or separate tab)
        if app.tabBars.buttons["MCP"].exists {
            app.tabBars.buttons["MCP"].tap()
        } else {
            app.tabBars.buttons["Settings"].tap()
            app.cells["MCP Servers"].tap()
        }
        
        // Find server toggle
        let serverSwitch = app.switches.firstMatch
        if serverSwitch.waitForExistence(timeout: 3) {
            let initialValue = serverSwitch.value as? String == "1"
            serverSwitch.tap()
            
            // Verify toggle changed
            let newValue = serverSwitch.value as? String == "1"
            XCTAssertNotEqual(initialValue, newValue)
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        app.launch()
        
        // Test VoiceOver labels
        XCTAssertTrue(app.tabBars.buttons["Home"].isAccessibilityElement)
        XCTAssertNotNil(app.tabBars.buttons["Home"].label)
        
        XCTAssertTrue(app.tabBars.buttons["Projects"].isAccessibilityElement)
        XCTAssertNotNil(app.tabBars.buttons["Projects"].label)
        
        XCTAssertTrue(app.tabBars.buttons["Sessions"].isAccessibilityElement)
        XCTAssertNotNil(app.tabBars.buttons["Sessions"].label)
        
        XCTAssertTrue(app.tabBars.buttons["Settings"].isAccessibilityElement)
        XCTAssertNotNil(app.tabBars.buttons["Settings"].label)
    }
    
    func testAccessibilityNavigation() throws {
        app.launch()
        
        // Test keyboard navigation
        let firstElement = app.descendants(matching: .any).firstMatch
        XCTAssertTrue(firstElement.exists)
        
        // Verify focus indicators and navigation order
        // This would require more specific accessibility testing setup
    }
    
    // MARK: - Dark Mode Tests
    
    func testDarkModeAppearance() throws {
        // Launch in dark mode
        app.launchArguments.append("--dark-mode")
        app.launch()
        
        // Verify UI adapts to dark mode
        // This would check specific color values or assets
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - Orientation Tests
    
    func testOrientationChanges() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Orientation test only for iPad")
        }
        
        app.launch()
        
        // Test portrait
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.tabBars.firstMatch.exists)
        
        // Test landscape
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.tabBars.firstMatch.exists || app.splitGroups.firstMatch.exists)
        
        // Return to portrait
        XCUIDevice.shared.orientation = .portrait
    }
    
    // MARK: - Performance Monitoring Tests
    
    func testScrollingPerformance() throws {
        app.launch()
        
        // Navigate to a list view
        app.tabBars.buttons["Sessions"].tap()
        
        // Measure scrolling performance
        let table = app.tables.firstMatch
        if table.waitForExistence(timeout: 3) {
            measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
                table.swipeUp()
                table.swipeDown()
            }
        }
    }
    
    func testMemoryUsage() throws {
        app.launch()
        
        let metrics: [XCTMetric] = [
            XCTMemoryMetric(application: app),
            XCTCPUMetric(application: app)
        ]
        
        measure(metrics: metrics) {
            // Navigate through all main screens
            app.tabBars.buttons["Home"].tap()
            app.tabBars.buttons["Projects"].tap()
            app.tabBars.buttons["Sessions"].tap()
            app.tabBars.buttons["Settings"].tap()
        }
    }
    
    // MARK: - Error Recovery Tests
    
    func testNetworkErrorRecovery() throws {
        app.launchEnvironment["SIMULATE_NETWORK_ERROR"] = "true"
        app.launch()
        
        // Try to load data
        app.tabBars.buttons["Projects"].tap()
        
        // Verify error message
        let errorMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'error'")).firstMatch
        XCTAssertTrue(errorMessage.waitForExistence(timeout: 5))
        
        // Try retry
        if app.buttons["Retry"].exists {
            app.buttons["Retry"].tap()
        }
    }
}

// MARK: - Helper Extensions
// Note: clearAndTypeText is defined locally to avoid conflicts