# Claude Code iOS Development Guide

## 📱 iOS Application Architecture Overview

### Project Structure
```
apps/ios/
├── Project.swift              # Tuist configuration (single source of truth)
├── ClaudeCode.xcodeproj/      # Generated Xcode project (do not commit)
├── Scripts/
│   └── bootstrap.sh           # Environment setup script
├── Sources/
│   ├── App/                   # Core application
│   │   ├── ClaudeCodeApp.swift  # Main app entry point
│   │   ├── Core/              # Core services
│   │   │   ├── AppSettings.swift
│   │   │   ├── KeychainService.swift
│   │   │   └── Networking/
│   │   │       ├── APIClient.swift     # REST API client
│   │   │       └── SSEClient.swift     # Server-sent events
│   │   ├── Concurrency/       # Actor-based concurrency
│   │   │   ├── ActorBasedTaskManagement.swift
│   │   │   └── ActorBasedMemoryManagement.swift
│   │   └── Theme/             # Design system
│   │       ├── Theme.swift
│   │       └── Tokens.css
│   └── Features/              # Feature modules
│       ├── Home/              # Dashboard
│       ├── Projects/          # Project management
│       ├── Sessions/          # Chat sessions
│       ├── MCP/               # MCP integration
│       ├── Monitoring/        # System monitoring
│       ├── Files/             # File browser
│       ├── Settings/          # App settings
│       └── Tracing/           # Debug tracing
└── ios-build.sh               # Main build script

```

## 🛠 Environment Setup

### Prerequisites

1. **Xcode 15.0+** (iOS 16.0 SDK minimum, iOS 17.0 SDK recommended)
   ```bash
   # Check Xcode version
   xcodebuild -version
   ```

2. **Homebrew** (for tools installation)
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

3. **Tuist** (project generation)
   ```bash
   curl -Ls https://install.tuist.io | bash
   ```

4. **Swift Package Manager** (automatic with Xcode)

### Initial Setup

1. **Bootstrap the Project**
   ```bash
   cd apps/ios
   ./Scripts/bootstrap.sh
   ```
   This script will:
   - Install Tuist if missing
   - Generate Xcode project from Project.swift
   - Open the project in Xcode

2. **Configure Bundle Identifier**
   - Open `Project.swift`
   - Update `bundleId: "com.claudecode.ios"`
   - Update `Sources/App/Info.plist` bundle identifier if needed

3. **Set Up Code Signing**
   - Open project in Xcode
   - Select target "ClaudeCode"
   - Go to "Signing & Capabilities"
   - Select your development team
   - Enable automatic signing

## 📦 Dependencies

### Swift Packages (via SPM)
- **swift-log** (1.5.3+): Logging infrastructure
- **swift-metrics** (2.5.0+): Performance metrics
- **swift-collections** (1.0.6+): Data structures
- **eventsource** (3.0.0+): SSE support
- **KeychainAccess** (4.2.2+): Secure storage
- **Charts** (5.1.0+): Data visualization
- ~~**Shout**: SSH client~~ (Removed - not iOS compatible)

### Installation
Dependencies are automatically resolved when opening the project in Xcode.

## 🔧 Configuration

### Environment Variables

1. **API Configuration** (`AppSettings.swift`)
   - `baseURL`: Backend server URL (default: `http://localhost:8000`)
   - `apiKey`: Authentication token (stored in Keychain)
   - `streamingDefault`: Enable SSE by default
   - `sseBufferKiB`: SSE buffer size

2. **Info.plist Settings**
   ```xml
   <!-- Allow local development connections -->
   <key>NSAppTransportSecurity</key>
   <dict>
       <key>NSAllowsArbitraryLoads</key>
       <true/>
   </dict>
   ```

### Feature Flags

Feature flags can be implemented using:
```swift
// AppSettings.swift extension
extension AppSettings {
    @AppStorage("feature.newUI") var featureNewUI: Bool = false
    @AppStorage("feature.betaMonitoring") var featureBetaMonitoring: Bool = false
    @AppStorage("feature.debugging") var featureDebugging: Bool = false
}
```

## 🏗 Architecture Details

### MVVM Pattern

The app follows MVVM architecture:

1. **Models**: API response types (`APIClient.swift`)
2. **Views**: SwiftUI views (`*View.swift`)
3. **ViewModels**: `@StateObject` properties in views

### Navigation Structure

```swift
TabView {
    HomeView()        // Dashboard
    ProjectsListView() // Project management
    SessionsView()     // Active sessions
    MonitoringView()   // System metrics
}
```

### Data Flow

1. **API Layer** (`APIClient.swift`)
   - Generic JSON helpers
   - Typed endpoints
   - Error handling

2. **Streaming** (`SSEClient.swift`)
   - Real-time updates
   - Event parsing
   - Buffer management

3. **Storage** (`KeychainService.swift`)
   - Secure credential storage
   - API key management

### Key Components

#### APIClient
- RESTful API communication
- Generic JSON encoding/decoding
- Typed endpoints for:
  - Projects CRUD
  - Sessions management
  - Model capabilities
  - Health checks

#### SSEClient
- Server-sent events handling
- Real-time chat streaming
- Tool execution monitoring
- Event buffering

#### ChatConsoleView
- Real-time chat interface
- Tool timeline visualization
- Streaming/non-streaming modes
- Session management

## 🧪 Testing Strategy

### Unit Tests

```swift
// Tests/APIClientTests.swift
import XCTest
@testable import ClaudeCode

class APIClientTests: XCTestCase {
    func testHealthEndpoint() async throws {
        // Given
        let settings = AppSettings()
        settings.baseURL = "http://test.local"
        let client = APIClient(settings: settings)!
        
        // When
        let health = try await client.health()
        
        // Then
        XCTAssertTrue(health.ok)
    }
}
```

### Integration Tests

```swift
// Tests/ChatIntegrationTests.swift
class ChatIntegrationTests: XCTestCase {
    func testStreamingSession() async throws {
        // Test SSE streaming with mock server
    }
}
```

### UI Tests (XCUITest)

```swift
// UITests/SessionFlowTests.swift
class SessionFlowTests: XCTestCase {
    func testCreateNewSession() {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to sessions
        app.tabBars.buttons["Sessions"].tap()
        
        // Create new session
        app.navigationBars.buttons["Add"].tap()
        app.textFields["Title"].typeText("Test Session")
        app.buttons["Create"].tap()
        
        // Verify session created
        XCTAssert(app.cells["Test Session"].exists)
    }
}
```

## 🚀 CI/CD Pipeline

### GitHub Actions Workflow

```yaml
# .github/workflows/ios.yml
name: iOS CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '15.4'
    
    - name: Install Dependencies
      run: |
        curl -Ls https://install.tuist.io | bash
        cd apps/ios
        tuist generate
    
    - name: Build
      run: |
        xcodebuild build \
          -project apps/ios/ClaudeCode.xcodeproj \
          -scheme ClaudeCode \
          -destination 'platform=iOS Simulator,name=iPhone 15'
    
    - name: Test
      run: |
        xcodebuild test \
          -project apps/ios/ClaudeCode.xcodeproj \
          -scheme ClaudeCode \
          -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 📊 Performance Monitoring

### Instrumentation Points

1. **Network Performance**
   ```swift
   // Add to APIClient
   let start = CFAbsoluteTimeGetCurrent()
   let response = try await getJSON(path, as: T.self)
   let duration = CFAbsoluteTimeGetCurrent() - start
   log.info("API call took \(duration)s")
   ```

2. **Memory Monitoring**
   ```swift
   // Add to critical views
   .onAppear {
       let memoryUsage = getMemoryUsage()
       analytics.track("view_loaded", properties: [
           "memory_mb": memoryUsage
       ])
   }
   ```

3. **SSE Performance**
   ```swift
   // Track streaming metrics
   var bytesReceived = 0
   var eventsProcessed = 0
   var processingTime: TimeInterval = 0
   ```

## 🔍 Debugging & Logging

### Logging Configuration

```swift
// Configure in ClaudeCodeApp.swift
import Logging

LoggingSystem.bootstrap { label in
    var handler = StreamLogHandler.standardOutput(label: label)
    handler.logLevel = .debug
    return handler
}
```

### Debug Menu

```swift
// Add to SettingsView
Section("Debug") {
    Toggle("Show Network Logs", isOn: $settings.showNetworkLogs)
    Toggle("Mock API Responses", isOn: $settings.useMockAPI)
    Button("Clear Keychain") { try? keychain.clear() }
    Button("Export Logs") { exportLogs() }
}
```

## 🔐 Security Considerations

### Keychain Security
- API keys stored in iOS Keychain
- Biometric authentication for sensitive operations
- Certificate pinning for production

### Network Security
- TLS 1.3 enforcement
- Certificate validation
- Request signing for sensitive endpoints

## 📱 Multi-Device Support

### iPad Optimization
```swift
// Add to views
.navigationViewStyle(StackNavigationViewStyle())
.onAppear {
    if UIDevice.current.userInterfaceIdiom == .pad {
        // iPad-specific setup
    }
}
```

### Dynamic Type Support
```swift
Text("Title")
    .font(.headline)
    .dynamicTypeSize(...DynamicTypeSize.accessibility5)
```

## 🎨 Design System Integration

### Theme Application
```swift
// Consistent theming
.background(Theme.card)
.foregroundStyle(Theme.foreground)
.overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
```

### Dark Mode Support
```swift
.preferredColorScheme(.dark)
.environment(\.colorScheme, .dark)
```

## 🚦 Error Handling Strategy

### Network Errors
```swift
enum NetworkError: LocalizedError {
    case invalidURL
    case noConnection
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .noConnection: return "No internet connection"
        case .serverError(let code): return "Server error: \(code)"
        }
    }
}
```

### User-Facing Errors
```swift
.alert("Error", isPresented: $showError, presenting: error) { _ in
    Button("Retry") { retry() }
    Button("Cancel", role: .cancel) { }
} message: { error in
    Text(error.localizedDescription)
}
```

## 📈 Analytics Integration

### Event Tracking
```swift
// Track user interactions
Analytics.track("session_created", properties: [
    "model": modelId,
    "streaming": useStream,
    "project_id": projectId
])
```

### Performance Metrics
```swift
// Track performance
Analytics.track("api_response", properties: [
    "endpoint": path,
    "duration_ms": duration * 1000,
    "status_code": statusCode
])
```

## 🔄 State Management

### AppStorage for Persistence
```swift
@AppStorage("user.theme") var theme: String = "dark"
@AppStorage("user.language") var language: String = "en"
```

### ObservableObject for Shared State
```swift
class SessionManager: ObservableObject {
    @Published var activeSessions: [Session] = []
    @Published var currentSession: Session?
}
```

## 📝 Code Quality Checklist

- [ ] SwiftLint configuration added
- [ ] Unit test coverage >80%
- [ ] UI test coverage for critical flows
- [ ] Accessibility labels added
- [ ] Memory leak testing completed
- [ ] Performance profiling done
- [ ] Security audit passed
- [ ] Documentation updated
- [ ] Localization prepared
- [ ] App Store metadata ready

## 🆘 Troubleshooting

### Common Issues

1. **Build Failures**
   - Clean build folder: Cmd+Shift+K
   - Reset package caches: File → Packages → Reset Package Caches
   - Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`

2. **Simulator Issues**
   - Reset simulator: Device → Erase All Content and Settings
   - Clean simulator runtime: `xcrun simctl shutdown all`

3. **Certificate Issues**
   - Refresh profiles: Xcode → Settings → Accounts → Download Manual Profiles
   - Clear provisioning: `rm -rf ~/Library/MobileDevice/Provisioning\ Profiles`

## 📚 Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)