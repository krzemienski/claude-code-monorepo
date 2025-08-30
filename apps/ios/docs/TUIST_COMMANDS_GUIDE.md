# Tuist Commands Guide

## Overview

This guide documents all Tuist commands used in the `ios-build.sh` script and provides comprehensive information about Tuist project management for the ClaudeCode iOS app.

## Core Tuist Commands

### 1. `tuist clean`
**Purpose**: Removes all generated files and cleans the project workspace.

**Usage**:
```bash
tuist clean
```

**When to use**:
- Before switching branches
- When experiencing build issues
- To ensure a clean build environment
- After modifying Project.swift significantly

**What it does**:
- Removes `.build/` directory
- Removes `Derived/` directory  
- Cleans generated Xcode project files
- Resets cached configurations

### 2. `tuist generate`
**Purpose**: Generates the Xcode project and workspace from Project.swift configuration.

**Usage**:
```bash
tuist generate
```

**When to use**:
- After modifying Project.swift
- After pulling changes from git
- When setting up the project for the first time
- After running `tuist clean`

**What it generates**:
- `ClaudeCode.xcodeproj` - Xcode project file
- `ClaudeCode.xcworkspace` - Xcode workspace (if dependencies exist)
- Build configurations (Debug/Release)
- Scheme definitions

### 3. `tuist fetch`
**Purpose**: Downloads and resolves external dependencies defined in Package.swift.

**Usage**:
```bash
tuist fetch
```

**When to use**:
- After adding new Swift Package dependencies
- When setting up project on a new machine
- After modifying Tuist/Package.swift

**What it does**:
- Downloads Swift Package Manager dependencies
- Resolves version conflicts
- Caches dependencies locally
- Integrates packages into the project

### 4. `tuist install`
**Purpose**: Installs Tuist-managed dependencies and tools.

**Usage**:
```bash
tuist install
```

**When to use**:
- Initial project setup
- After Tuist version updates
- When dependencies fail to resolve

### 5. `tuist edit`
**Purpose**: Opens Project.swift in Xcode for editing with code completion.

**Usage**:
```bash
tuist edit
```

**Benefits**:
- Full Swift code completion for Project.swift
- Syntax highlighting and error checking
- Easy navigation between configuration files
- Live validation of configuration

### 6. `tuist graph`
**Purpose**: Generates a visual dependency graph of the project.

**Usage**:
```bash
tuist graph              # Generate and open graph
tuist graph --format dot # Export as DOT format
tuist graph --format png # Export as PNG image
```

**When to use**:
- Understanding project structure
- Identifying circular dependencies
- Documentation purposes
- Architecture reviews

### 7. `tuist cache`
**Purpose**: Manages build cache for faster compilation.

**Usage**:
```bash
tuist cache warm    # Pre-build dependencies
tuist cache print   # Show cache status
```

**Benefits**:
- Faster incremental builds
- Shared cache across team
- Reduced CI/CD build times

## Integration with ios-build.sh

The `ios-build.sh` script wraps these Tuist commands with additional functionality:

### Script Actions

#### `./ios-build.sh clean`
- Executes `tuist clean`
- Removes additional build artifacts
- Clears DerivedData if needed

#### `./ios-build.sh generate`
- Runs `tuist fetch` to get dependencies
- Executes `tuist generate`
- Validates generated project

#### `./ios-build.sh build [config] [device]`
- Ensures project is generated
- Builds using xcodebuild with specified configuration
- Supports Debug/Release configurations
- Targets specific simulator devices

#### `./ios-build.sh run [config] [device]`
- Builds the app
- Boots simulator
- Installs and launches app
- Streams console logs

#### `./ios-build.sh test [config] [device]`
- Runs unit tests
- Generates coverage reports
- Outputs test results

#### `./ios-build.sh all [config] [device]`
- Complete workflow: clean → generate → build → test → run

## Project.swift Configuration

### Key Sections

```swift
import ProjectDescription

let project = Project(
    name: "ClaudeCode",
    
    // Organization settings
    organizationName: "ClaudeCode",
    
    // Platform and version
    deploymentTargets: .iOS("16.0"),
    
    // Build settings
    settings: Settings.settings(
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    
    // Targets
    targets: [
        // Main app target
        .target(
            name: "ClaudeCode",
            destinations: .iOS,
            product: .app,
            bundleId: "com.anthropic.ClaudeCode"
        ),
        
        // Unit tests
        .target(
            name: "ClaudeCodeTests",
            destinations: .iOS,
            product: .unitTests
        ),
        
        // UI tests
        .target(
            name: "ClaudeCodeUITests",
            destinations: .iOS,
            product: .uiTests
        )
    ]
)
```

## Best Practices

### 1. Version Control
- **DO**: Commit Project.swift and Package.swift
- **DON'T**: Commit generated .xcodeproj or .xcworkspace files
- **DO**: Add `*.xcodeproj` and `*.xcworkspace` to .gitignore

### 2. Dependency Management
- Define all dependencies in `Tuist/Package.swift`
- Use specific version requirements
- Run `tuist fetch` after dependency changes
- Cache dependencies for CI/CD

### 3. Build Configurations
- Use Debug for development
- Use Release for TestFlight/App Store
- Define environment-specific settings in Project.swift
- Keep sensitive data in xcconfig files

### 4. Team Collaboration
- Always run `tuist generate` after pulling changes
- Document Project.swift modifications
- Use `tuist graph` to visualize changes
- Share build cache when possible

## Troubleshooting

### Common Issues and Solutions

#### "Project.swift not found"
**Solution**: Ensure you're in the project root directory containing Project.swift

#### "Dependencies not resolving"
**Solution**: 
```bash
tuist clean
tuist fetch
tuist generate
```

#### "Build fails after Project.swift changes"
**Solution**:
```bash
./ios-build.sh clean
./ios-build.sh generate
./ios-build.sh build
```

#### "Simulator not found"
**Solution**: 
- Check available simulators: `xcrun simctl list devices`
- Create missing simulator: `xcrun simctl create "iPhone 15" "iPhone 15"`

## Advanced Usage

### Custom Build Settings
Add to Project.swift:
```swift
settings: Settings.settings(
    base: [
        "SWIFT_VERSION": "5.9",
        "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
        "CODE_SIGN_IDENTITY": ""
    ]
)
```

### Environment Variables
Use in ios-build.sh:
```bash
TUIST_CONFIG=Release ./ios-build.sh build
```

### CI/CD Integration
```bash
# GitHub Actions example
- name: Build iOS App
  run: |
    tuist fetch
    tuist generate
    tuist build --configuration Release
```

## Why Tuist?

### Key Benefits
- **Type-safe configuration**: Swift code instead of YAML
- **Built-in caching**: Faster incremental builds
- **Better dependency management**: Full SPM integration
- **Module support**: True modular architecture
- **Performance**: Optimized build times
- **Team collaboration**: Consistent environment across team

### Tuist Advantages
| Feature | Benefit |
|---------|---------||
| Project.swift | Type-safe Swift configuration |
| tuist generate | Fast project generation |
| Built-in cache | Reduced build times |
| Module support | Better code organization |
| Dependency graph | Visual architecture |
| Hot reload | Faster development |

## Additional Resources

- [Tuist Documentation](https://docs.tuist.io)
- [Project.swift Reference](https://docs.tuist.io/manifests/project)
- [Tuist CLI Reference](https://docs.tuist.io/commands/generate)
- [Migration Guide](https://docs.tuist.io/guides/migration)

## Summary

Tuist provides a powerful, type-safe way to manage iOS projects. The `ios-build.sh` script simplifies common workflows while Project.swift serves as the single source of truth for project configuration. This approach ensures consistency, reduces merge conflicts, and improves build times across the team.

### Quick Reference
```bash
# Daily workflow
./ios-build.sh clean      # Start fresh
./ios-build.sh generate   # Update project
./ios-build.sh build      # Build app
./ios-build.sh run        # Run in simulator
./ios-build.sh test       # Run tests

# Or all at once
./ios-build.sh all
```