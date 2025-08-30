import XCTest

final class ClaudeCodeUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = ["UITEST_MODE": "1"]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Launch & Performance Tests
    
    func testLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    func testAppLaunch() {
        app.launch()
        
        // Verify app launches successfully
        XCTAssertTrue(app.exists)
        
        // Check for tab bar
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    }
    
    // MARK: - Navigation Tests
    
    func testTabNavigation() throws {
        app.launch()
        
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Test all tabs
        let tabs = ["Home", "Projects", "Sessions", "MCP", "Settings"]
        
        for tabName in tabs {
            let tab = tabBar.buttons[tabName]
            if tab.exists {
                tab.tap()
                Thread.sleep(forTimeInterval: 0.5)
                XCTAssertTrue(tab.isSelected, "\(tabName) should be selected")
            }
        }
    }
    
    // MARK: - Onboarding Tests
    
    func testOnboardingFlow() {
        app.launchArguments.append("--reset-onboarding")
        app.launch()
        
        // Verify onboarding appears
        let welcomeText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Welcome'")).firstMatch
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5))
        
        // Complete configuration
        if app.buttons["Configure"].exists {
            app.buttons["Configure"].tap()
            
            // Enter base URL
            let baseURLField = app.textFields.firstMatch
            if baseURLField.waitForExistence(timeout: 2) {
                baseURLField.tap()
                baseURLField.typeText("http://localhost:8000")
            }
            
            // Continue
            if app.buttons["Continue"].exists {
                app.buttons["Continue"].tap()
            }
        }
    }
    
    // MARK: - Settings Tests
    
    func testSettingsFlow() throws {
        app.launch()
        
        // Navigate to Settings
        let tabBar = app.tabBars.firstMatch
        let settingsTab = tabBar.buttons["Settings"]
        
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()
            
            // Verify settings screen
            XCTAssertTrue(app.navigationBars["Settings"].exists || 
                         app.staticTexts["Settings"].exists)
            
            // Check for configuration options
            let configCell = app.cells.containing(NSPredicate(format: "label CONTAINS[c] 'Configuration'")).firstMatch
            if configCell.exists {
                configCell.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }
    
    // MARK: - Session Tests
    
    func testCreateNewSession() {
        app.launch()
        
        // Navigate to Sessions
        app.tabBars.buttons["Sessions"].tap()
        
        // Look for new session button
        let newButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'New'")).firstMatch
        if newButton.waitForExistence(timeout: 5) {
            newButton.tap()
            
            // Verify session creation UI appears
            let textField = app.textFields.firstMatch
            XCTAssertTrue(textField.waitForExistence(timeout: 5))
        }
    }
    
    // MARK: - Project Tests
    
    func testProjectList() {
        app.launch()
        
        // Navigate to Projects
        app.tabBars.buttons["Projects"].tap()
        
        // Verify projects screen loads
        let projectsView = app.tables.firstMatch
        XCTAssertTrue(projectsView.waitForExistence(timeout: 5) || 
                     app.collectionViews.firstMatch.waitForExistence(timeout: 5))
    }
    
    // MARK: - MCP Tests
    
    func testMCPServerList() {
        app.launch()
        
        // Navigate to MCP
        app.tabBars.buttons["MCP"].tap()
        
        // Verify MCP screen loads
        let mcpContent = app.tables.firstMatch
        XCTAssertTrue(mcpContent.waitForExistence(timeout: 5) ||
                     app.staticTexts["MCP Servers"].exists)
    }
    
    // MARK: - Home Screen Tests
    
    func testHomeScreenElements() {
        app.launch()
        
        // Navigate to Home
        app.tabBars.buttons["Home"].tap()
        
        // Verify home screen content
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Claude Code'")).firstMatch.exists ||
                     app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'New'")).firstMatch.exists)
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() {
        app.launch()
        
        // Check tab bar accessibility
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.isAccessibilityElement || tabBar.buttons.count > 0)
        
        // Verify buttons have labels
        for button in app.buttons.allElementsBoundByIndex {
            if button.exists && button.isHittable {
                XCTAssertFalse(button.label.isEmpty, "Button should have accessibility label")
            }
        }
    }
}