import XCTest

// MARK: - Shared UI Test Helper Extensions

extension XCUIElement {
    /// Clears existing text and types new text into the element
    func clearAndTypeText(_ text: String) {
        guard let stringValue = self.value as? String else {
            self.typeText(text)
            return
        }
        
        // Clear existing text
        self.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        
        // Type new text
        self.typeText(text)
    }
    
    /// Waits for the element to exist with a default timeout
    func waitForExistence(timeout: TimeInterval = 10) -> Bool {
        return self.waitForExistence(timeout: timeout)
    }
}

// MARK: - Common Test Utilities

extension XCTestCase {
    /// Launches the app with specified environment variables
    func launchApp(with environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = environment
        app.launch()
        return app
    }
    
    /// Takes a screenshot with a descriptive name
    func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}