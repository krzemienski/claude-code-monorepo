# iOS Development Setup Guide
## Claude Code iOS Client

### 🚀 Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd claude-code-monorepo/apps/ios

# Run setup script (creates this if not exists)
./scripts/setup-ios.sh

# Open in Xcode
open ClaudeCode.xcworkspace
# OR if using Tuist
tuist generate && tuist open
```

### 📋 Prerequisites

#### System Requirements
- **macOS**: Ventura 13.0+ (Sonoma 14.0+ recommended)
- **Xcode**: 15.0+ (for iOS 17.0 support)
- **Storage**: 10GB free space minimum
- **RAM**: 8GB minimum, 16GB recommended

#### Required Software

##### 1. Xcode Installation
```bash
# Install from Mac App Store
# OR download from developer.apple.com

# Verify installation
xcodebuild -version

# Install additional components
xcode-select --install

# Accept license
sudo xcodebuild -license accept
```

##### 2. Homebrew Packages
```bash
# Install Homebrew if not present
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required packages
brew install rbenv ruby-build
brew install swiftlint
brew install swiftformat
brew install xcbeautify
```

##### 3. Tuist Installation (Recommended)
```bash
# Install Tuist
curl -Ls https://install.tuist.io | bash

# Verify installation
tuist version

# Update to latest
tuist update
```

##### 4. Ruby Environment
```bash
# Install Ruby via rbenv
rbenv install 3.2.0
rbenv global 3.2.0

# Install gems
gem install bundler
gem install fastlane
gem install cocoapods
gem install xcpretty
```

### 🛠️ Project Setup

#### Step 1: Environment Configuration

Create `.env` file in the iOS project root:
```bash
cd apps/ios
cp .env.example .env
```

Edit `.env` with your configuration:
```env
# API Configuration
API_BASE_URL=http://localhost:8000
API_KEY=your-development-api-key

# Development Settings
ENABLE_DEBUG_LOGGING=true
ENABLE_NETWORK_LOGGING=true
USE_MOCK_DATA=false

# Push Notifications (optional)
APNS_KEY_ID=your-key-id
APNS_TEAM_ID=your-team-id

# Analytics (optional)
ANALYTICS_ENABLED=false
CRASHLYTICS_ENABLED=false
```

#### Step 2: Build System Setup

##### Using Tuist
```bash
# Fetch dependencies
tuist fetch

# Generate Xcode project
tuist generate

# Open in Xcode
tuist open

# Build
tuist build

# Run tests
tuist test
```

**Note**: Tuist is the sole build system for this project. The Project.swift file is the single source of truth for all project configuration.

#### Step 3: Simulator Configuration

```bash
# List available simulators
xcrun simctl list devices

# Create iPhone 15 Pro simulator
xcrun simctl create "iPhone 15 Pro" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-17-0

# Boot simulator
xcrun simctl boot "iPhone 15 Pro"

# Open Simulator app
open -a Simulator

# Install app to simulator
xcrun simctl install "iPhone 15 Pro" \
  ~/Library/Developer/Xcode/DerivedData/ClaudeCode-*/Build/Products/Debug-iphonesimulator/ClaudeCode.app
```

### 🔑 Code Signing Setup

#### Development Team Configuration

1. **Open Xcode Project Settings**:
   - Select project in navigator
   - Select "ClaudeCode" target
   - Go to "Signing & Capabilities" tab

2. **Configure Signing**:
   ```
   Team: [Select your team]
   Bundle Identifier: com.claudecode.ios
   Signing Certificate: Apple Development
   Provisioning Profile: Automatic
   ```

3. **For CI/CD** (create `ExportOptions.plist`):
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
     "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
     <key>method</key>
     <string>development</string>
     <key>teamID</key>
     <string>YOUR_TEAM_ID</string>
     <key>compileBitcode</key>
     <false/>
   </dict>
   </plist>
   ```

### 🏃‍♂️ Running the App

#### From Xcode
1. Select target device/simulator
2. Press `Cmd+R` or click Run button
3. For debugging: `Cmd+Y` to pause at breakpoints

#### From Command Line
```bash
# Using Tuist
tuist run ClaudeCode

# Using xcodebuild
xcodebuild -scheme ClaudeCode \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -derivedDataPath ./build \
  build

# Run on device
ios-deploy --bundle ./build/Build/Products/Debug-iphoneos/ClaudeCode.app
```

### 🧪 Testing

#### Unit Tests
```bash
# Run all tests
tuist test

# OR using xcodebuild
xcodebuild test \
  -scheme ClaudeCode \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  | xcbeautify

# Run specific test
xcodebuild test \
  -scheme ClaudeCode \
  -only-testing:ClaudeCodeTests/APIClientTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

#### UI Tests
```bash
# Run UI tests
xcodebuild test \
  -scheme ClaudeCodeUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  | xcbeautify
```

#### Test Coverage
```bash
# Generate coverage report
xcodebuild test \
  -scheme ClaudeCode \
  -enableCodeCoverage YES \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# View coverage
xcrun xccov view --report ./build/Logs/Test/*.xcresult
```

### 🐛 Debugging

#### Network Debugging
```swift
// Enable in AppSettings
#if DEBUG
URLSession.shared.configuration.waitsForConnectivity = true
URLSession.shared.configuration.timeoutIntervalForRequest = 60
#endif
```

#### Using Proxyman/Charles
1. Install Proxyman: `brew install --cask proxyman`
2. Install certificate on simulator
3. Enable SSL proxying for `localhost`
4. View all API calls in real-time

#### SwiftUI Preview Debugging
```swift
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.colorScheme, .dark)
            .previewDevice("iPhone 15 Pro")
    }
}
#endif
```

### 📦 Building for Distribution

#### TestFlight Build
```bash
# Using Fastlane
fastlane beta

# Manual process
xcodebuild archive \
  -scheme ClaudeCode \
  -configuration Release \
  -archivePath ./build/ClaudeCode.xcarchive

xcodebuild -exportArchive \
  -archivePath ./build/ClaudeCode.xcarchive \
  -exportPath ./build/ipa \
  -exportOptionsPlist ExportOptions.plist
```

#### App Store Build
```bash
# Increment version
agvtool next-version -all
agvtool new-marketing-version 1.0.1

# Build and upload
fastlane release
```

### 🔧 Troubleshooting

#### Common Issues

##### 1. Dependency Resolution Failures
```bash
# Clear SPM cache
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset packages
xcodebuild -resolvePackageDependencies
```

##### 2. Simulator Issues
```bash
# Reset simulator
xcrun simctl erase all

# Kill simulator
killall Simulator

# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData
```

##### 3. Code Signing Issues
```bash
# List certificates
security find-identity -p codesigning

# Clear provisioning profiles
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles

# Re-download from Xcode
Xcode > Settings > Accounts > Download Manual Profiles
```

##### 4. Build Performance
```bash
# Enable build timing
defaults write com.apple.dt.Xcode ShowBuildOperationDuration YES

# Increase parallel builds
defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks `sysctl -n hw.ncpu`

# Use faster linker
Build Settings > Other Linker Flags: -ld64
```

### 📱 Device Testing

#### Physical Device Setup
1. Connect iPhone/iPad via USB
2. Open Xcode > Window > Devices and Simulators
3. Trust computer on device
4. Enable Developer Mode (iOS 16+):
   - Settings > Privacy & Security > Developer Mode

#### Wireless Debugging
```bash
# Enable wireless debugging
Xcode > Window > Devices and Simulators
Select device > Connect via network

# Verify connection
xcrun devicectl list devices
```

### 🚀 Continuous Integration

#### GitHub Actions Setup
```yaml
# .github/workflows/ios.yml
name: iOS CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_15.0.app
      
    - name: Install Tuist
      run: curl -Ls https://install.tuist.io | bash
      
    - name: Generate project
      run: tuist generate
      working-directory: apps/ios
      
    - name: Build
      run: tuist build
      working-directory: apps/ios
      
    - name: Test
      run: tuist test
      working-directory: apps/ios
```

### 📚 Additional Resources

#### Documentation
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Tuist Documentation](https://docs.tuist.io)
- [Fastlane Documentation](https://docs.fastlane.tools)

#### Tools
- **SwiftLint**: Code style enforcement
- **SwiftFormat**: Automatic code formatting
- **Periphery**: Unused code detection
- **XCMetrics**: Build performance tracking

#### Useful Commands Reference
```bash
# Project
tuist generate          # Generate Xcode project
tuist open             # Open in Xcode
tuist build            # Build project
tuist test             # Run tests
tuist clean            # Clean build artifacts

# Simulator
xcrun simctl list      # List simulators
xcrun simctl boot <id> # Boot simulator
xcrun simctl shutdown <id> # Shutdown
xcrun simctl install <id> <app> # Install app
xcrun simctl openurl <id> <url> # Open URL

# Build
xcodebuild -list       # List schemes
xcodebuild clean       # Clean build
xcodebuild build       # Build project
xcodebuild test        # Run tests
xcodebuild archive     # Create archive

# Debug
lldb                   # Start debugger
po <variable>          # Print object
bt                     # Backtrace
c                      # Continue
```

### 🎯 Development Best Practices

1. **Always work on feature branches**
2. **Run tests before committing**
3. **Use SwiftLint for code consistency**
4. **Update documentation with changes**
5. **Test on real devices before release**
6. **Profile performance regularly**
7. **Monitor memory usage**
8. **Check accessibility compliance**
9. **Validate against different screen sizes**
10. **Test offline scenarios**

This guide should help you get started with iOS development for the Claude Code project. For specific questions or issues, please refer to the project documentation or reach out to the iOS development team.