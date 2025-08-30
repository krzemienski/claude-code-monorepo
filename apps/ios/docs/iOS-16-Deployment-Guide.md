# iOS 16 Deployment Guide

## Overview
ClaudeCode iOS app targets iOS 16.0 as the minimum deployment version, with progressive enhancement for iOS 17+ features.

## Version Requirements

### Minimum Requirements
- **iOS Version**: 16.0 or later
- **Xcode**: 15.0 or later (for iOS 16.0 SDK)
- **macOS**: Ventura 13.0 or later
- **Swift**: 5.10

### Deployment Targets
```swift
// Project.swift
deploymentTargets: .iOS("16.0")
```

## iOS Version Strategy

### iOS 16.0 (Base Support)
All core functionality is available on iOS 16.0:
- SwiftUI core components
- Async/await and Swift concurrency
- Navigation system
- Network connectivity
- Keychain integration
- Charts and visualization

### iOS 17.0+ (Progressive Enhancement)
Enhanced features for iOS 17+ devices:
```swift
// Example of conditional feature usage
if #available(iOS 17.0, *) {
    // Use iOS 17+ features
    view.symbolEffect(.pulse, value: animationTrigger)
} else {
    // Fallback for iOS 16
    view.scaleEffect(animationTrigger ? 1.1 : 1.0)
}
```

## Feature Availability Matrix

| Feature | iOS 16.0 | iOS 17.0+ | Notes |
|---------|----------|-----------|--------|
| **Core UI** | ✅ | ✅ | Full SwiftUI support |
| **SSE Networking** | ✅ | ✅ | URLSession-based |
| **Actor Concurrency** | ✅ | ✅ | Swift 5.5+ feature |
| **Symbol Effects** | ❌ | ✅ | iOS 17+ animation |
| **Observation Framework** | ❌ | ✅ | @Observable macro |
| **ScrollView Enhancements** | ❌ | ✅ | Advanced scrolling |
| **Interactive Widgets** | ❌ | ✅ | Widget interactivity |

## Conditional Compilation

### Symbol Effects (iOS 17+)
```swift
// MCPSettingsView.swift
if #available(iOS 17.0, *) {
    Image(systemName: icon)
        .symbolEffect(.pulse, value: pulseAnimation)
} else {
    // iOS 16 fallback
    Image(systemName: icon)
        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
        .animation(.easeInOut, value: pulseAnimation)
}
```

### Accessibility Enhancements (iOS 17+)
```swift
// AccessibilityHelpers.swift
if #available(iOS 17.0, *) {
    view.accessibilityZoomAction { action in
        // iOS 17+ zoom handling
    }
} else {
    // iOS 16 alternative
    view.accessibilityAction(.magicTap) {
        // Fallback zoom behavior
    }
}
```

## Build Configuration

### Xcode Settings
```xml
<!-- Info.plist -->
<key>MinimumOSVersion</key>
<string>16.0</string>
```

### Swift Package Manager
```swift
// Package.swift
platforms: [
    .iOS(.v16)
]
```

### Tuist Configuration
```swift
// Project.swift
deploymentTargets: .iOS("16.0")
```

## Testing Strategy

### Simulator Testing
```bash
# Test on iOS 16.4 (oldest supported)
xcrun simctl create "iPhone 14 iOS 16" "iPhone 14" "iOS16.4"

# Test on iOS 17.0 (progressive features)
xcrun simctl create "iPhone 15 iOS 17" "iPhone 15" "iOS17.0"
```

### Device Testing Matrix
- **iOS 16.0-16.7**: Core functionality validation
- **iOS 17.0+**: Enhanced feature validation
- **Latest iOS**: Future compatibility

## App Store Submission

### Metadata Requirements
- Minimum iOS Version: 16.0
- Recommended iOS Version: 17.0 or later
- Optimized for: iPhone 14 and later

### Binary Configuration
```bash
# Archive with iOS 16.0 deployment target
xcodebuild archive \
  -workspace ClaudeCode.xcworkspace \
  -scheme ClaudeCode \
  -archivePath ClaudeCode.xcarchive \
  IPHONEOS_DEPLOYMENT_TARGET=16.0
```

## Migration Notes

### From iOS 17.0 to 16.0
If migrating from iOS 17.0 deployment target:

1. **Remove iOS 17-only APIs**:
   - Replace @Observable with @ObservableObject
   - Remove symbol effects or add fallbacks
   - Update navigation APIs if needed

2. **Add Compatibility Checks**:
   ```swift
   if #available(iOS 17.0, *) {
       // iOS 17+ code
   } else {
       // iOS 16 fallback
   }
   ```

3. **Test Thoroughly**:
   - Run on iOS 16.4 simulator
   - Validate all features work
   - Check performance on older devices

## Performance Considerations

### iOS 16 Devices
- iPhone 14 series
- iPhone 13 series
- iPhone 12 series
- iPhone 11 series
- iPhone SE (2nd & 3rd gen)
- iPad (7th gen and later)

### Optimization Tips
1. Use lazy loading for heavy views
2. Implement image caching
3. Optimize animation complexity for older devices
4. Consider reducing particle effects on iOS 16

## Troubleshooting

### Common Issues

#### Symbol Effects Not Working
**Issue**: `.symbolEffect()` crashes on iOS 16
**Solution**: Always wrap in availability check
```swift
if #available(iOS 17.0, *) {
    // Use symbol effects
}
```

#### Navigation Issues
**Issue**: NavigationStack behavior differences
**Solution**: Test navigation thoroughly on iOS 16.4

#### Performance on Older Devices
**Issue**: Animations stuttering on iPhone 11
**Solution**: Reduce animation complexity or provide simpler alternatives

## Resources
- [Apple iOS 16 Release Notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-16-release-notes)
- [SwiftUI iOS 16 Features](https://developer.apple.com/documentation/swiftui)
- [iOS Version Adoption Stats](https://developer.apple.com/support/app-store/)