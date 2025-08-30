# SwiftUI UI Testing Strategy - Claude Code iOS

## Overview
This document outlines a comprehensive UI testing strategy for the Claude Code iOS application, covering unit tests, UI tests, and accessibility validation.

## Testing Architecture

### Test Pyramid for SwiftUI
```
         /\
        /  \  E2E Tests (10%)
       /    \  - Critical user journeys
      /      \  - Cross-feature workflows
     /________\
    /          \  UI Tests (30%)
   /            \  - Screen interactions
  /              \  - Navigation flows
 /________________\
/                  \  Unit Tests (60%)
/                    \  - View models
/                      \  - Business logic
/________________________\  - State management
```

## Testing Framework Setup

### Required Test Targets
```yaml
# Add to Project.yml
targets:
  ClaudeCodeTests:
    type: bundle.unit-test
    platform: iOS
    sources: Tests/Unit
    dependencies:
      - target: ClaudeCode
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.yourorg.claudecode.tests
  
  ClaudeCodeUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: Tests/UI
    dependencies:
      - target: ClaudeCode
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.yourorg.claudecode.uitests
```

## Unit Testing Strategy

### 1. View Model Testing

#### AppSettings Tests
```swift
import XCTest
@testable import ClaudeCode

class AppSettingsTests: XCTestCase {
    var settings: AppSettings!
    
    override func setUp() {
        super.setUp()
        settings = AppSettings()
    }
    
    func testBaseURLValidation() {
        // Test valid URL
        settings.baseURL = "http://localhost:8000"
        XCTAssertNotNil(settings.baseURLParsed)
        
        // Test invalid URL
        settings.baseURL = "not a url"
        XCTAssertNil(settings.baseURLParsed)
    }
    
    func testAPIKeyStorage() async throws {
        // Test saving
        settings.apiKeyPlaintext = "test-key-123"
        try settings.saveAPIKey()
        
        // Test retrieval
        let retrieved = settings.apiKey
        XCTAssertEqual(retrieved, "test-key-123")
    }
    
    func testStreamingDefault() {
        // Test default value
        XCTAssertTrue(settings.streamingDefault)
        
        // Test persistence
        settings.streamingDefault = false
        XCTAssertFalse(settings.streamingDefault)
    }
}
```

#### APIClient Tests
```swift
class APIClientTests: XCTestCase {
    var client: APIClient!
    var mockSession: URLSession!
    
    override func setUp() {
        super.setUp()
        let settings = AppSettings()
        settings.baseURL = "http://localhost:8000"
        client = APIClient(settings: settings)
        
        // Setup mock URLSession
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
    }
    
    func testHealthEndpoint() async throws {
        // Mock response
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"ok": true, "version": "1.0.0", "active_sessions": 3}
            """.data(using: .utf8)!
            return (response, data)
        }
        
        // Test
        let health = try await client.health()
        XCTAssertTrue(health.ok)
        XCTAssertEqual(health.version, "1.0.0")
        XCTAssertEqual(health.active_sessions, 3)
    }
}
```

### 2. State Management Testing

#### Session State Tests
```swift
class ChatConsoleStateTests: XCTestCase {
    func testTranscriptManagement() {
        var transcript: [ChatBubble] = []
        
        // Add user message
        transcript.append(ChatBubble(role: .user, text: "Hello"))
        XCTAssertEqual(transcript.count, 1)
        XCTAssertEqual(transcript[0].role, .user)
        
        // Add assistant message
        transcript.append(ChatBubble(role: .assistant, text: "Hi"))
        XCTAssertEqual(transcript.count, 2)
        
        // Update assistant message (streaming)
        transcript[1].text += " there!"
        XCTAssertEqual(transcript[1].text, "Hi there!")
    }
    
    func testToolTimelineState() {
        var timeline: [ToolRow] = []
        
        // Add running tool
        let tool = ToolRow(
            id: "1",
            name: "grep",
            state: .running,
            inputJSON: "{\"pattern\": \"test\"}"
        )
        timeline.insert(tool, at: 0)
        
        // Update to completed
        timeline[0].state = .ok
        timeline[0].output = "3 matches found"
        timeline[0].durationMs = 150
        
        XCTAssertEqual(timeline[0].state, .ok)
        XCTAssertNotNil(timeline[0].durationMs)
    }
}
```

### 3. Business Logic Testing

#### Filtering Logic Tests
```swift
class FilteringTests: XCTestCase {
    func testSessionFiltering() {
        let sessions = [
            APIClient.Session(id: "1", projectId: "p1", model: "claude", isActive: true),
            APIClient.Session(id: "2", projectId: "p1", model: "gpt", isActive: false),
            APIClient.Session(id: "3", projectId: "p2", model: "claude", isActive: true)
        ]
        
        // Test active filter
        let active = sessions.filter { $0.isActive }
        XCTAssertEqual(active.count, 2)
        
        // Test search filter
        let search = "gpt"
        let filtered = sessions.filter { 
            $0.model.localizedCaseInsensitiveContains(search) 
        }
        XCTAssertEqual(filtered.count, 1)
    }
}
```

## UI Testing Strategy

### 1. Screen Navigation Tests

```swift
import XCTest

class NavigationUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testHomeToProjectsNavigation() {
        // Navigate to Projects
        app.buttons["Projects"].tap()
        
        // Verify navigation
        XCTAssertTrue(app.navigationBars["Projects"].exists)
        
        // Navigate back
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Claude Code"].exists)
    }
    
    func testSettingsFlow() {
        // Open settings
        app.buttons["gear"].tap()
        
        // Verify settings screen
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        
        // Enter base URL
        let urlField = app.textFields["Base URL"]
        urlField.tap()
        urlField.typeText("http://localhost:8000")
        
        // Enter API key
        let apiField = app.secureTextFields["API Key"]
        apiField.tap()
        apiField.typeText("test-key")
        
        // Validate connection
        app.buttons["Validate"].tap()
        
        // Wait for result
        let statusText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'OK'"))
        XCTAssertTrue(statusText.element.waitForExistence(timeout: 5))
    }
}
```

### 2. Chat Interface Tests

```swift
class ChatUITests: XCTestCase {
    func testChatMessageFlow() {
        // Navigate to chat
        navigateToChat()
        
        // Type message
        let textEditor = app.textViews.firstMatch
        textEditor.tap()
        textEditor.typeText("Hello Claude")
        
        // Send message
        app.buttons["Send"].tap()
        
        // Verify message appears
        let userMessage = app.staticTexts["Hello Claude"]
        XCTAssertTrue(userMessage.exists)
        
        // Wait for response
        let assistantMessage = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Hi'")
        )
        XCTAssertTrue(assistantMessage.element.waitForExistence(timeout: 10))
    }
    
    func testStreamingToggle() {
        navigateToChat()
        
        // Verify streaming is on by default
        let streamToggle = app.switches["Stream"]
        XCTAssertTrue(streamToggle.isSelected)
        
        // Toggle off
        streamToggle.tap()
        XCTAssertFalse(streamToggle.isSelected)
    }
}
```

### 3. List Interaction Tests

```swift
class ListInteractionTests: XCTestCase {
    func testProjectListSearch() {
        // Navigate to projects
        app.buttons["Projects"].tap()
        
        // Pull to refresh
        let list = app.tables.firstMatch
        list.swipeDown()
        
        // Search
        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("test")
        
        // Verify filtered results
        XCTAssertTrue(app.cells.count > 0)
    }
    
    func testSwipeActions() {
        // Navigate to sessions
        app.buttons["Sessions"].tap()
        
        // Swipe on active session
        let cell = app.cells.element(boundBy: 0)
        cell.swipeLeft()
        
        // Verify stop action appears
        XCTAssertTrue(app.buttons["Stop"].exists)
    }
}
```

## Accessibility Testing

### 1. VoiceOver Testing

```swift
class AccessibilityTests: XCTestCase {
    func testVoiceOverLabels() {
        // Home screen
        XCTAssertEqual(
            app.buttons["Projects"].label,
            "Projects"
        )
        
        // Verify accessibility hints
        XCTAssertNotNil(
            app.buttons["Projects"].accessibilityHint
        )
    }
    
    func testDynamicType() {
        // Set large text size
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraLarge"
        ]
        app.launch()
        
        // Verify text scales
        let label = app.staticTexts.firstMatch
        XCTAssertTrue(label.frame.height > 30)
    }
    
    func testColorContrast() {
        // Take screenshots for manual contrast verification
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Color Contrast Check"
        add(attachment)
    }
}
```

### 2. Accessibility Audit

```swift
extension XCTestCase {
    func performAccessibilityAudit() throws {
        let app = XCUIApplication()
        
        try app.performAccessibilityAudit { issue in
            var shouldIgnore = false
            
            // Ignore known issues
            if issue.auditType == .contrast &&
               issue.element?.label == "Muted Text" {
                shouldIgnore = true // Design decision
            }
            
            return shouldIgnore
        }
    }
}
```

## Performance Testing

### 1. Launch Time Testing

```swift
class PerformanceTests: XCTestCase {
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    func testScrollPerformance() {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to long list
        app.buttons["Sessions"].tap()
        
        measure {
            let list = app.tables.firstMatch
            list.swipeUp(velocity: .fast)
            list.swipeDown(velocity: .fast)
        }
    }
}
```

### 2. Memory Testing

```swift
class MemoryTests: XCTestCase {
    func testMemoryDuringStreaming() {
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        
        measure(metrics: [XCTMemoryMetric()], options: options) {
            // Start chat
            navigateToChat()
            startMeasuring()
            
            // Send message and stream response
            sendMessage("Generate a long response")
            
            // Wait for streaming to complete
            Thread.sleep(forTimeInterval: 10)
            stopMeasuring()
        }
    }
}
```

## Test Data Management

### Mock Data Factory

```swift
enum TestDataFactory {
    static func makeProject(
        id: String = UUID().uuidString,
        name: String = "Test Project"
    ) -> APIClient.Project {
        return APIClient.Project(
            id: id,
            name: name,
            description: "Test description",
            path: "/test/path"
        )
    }
    
    static func makeSession(
        isActive: Bool = true
    ) -> APIClient.Session {
        return APIClient.Session(
            id: UUID().uuidString,
            projectId: "test-project",
            model: "claude-3-haiku",
            isActive: isActive,
            messageCount: 10,
            totalTokens: 1000
        )
    }
}
```

## Continuous Integration Setup

### GitHub Actions Workflow

```yaml
name: iOS Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_15.0.app
    
    - name: Generate Project
      run: |
        cd apps/ios
        ./Scripts/bootstrap.sh
    
    - name: Run Unit Tests
      run: |
        xcodebuild test \
          -scheme ClaudeCode \
          -destination 'platform=iOS Simulator,name=iPhone 15' \
          -resultBundlePath TestResults.xcresult
    
    - name: Run UI Tests
      run: |
        xcodebuild test \
          -scheme ClaudeCodeUITests \
          -destination 'platform=iOS Simulator,name=iPhone 15' \
          -resultBundlePath UITestResults.xcresult
    
    - name: Upload Results
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: "*.xcresult"
```

## Test Coverage Goals

### Minimum Coverage Targets
- **Overall**: 70%
- **Critical Paths**: 90%
- **View Models**: 80%
- **Networking**: 85%
- **State Management**: 75%

### Priority Testing Areas

#### High Priority (Must Test)
1. Authentication flow
2. Chat message sending/receiving
3. SSE streaming
4. Error handling
5. Data persistence

#### Medium Priority (Should Test)
1. Navigation flows
2. List interactions
3. Form validation
4. Search/filter
5. Refresh actions

#### Low Priority (Nice to Have)
1. Animation timing
2. Edge case handling
3. Rotation support
4. Deep linking
5. Background modes

## Testing Best Practices

### 1. Test Naming Convention
```swift
func test_MethodName_Condition_ExpectedResult() {
    // Example:
    func test_validateConnection_withValidURL_returnsSuccess()
    func test_sendMessage_whenStreaming_updatesTranscript()
}
```

### 2. Arrange-Act-Assert Pattern
```swift
func testExample() {
    // Arrange
    let viewModel = ChatViewModel()
    let message = "Test message"
    
    // Act
    viewModel.send(message)
    
    // Assert
    XCTAssertEqual(viewModel.transcript.count, 1)
}
```

### 3. Async Testing
```swift
func testAsyncOperation() async throws {
    // Use async/await
    let result = try await apiClient.fetchData()
    XCTAssertNotNil(result)
}
```

### 4. UI Test Helpers
```swift
extension XCUIElement {
    func clearAndType(_ text: String) {
        guard let value = self.value as? String else {
            XCTFail("Failed to clear field")
            return
        }
        
        self.tap()
        let deleteString = String(
            repeating: XCTDeleteKey, 
            count: value.count
        )
        self.typeText(deleteString)
        self.typeText(text)
    }
}
```

## Conclusion

This comprehensive testing strategy ensures the Claude Code iOS app maintains high quality through:
- Layered testing approach (unit, UI, accessibility)
- Focus on critical user paths
- Performance monitoring
- Accessibility compliance
- Continuous integration

Regular execution of these tests will catch regressions early and maintain app reliability.