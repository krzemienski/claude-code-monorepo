# Tuist Setup and Configuration Guide

## Overview

This document provides a comprehensive guide for the Tuist project configuration that replaces the XcodeGen setup for the ClaudeCode iOS application.

## Project Structure

```
apps/ios/
├── Project.swift           # Main project configuration
├── Workspace.swift         # Workspace configuration
├── Config.swift           # Tuist configuration
├── .tuist-version         # Tuist version lock (4.65.4)
├── Tuist/
│   └── ProjectDescriptionHelpers/
│       └── Project+Templates.swift  # Reusable templates
├── Sources/
│   ├── App/              # Main app source
│   └── Features/         # Feature modules
├── Tests/                # Unit tests
└── UITests/              # UI tests
```

## Core Configuration Files

### 1. Project.swift

The main project configuration defines:
- **App Target**: Main iOS application
- **Test Targets**: Unit and UI tests
- **Dependencies**: Swift Package Manager integration
- **Build Settings**: Debug and Release configurations
- **Schemes**: Development, testing, and performance profiling

Key Features:
- iOS 16.0 minimum deployment target
- Universal app (iPhone and iPad)
- SwiftUI-based architecture
- Integrated SPM dependencies
- Code coverage enabled
- SwiftLint and SwiftFormat integration

### 2. Workspace.swift

Defines the workspace structure with:
- **ClaudeCode-All**: Full build with all targets
- **ClaudeCode-Dev**: Development scheme with debugging
- **ClaudeCode-Performance**: Performance profiling scheme

### 3. Config.swift

Global Tuist configuration:
- Swift version 5.10
- Compatible with all Xcode versions
- Dependency resolution settings

## Dependencies

The project includes the following Swift packages:

| Package | Version | Purpose |
|---------|---------|---------|
| swift-log | 1.5.0+ | Logging infrastructure |
| swift-metrics | 2.4.0+ | Metrics collection |
| swift-collections | 1.1.0+ | Advanced data structures |
| swift-eventsource | 3.0.0+ | Server-sent events |
| KeychainAccess | 4.2.0+ | Secure storage |
| Charts | 5.0.0+ | Data visualization |
| ViewInspector | 0.9.0+ | SwiftUI testing |

## Build Configurations

### Debug Configuration
- Optimization: None (`-Onone`)
- Compilation Mode: Single file
- Testability: Enabled
- Debug symbols: DWARF format
- Active compilation conditions: DEBUG

### Release Configuration
- Optimization: Full (`-O`)
- Compilation Mode: Whole module
- Testability: Disabled
- Debug symbols: DWARF with dSYM
- Validation: Enabled

## Schemes

### 1. ClaudeCode (Main)
- **Build**: App target only
- **Test**: Unit tests with coverage
- **Run**: Debug configuration with environment variables
- **Archive**: Release configuration
- **Profile**: Release with profiling

### 2. ClaudeCode-Tests
- **Build**: App and test targets
- **Test**: Parallel test execution with coverage
- **Options**: Random test ordering enabled

### 3. ClaudeCode-UITests
- **Build**: App and UI test targets
- **Test**: Sequential UI test execution
- **Run**: App target for manual testing

### 4. ClaudeCode-Dev (Workspace)
- **Environment**: Development settings
- **Logging**: Enhanced debugging output
- **Network**: Local API server connection

### 5. ClaudeCode-Performance (Workspace)
- **Build**: Release configuration
- **Profile**: Performance monitoring enabled
- **GPU**: Frame capture and validation

## Setup Instructions

### Prerequisites

1. Install Tuist (if not already installed):
```bash
curl -Ls https://install.tuist.io | bash
```

2. Verify installation:
```bash
tuist version
# Should show: 4.65.4
```

### Project Generation

1. Navigate to the iOS project directory:
```bash
cd apps/ios
```

2. Clean any existing Xcode files:
```bash
rm -rf *.xcodeproj *.xcworkspace
tuist clean
```

3. Generate the Xcode project:
```bash
tuist generate
```

4. Open the workspace:
```bash
open ClaudeCode.xcworkspace
```

### Building and Testing

#### Command Line

Build the project:
```bash
tuist build
```

Run tests:
```bash
tuist test
```

#### Xcode

1. Select the desired scheme from the scheme selector
2. Choose target device/simulator
3. Build: `⌘B`
4. Run: `⌘R`
5. Test: `⌘U`

## Migration from XcodeGen

### Key Differences

| Aspect | XcodeGen | Tuist |
|--------|----------|------|
| Configuration | YAML (`project.yml`) | Swift (`Project.swift`) |
| Type Safety | No | Yes (Swift compiler) |
| Helpers | Limited | Full Swift capabilities |
| Caching | No | Yes (built-in) |
| Dependencies | Manual SPM | Integrated SPM |
| Modularity | Basic | Advanced with helpers |

### Migration Steps

1. **Remove XcodeGen artifacts**:
   - Delete `project.yml`
   - Remove `.xcodegen` directory
   - Clean derived data

2. **Update CI/CD**:
   Replace:
   ```bash
   xcodegen generate
   ```
   With:
   ```bash
   tuist generate
   ```

3. **Update documentation**:
   - Replace XcodeGen references with Tuist
   - Update build instructions
   - Update dependency management docs

## Modularization Support

The configuration supports future modularization:

```swift
// Future module structure
Modules/
├── Core/           # Shared utilities
├── Networking/     # API client
├── UI/            # Design system
└── Analytics/     # Metrics and tracking
```

Each module can have its own `Project.swift` using the helpers:

```swift
import ProjectDescriptionHelpers

let project = Project.featureModule(
    name: "Networking",
    dependencies: [
        .external(name: "Alamofire")
    ]
)
```

## Troubleshooting

### Common Issues

1. **Tuist version mismatch**:
   ```bash
   tuist install 4.65.4
   ```

2. **Cache issues**:
   ```bash
   tuist clean
   rm -rf ~/Library/Caches/tuist
   ```

3. **Dependency resolution**:
   ```bash
   tuist fetch
   ```

4. **Build failures**:
   - Check Swift version: 5.10
   - Verify Xcode version compatibility
   - Clean and regenerate project

### Performance Optimization

1. **Enable caching**:
   ```bash
   tuist cache warm
   ```

2. **Parallel builds**:
   Already configured in schemes

3. **Incremental compilation**:
   Enabled by default in debug configuration

## Best Practices

1. **Always use Tuist commands** for project generation
2. **Don't commit generated files** (`.xcodeproj`, `.xcworkspace`)
3. **Keep helpers modular** for reusability
4. **Use schemes** for different workflows
5. **Version lock Tuist** using `.tuist-version`
6. **Document custom configurations** in helpers

## Additional Resources

- [Tuist Documentation](https://docs.tuist.io)
- [Swift Package Manager](https://swift.org/package-manager/)
- [Project Structure Best Practices](https://docs.tuist.io/guides/project-structure)

## Support

For issues or questions:
1. Check this documentation
2. Review Tuist logs: `~/.tuist/logs`
3. Run diagnostics: `tuist doctor`