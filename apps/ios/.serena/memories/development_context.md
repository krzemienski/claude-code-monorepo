# Development Context

## Current Focus Areas
1. Memory safety improvements (completed)
2. View decomposition (in progress)
3. Protocol-oriented design (planned)
4. iPad optimization (planned)
5. Test suite fixes (needed)

## Build Commands
```bash
# Build for simulator
xcodebuild -workspace ClaudeCode.xcworkspace -scheme ClaudeCode \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Run tests
xcodebuild test -workspace ClaudeCode.xcworkspace -scheme ClaudeCode \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Launch simulator
xcrun simctl boot "iPhone 16 Pro"
xcrun simctl launch booted com.claudecode.ios
```

## Project Dependencies
- Tuist for project generation
- Swift Package Manager for dependencies
- Xcode 16.4+ required

## File Organization
- Sources/App: Core app infrastructure
- Sources/Features: Feature modules
- Modules/: Modular architecture components
- Tests/: Test suites
- UITests/: UI automation tests