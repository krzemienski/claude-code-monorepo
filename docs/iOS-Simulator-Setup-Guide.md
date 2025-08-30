# iOS Simulator Environment Setup Guide

## System Requirements

### Minimum Requirements
- **macOS**: Ventura 13.0 or later (Sonoma 14.0+ recommended)
- **Xcode**: 15.0 or later (16.4 detected on current system)
- **Disk Space**: 10GB minimum for Xcode and simulators
- **RAM**: 8GB minimum, 16GB recommended
- **Processor**: Apple Silicon (M1/M2/M3) or Intel Core i5+

### Current Environment Status
```
Xcode Version: 16.4
Build: 16F6
Swift: 5.10
iOS SDK: 17.0+
```

## Prerequisites Installation

### 1. Install Xcode
```bash
# Option 1: Mac App Store (Recommended)
# Search for "Xcode" in Mac App Store and install

# Option 2: Developer Portal
# Download from developer.apple.com/xcode/

# Option 3: Xcode Command Line Tools only
xcode-select --install
```

### 2. Install Homebrew (if not installed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3. Install XcodeGen
```bash
# Install via Homebrew
brew install xcodegen

# Verify installation
xcodegen --version
```

## Project Setup

### 1. Clone Repository
```bash
git clone [repository-url]
cd claude-code-monorepo/apps/ios
```

### 2. Generate Xcode Project
```bash
# Run bootstrap script
./Scripts/bootstrap.sh

# Or manually:
xcodegen generate
open ClaudeCode.xcodeproj
```

### 3. Configure Environment Variables
Create `.env` file in project root:
```bash
ANTHROPIC_API_KEY=your_api_key_here
BASE_URL=http://localhost:8000
```

## iOS Simulator Configuration

### Available Simulators

#### iOS 18.6 Simulators
- iPhone 16 Pro
- iPhone 16 Pro Max
- iPhone 16
- iPhone 16 Plus
- iPad Pro 11-inch (M4)
- iPad Pro 13-inch (M4)
- iPad mini (A17 Pro)
- iPad Air 11-inch (M3)
- iPad Air 13-inch (M3)

#### iOS 26.0 Simulators (Beta)
- Latest iPhone and iPad models
- Preview of upcoming iOS features

### Recommended Simulators for Testing
1. **Primary Development**: iPhone 16 Pro (iOS 18.6)
2. **Large Screen**: iPhone 16 Pro Max
3. **iPad Testing**: iPad Pro 11-inch (M4)
4. **Minimum iOS**: iPhone with iOS 17.0

### Managing Simulators

#### List Available Simulators
```bash
xcrun simctl list devices

# List only available devices
xcrun simctl list devices available

# List specific iOS version
xcrun simctl list devices "iOS 18.6"
```

#### Create New Simulator
```bash
# Create iPhone 16 Pro simulator
xcrun simctl create "iPhone 16 Pro Dev" "iPhone 16 Pro" "iOS18.6"

# Create with specific iOS version
xcrun simctl create "Test iPhone" com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro com.apple.CoreSimulator.SimRuntime.iOS-18-6
```

#### Boot Simulator
```bash
# Boot by UUID
xcrun simctl boot BECB3FA0-518E-4F80-8B8E-7E10C16F3B36

# Boot by name
xcrun simctl boot "iPhone 16 Pro"
```

#### Open Simulator App
```bash
open -a Simulator

# Open specific simulator
open -a Simulator --args -CurrentDeviceUDID BECB3FA0-518E-4F80-8B8E-7E10C16F3B36
```

## Building and Running

### Via Xcode GUI

1. Open `ClaudeCode.xcodeproj`
2. Select target device from scheme selector
3. Press `Cmd+R` to build and run
4. Or use `Product → Run` menu

### Via Command Line

#### Build for Simulator
```bash
# Build for specific simulator
xcodebuild -project ClaudeCode.xcodeproj \
           -scheme ClaudeCode \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
           build

# Build for generic simulator
xcodebuild -project ClaudeCode.xcodeproj \
           -scheme ClaudeCode \
           -destination 'generic/platform=iOS Simulator' \
           build
```

#### Run on Simulator
```bash
# Build and run
xcodebuild -project ClaudeCode.xcodeproj \
           -scheme ClaudeCode \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
           -derivedDataPath ./build \
           build

# Install on booted simulator
xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/ClaudeCode.app

# Launch app
xcrun simctl launch booted com.yourorg.claudecodeabs
```

## Environment Configuration

### App Transport Security (ATS)
Already configured in `Info.plist` for local development:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```
**Note**: This should be restricted in production builds.

### Local Backend Connection
1. Ensure backend is running on `http://localhost:8000`
2. Simulator can access localhost directly
3. For physical device testing, use computer's IP address

### API Key Configuration
Configure in Settings view (first launch):
1. Launch app in simulator
2. Navigate to Settings tab
3. Enter Base URL: `http://localhost:8000`
4. Enter Anthropic API key
5. Save settings (stored securely in Keychain)

## Debugging and Development

### Enable Debug Menu in Simulator
1. Open Simulator
2. Device → Developer menu
3. Enable:
   - Slow Animations (for UI debugging)
   - Color Blended Layers (performance)
   - Color Misaligned Images (layout issues)

### Network Debugging
```bash
# Monitor network traffic
xcrun simctl privacy booted grant network com.yourorg.claudecodeabs

# View console logs
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.yourorg.claudecode"'
```

### Reset Simulator
```bash
# Erase all content and settings
xcrun simctl erase all

# Erase specific simulator
xcrun simctl erase "iPhone 16 Pro"

# Reset keychain (useful for API key issues)
xcrun simctl keychain booted reset
```

## Common Issues and Solutions

### Issue: Simulator Won't Boot
```bash
# Solution: Kill and restart simulator service
killall Simulator
xcrun simctl shutdown all
xcrun simctl erase all
```

### Issue: Network Connection Failed
```bash
# Check if backend is running
curl http://localhost:8000/health

# Verify ATS settings in Info.plist
# Ensure NSAllowsArbitraryLoads is true for dev
```

### Issue: Build Fails - Missing Dependencies
```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset package cache
swift package reset

# Resolve packages
swift package resolve
```

### Issue: API Key Not Saving
```bash
# Reset simulator keychain
xcrun simctl keychain booted reset

# Check keychain service name matches
# Service: "com.yourorg.claudecode"
# Account: "apiKey"
```

## Performance Optimization

### Simulator Settings for Best Performance
1. **Hardware → Device**: Choose device with less pixels (iPhone 16 vs Pro Max)
2. **Window → Physical Size**: Reduce window size
3. **Disable unnecessary features**:
   - Location simulation
   - Motion effects
   - Background app refresh

### Build Settings Optimization
```bash
# Debug builds (faster compilation)
xcodebuild -configuration Debug

# Release builds (optimized performance)
xcodebuild -configuration Release
```

## Testing Multiple iOS Versions

### Download Additional Simulators
1. Xcode → Settings → Platforms
2. Click '+' to add iOS versions
3. Download iOS 17.0 for minimum version testing
4. Download iOS 18.6 for latest features

### Test Matrix
| iOS Version | Device | Priority | Notes |
|------------|--------|----------|-------|
| 17.0 | iPhone 15 | High | Minimum supported |
| 18.0 | iPhone 16 | High | Current stable |
| 18.6 | iPhone 16 Pro | Critical | Latest features |
| iPadOS 17.0 | iPad Pro | Medium | Tablet layout |

## Continuous Integration Setup

### GitHub Actions Configuration
```yaml
name: iOS Build
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '16.4'
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Generate Project
        run: cd apps/ios && xcodegen generate
      - name: Build
        run: |
          xcodebuild -project apps/ios/ClaudeCode.xcodeproj \
                     -scheme ClaudeCode \
                     -destination 'platform=iOS Simulator,OS=18.6,name=iPhone 16 Pro' \
                     build
```

## Next Steps

1. **Run Bootstrap Script**: `./Scripts/bootstrap.sh`
2. **Open in Xcode**: Project will auto-open
3. **Select Simulator**: Choose iPhone 16 Pro from device menu
4. **Build and Run**: Press Cmd+R
5. **Configure Settings**: Enter API key and base URL
6. **Test Features**: Navigate through all tabs

## Additional Resources

- [Apple Developer - Simulator](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator)
- [XcodeGen Documentation](https://github.com/yonaskolb/XcodeGen)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Swift Package Manager](https://swift.org/package-manager/)