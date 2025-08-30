# ClaudeCode iOS App

## Overview
Native iOS client for ClaudeCode, built with SwiftUI and managed using Tuist for project generation. Supports iOS 16.0+.

## Quick Start

### Prerequisites
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- macOS Ventura or later
- Tuist 4.x (install with `curl -Ls https://install.tuist.io | bash`)

### Building and Running

#### Option 1: Using the Build Script (Recommended)
```bash
# From the iOS directory
cd apps/ios

# Generate and run (default: iPhone 15, Debug)
./ios-build.sh run

# Complete workflow (clean, generate, build, test, run)
./ios-build.sh all

# With specific device
./ios-build.sh run debug iPhone-16-Pro

# Release build
./ios-build.sh build release
```

#### Option 2: Using Xcode
1. Generate the project using Tuist:
   ```bash
   cd apps/ios
   ./ios-build.sh generate
   # Or directly: tuist generate
   ```

2. Open in Xcode:
   ```bash
   open ClaudeCode.xcworkspace
   # Or: open ClaudeCode.xcodeproj
   ```

3. Select the ClaudeCode scheme and iPhone simulator
4. Press Cmd+R to build and run

#### Option 3: Command Line with Tuist
```bash
cd apps/ios

# Clean any existing artifacts
tuist clean

# Fetch dependencies
tuist fetch

# Generate Xcode project
tuist generate

# Build using xcodebuild
xcodebuild build \
  -workspace ClaudeCode.xcworkspace \
  -scheme ClaudeCode \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 15"

# Install and run
xcrun simctl boot "iPhone 15"
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/ClaudeCode.app
xcrun simctl launch booted com.claudecode.ios
```

## Backend Connection

### Start the Backend Server
```bash
cd services/backend
python -m app.main
```

The backend runs at `http://localhost:8000` by default.

### Verify Connection
1. Launch the iOS app
2. Go to the "Test" tab (visible in Debug builds)
3. Tap "Run Backend Tests"
4. All tests should pass if the backend is running

### Configuration
- Default backend URL: `http://localhost:8000`
- Can be changed in Settings tab
- API key is optional for local development

## Features

### Implemented
✅ Backend connectivity with comprehensive logging
✅ Health endpoint monitoring
✅ SSE (Server-Sent Events) support
✅ Project management UI
✅ Session management
✅ Real-time monitoring
✅ Mock SSH client (for iOS compatibility)
✅ Keychain integration for secure API key storage
✅ Dark mode optimized UI
✅ Network error handling

### Architecture
- **SwiftUI**: Modern declarative UI
- **Async/Await**: Modern concurrency
- **OSLog**: Structured logging
- **URLSession**: Network requests
- **Keychain**: Secure storage

## Debugging

### View Logs in Console
```bash
# Stream all app logs
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.claudecode.ios"'

# Filter by category
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.claudecode.ios" AND category == "API"'

# Log categories:
# - App: General app lifecycle
# - API: API requests/responses
# - SSE: Server-sent events
# - UI: User interface events
# - Auth: Authentication
# - Network: Network operations
# - Debug: Debug information
```

### Common Issues

#### Build Fails with SSH Dependency
- The Shout SSH library has been removed
- Using mock SSH implementation for iOS

#### Backend Connection Failed
1. Ensure backend is running: `cd services/backend && python -m app.main`
2. Check URL in Settings (should be `http://localhost:8000`)
3. Verify network permissions in Info.plist (already configured)

#### Simulator Not Found
```bash
# List available simulators
xcrun simctl list devices

# Use specific simulator with new script
./ios-build.sh run debug iPhone-14

# Or create missing simulator
xcrun simctl create "iPhone 15" "iPhone 15"
```

## Project Structure
```
apps/ios/
├── Project.swift            # Tuist configuration (source of truth)
├── Package.swift            # Swift Package dependencies
├── Tuist/
│   └── Package.swift        # External dependencies
├── Sources/
│   ├── App/
│   │   ├── ClaudeCodeApp.swift    # Main app entry
│   │   ├── Core/
│   │   │   ├── Networking/        # API client, SSE
│   │   │   ├── Logging/           # Logging system
│   │   │   ├── Auth/              # Authentication
│   │   │   └── AppSettings.swift  # App configuration
│   │   ├── Theme/                 # UI theme
│   │   └── Components/            # Reusable UI
│   └── Features/
│       ├── Home/                  # Home screen
│       ├── Projects/              # Project management
│       ├── Sessions/              # Chat sessions
│       ├── Monitoring/            # System monitoring
│       └── Diagnostics/           # Backend testing
├── Tests/                         # Unit tests
├── UITests/                       # UI tests
├── docs/
│   └── TUIST_COMMANDS_GUIDE.md   # Tuist documentation
└── ios-build.sh                   # Build automation script
```

## Development

### Dependencies
Managed via Swift Package Manager in Package.swift and Tuist/Package.swift:
- swift-log: Logging
- swift-metrics: Metrics collection
- swift-collections: Data structures
- eventsource: SSE client
- KeychainAccess: Secure storage
- Charts: Data visualization

To add dependencies:
1. Edit Package.swift or Tuist/Package.swift
2. Run `tuist fetch`
3. Run `tuist generate`

### Testing
```bash
# Run unit tests
xcodebuild test -scheme ClaudeCode -destination "platform=iOS Simulator,name=iPhone 15 Pro"

# Run UI tests
xcodebuild test -scheme ClaudeCodeUITests -destination "platform=iOS Simulator,name=iPhone 15 Pro"
```

## Deployment

### App Store Build
1. Update version in Project.yml
2. Archive in Xcode (Product → Archive)
3. Upload to App Store Connect
4. Submit for review

### TestFlight
1. Archive the app
2. Upload to App Store Connect
3. Distribute via TestFlight

## Support

For issues or questions:
1. Check the logs using the debug commands above
2. Verify backend is running and accessible
3. Try the clean build option: `./scripts/ios-build.sh --clean`