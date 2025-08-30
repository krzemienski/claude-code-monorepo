# iOS Build and Deployment Instructions

## Quick Start

### One-Command Setup
```bash
cd apps/ios
./Scripts/bootstrap.sh
# Xcode opens automatically
# Press Cmd+R to build and run
```

## Build Configurations

### Debug Build (Development)
- **Purpose**: Local development and testing
- **Optimizations**: Disabled for faster builds
- **Debugging**: Full symbols and LLDB support
- **Code Signing**: Automatic (Development)

### Release Build (Production)
- **Purpose**: App Store distribution
- **Optimizations**: Full optimization enabled
- **Debugging**: Symbols stripped
- **Code Signing**: Manual (Distribution)

## Build Process

### 1. Project Generation

#### Using Bootstrap Script (Recommended)
```bash
cd apps/ios
./Scripts/bootstrap.sh
```

#### Manual Generation
```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate project from Project.yml
xcodegen generate

# Open in Xcode
open ClaudeCode.xcodeproj
```

### 2. Dependency Resolution

Swift Package Manager handles all dependencies automatically:

```bash
# Resolve packages (automatic in Xcode)
swift package resolve

# Update packages to latest versions
swift package update

# Reset package cache if needed
swift package reset
rm -rf .build
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### 3. Build Commands

#### Xcode GUI Build
1. Open `ClaudeCode.xcodeproj`
2. Select scheme: `ClaudeCode`
3. Select destination: Simulator or Device
4. Build: `Cmd+B`
5. Run: `Cmd+R`
6. Build and Run: `Cmd+R`

#### Command Line Build

##### Basic Build
```bash
xcodebuild -project ClaudeCode.xcodeproj \
           -scheme ClaudeCode \
           -configuration Debug \
           build
```

##### Simulator Build
```bash
xcodebuild -project ClaudeCode.xcodeproj \
           -scheme ClaudeCode \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
           -configuration Debug \
           build
```

##### Device Build
```bash
xcodebuild -project ClaudeCode.xcodeproj \
           -scheme ClaudeCode \
           -destination 'generic/platform=iOS' \
           -configuration Release \
           build
```

##### Archive Build (for Distribution)
```bash
xcodebuild -project ClaudeCode.xcodeproj \
           -scheme ClaudeCode \
           -archivePath ./build/ClaudeCode.xcarchive \
           -configuration Release \
           archive
```

### 4. Build Output Locations

```
# Debug builds
./build/Build/Products/Debug-iphonesimulator/ClaudeCode.app

# Release builds
./build/Build/Products/Release-iphonesimulator/ClaudeCode.app

# Archives
./build/ClaudeCode.xcarchive
```

## Deployment Options

### 1. Simulator Deployment

#### Install on Running Simulator
```bash
# Boot simulator first
xcrun simctl boot "iPhone 16 Pro"

# Install app
xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/ClaudeCode.app

# Launch app
xcrun simctl launch booted com.yourorg.claudecodeabs
```

#### Direct Run from Xcode
1. Select target simulator from scheme
2. Press `Cmd+R`
3. App installs and launches automatically

### 2. Device Deployment (Development)

#### Prerequisites
1. Apple Developer Account (free or paid)
2. Device registered in Xcode
3. Development provisioning profile

#### Steps
1. Connect iOS device via USB
2. Trust computer on device
3. Select device in Xcode scheme
4. Enable Developer Mode on device (iOS 16+):
   - Settings → Privacy & Security → Developer Mode
5. Build and Run: `Cmd+R`

#### Manual Installation
```bash
# Build for device
xcodebuild -project ClaudeCode.xcodeproj \
           -scheme ClaudeCode \
           -destination 'id=YOUR_DEVICE_UUID' \
           build

# Install using ios-deploy
brew install ios-deploy
ios-deploy --bundle ./build/Build/Products/Debug-iphoneos/ClaudeCode.app
```

### 3. TestFlight Deployment

#### Prerequisites
- Apple Developer Program membership ($99/year)
- App Store Connect access
- Distribution certificate and provisioning profile

#### Process
1. **Archive the app**:
```bash
xcodebuild -project ClaudeCode.xcodeproj \
           -scheme ClaudeCode \
           -archivePath ./build/ClaudeCode.xcarchive \
           -configuration Release \
           archive
```

2. **Export for App Store**:
```bash
xcodebuild -exportArchive \
           -archivePath ./build/ClaudeCode.xcarchive \
           -exportPath ./build/export \
           -exportOptionsPlist ExportOptions.plist
```

3. **Upload to App Store Connect**:
```bash
xcrun altool --upload-app \
             --file ./build/export/ClaudeCode.ipa \
             --type ios \
             --apiKey YOUR_API_KEY \
             --apiIssuer YOUR_ISSUER_ID
```

4. **Configure in App Store Connect**:
   - Add build to TestFlight
   - Add internal/external testers
   - Submit for review (external)

### 4. App Store Deployment

#### Prerequisites
- Complete TestFlight testing
- App Store assets (screenshots, descriptions)
- Privacy policy URL
- Support URL

#### Submission Process
1. Archive and upload (same as TestFlight)
2. In App Store Connect:
   - Create new app version
   - Add build from TestFlight
   - Fill in metadata
   - Add screenshots for all device sizes
   - Submit for review

#### Required Screenshots
- iPhone 6.7" (16 Pro Max)
- iPhone 6.1" (16 Pro)
- iPad Pro 12.9"
- iPad Pro 11"

## Code Signing

### Automatic Signing (Development)
Configured in `Project.yml`:
```yaml
settings:
  base:
    CODE_SIGN_STYLE: Automatic
    DEVELOPMENT_TEAM: YOUR_TEAM_ID
```

### Manual Signing (Distribution)
```yaml
settings:
  base:
    CODE_SIGN_STYLE: Manual
    PROVISIONING_PROFILE_SPECIFIER: "Your Profile Name"
    CODE_SIGN_IDENTITY: "iPhone Distribution"
```

### Signing Issues Resolution
```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset provisioning profiles
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles

# Re-download profiles
xcodebuild -downloadProvisioningProfiles
```

## Build Optimization

### Compilation Optimizations

#### Debug Configuration
```yaml
settings:
  configs:
    Debug:
      SWIFT_OPTIMIZATION_LEVEL: -Onone
      SWIFT_COMPILATION_MODE: singlefile
      DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
```

#### Release Configuration
```yaml
settings:
  configs:
    Release:
      SWIFT_OPTIMIZATION_LEVEL: -O
      SWIFT_COMPILATION_MODE: wholemodule
      DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
      STRIP_INSTALLED_PRODUCT: YES
```

### Build Time Optimization

#### Parallel Builds
```bash
# Use all CPU cores
xcodebuild -parallelizeTargets \
           -jobs $(sysctl -n hw.ncpu)
```

#### Incremental Builds
```bash
# Clean only when necessary
# Use incremental builds for faster iteration
xcodebuild -scheme ClaudeCode build
```

#### Build Caching
```bash
# Enable build caching
defaults write com.apple.dt.XCBuild EnableBuildSystemCaching -bool YES
```

## Continuous Integration

### GitHub Actions Workflow

Create `.github/workflows/ios.yml`:
```yaml
name: iOS CI/CD

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
    
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '16.4'
    
    - name: Install Dependencies
      run: |
        brew install xcodegen
        cd apps/ios
        swift package resolve
    
    - name: Generate Project
      run: |
        cd apps/ios
        xcodegen generate
    
    - name: Build
      run: |
        cd apps/ios
        xcodebuild -project ClaudeCode.xcodeproj \
                   -scheme ClaudeCode \
                   -destination 'platform=iOS Simulator,OS=18.6,name=iPhone 16 Pro' \
                   -configuration Debug \
                   clean build
    
    - name: Run Tests
      run: |
        cd apps/ios
        xcodebuild test \
                   -project ClaudeCode.xcodeproj \
                   -scheme ClaudeCode \
                   -destination 'platform=iOS Simulator,OS=18.6,name=iPhone 16 Pro'
```

### Fastlane Integration

Create `fastlane/Fastfile`:
```ruby
default_platform(:ios)

platform :ios do
  desc "Build for development"
  lane :dev do
    xcodegen
    build_app(
      scheme: "ClaudeCode",
      configuration: "Debug",
      export_method: "development"
    )
  end

  desc "Deploy to TestFlight"
  lane :beta do
    xcodegen
    build_app(
      scheme: "ClaudeCode",
      configuration: "Release",
      export_method: "app-store"
    )
    upload_to_testflight
  end

  desc "Deploy to App Store"
  lane :release do
    xcodegen
    build_app(
      scheme: "ClaudeCode",
      configuration: "Release",
      export_method: "app-store"
    )
    upload_to_app_store(
      submit_for_review: true,
      automatic_release: true
    )
  end
end
```

## Troubleshooting

### Common Build Errors

#### Error: No such module 'PackageName'
```bash
# Solution: Reset packages
swift package reset
rm -rf .build
xcodegen generate
```

#### Error: Signing for "ClaudeCode" requires a development team
```bash
# Solution: Set team in Xcode
# Open project settings → Signing & Capabilities
# Select your team or add Apple ID
```

#### Error: Build input file cannot be found
```bash
# Solution: Clean and regenerate
rm -rf ~/Library/Developer/Xcode/DerivedData
xcodegen generate
```

### Build Performance Issues

#### Slow Builds
1. Enable build timing: `defaults write com.apple.dt.Xcode ShowBuildOperationDuration YES`
2. Use incremental builds
3. Reduce parallel build jobs if memory constrained
4. Disable indexing during builds

#### Large App Size
1. Enable App Thinning
2. Remove unused resources
3. Optimize image assets
4. Enable Swift size optimization

## Deployment Checklist

### Pre-Deployment
- [ ] Version number updated in Project.yml
- [ ] Build number incremented
- [ ] All tests passing
- [ ] No compiler warnings
- [ ] API keys removed from code
- [ ] Debug code removed/disabled
- [ ] Performance profiling completed
- [ ] Memory leaks checked

### TestFlight Deployment
- [ ] Archive created successfully
- [ ] Export compliance reviewed
- [ ] Beta app description added
- [ ] Test information provided
- [ ] Internal testers added
- [ ] External test group configured

### App Store Deployment
- [ ] App Store listing complete
- [ ] Screenshots for all devices
- [ ] App preview video (optional)
- [ ] Keywords optimized
- [ ] Privacy policy linked
- [ ] Support URL active
- [ ] Age rating configured
- [ ] App review guidelines checked

## Security Considerations

### API Key Management
- Never commit API keys to repository
- Use environment variables for CI/CD
- Store in Keychain for production
- Rotate keys regularly

### Code Obfuscation
```bash
# Enable for Release builds
SWIFT_COMPILATION_MODE = wholemodule
GCC_OPTIMIZATION_LEVEL = s
```

### Network Security
- Enable ATS for production
- Implement certificate pinning
- Use HTTPS exclusively
- Validate all inputs

## Monitoring Deployment

### Crash Reporting
- Integrate Crashlytics or similar
- Monitor crash-free users rate
- Set up alerts for spikes

### Analytics
- Track user engagement
- Monitor performance metrics
- A/B test new features
- Track conversion rates

## Conclusion

This guide covers the complete build and deployment pipeline for the ClaudeCode iOS application. Follow the appropriate section based on your deployment target, and ensure all prerequisites are met before proceeding with deployment.