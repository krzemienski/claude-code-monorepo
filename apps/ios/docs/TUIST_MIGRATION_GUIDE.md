# Tuist Migration Guide

## 🎯 Overview

This iOS project has been migrated from manual Xcode project management to **Tuist**, a powerful project generation tool that provides:
- ✅ Declarative project configuration
- ✅ Reproducible builds across team members
- ✅ Simplified dependency management
- ✅ Elimination of `.xcodeproj` merge conflicts
- ✅ Consistent project structure

## 📁 Project Structure

```
apps/ios/
├── Project.swift           # Main Tuist configuration
├── Tuist.swift            # Tuist settings
├── Tuist/
│   ├── Package.swift      # External dependencies
│   └── Dependencies.swift # Dependency configuration
├── Sources/
│   ├── App/              # Main app code
│   └── Features/         # Feature modules
├── Tests/                # Unit tests
├── UITests/              # UI tests
└── scripts/
    └── build.sh          # CI/CD build script
```

## 🚀 Getting Started

### Prerequisites

1. **Install Tuist**:
   ```bash
   curl -Ls https://install.tuist.io | bash
   ```

2. **Verify installation**:
   ```bash
   tuist version
   ```

### Daily Workflow

1. **Generate Xcode project**:
   ```bash
   tuist generate
   ```
   This creates `ClaudeCode.xcworkspace` which you open in Xcode.

2. **Install/Update dependencies**:
   ```bash
   tuist install
   ```

3. **Clean generated files**:
   ```bash
   tuist clean
   ```

## 🔧 Configuration Files

### Project.swift
The main configuration file defining:
- Target configurations (app, tests, UI tests)
- Build settings
- Source and resource paths
- Dependencies
- Info.plist values

### Tuist/Package.swift
Defines external Swift Package Manager dependencies:
- Apple libraries (Logging, Metrics, Collections)
- Networking (LDSwiftEventSource)
- Security (KeychainAccess)
- UI Components (DGCharts)

### Tuist/Dependencies.swift
Advanced dependency configuration with:
- Product types (framework vs static library)
- Platform-specific settings
- Build configurations

## 📝 Common Tasks

### Adding a New File
1. Add the Swift file to appropriate directory under `Sources/`
2. Run `tuist generate` to update project
3. File will automatically be included

### Adding a New Dependency
1. Edit `Tuist/Package.swift`:
   ```swift
   .package(url: "https://github.com/...", from: "1.0.0")
   ```
2. Add to `Project.swift` target dependencies:
   ```swift
   dependencies: [
       .external(name: "PackageName")
   ]
   ```
3. Run `tuist install` and `tuist generate`

### Creating a New Target
Edit `Project.swift`:
```swift
targets: [
    // ... existing targets
    .target(
        name: "NewTarget",
        destinations: .iOS,
        product: .framework,
        bundleId: "com.claudecode.newtarget",
        // ... configuration
    )
]
```

## 🏗️ Build & Test

### Local Build
```bash
# Using the build script
./scripts/build.sh Debug

# Or directly with xcodebuild
xcodebuild build \
    -workspace ClaudeCode.xcworkspace \
    -scheme ClaudeCode \
    -configuration Debug
```

### Run Tests
```bash
# Using the build script
./scripts/build.sh Debug "platform=iOS Simulator,name=iPhone 15 Pro" --test

# Or directly
xcodebuild test \
    -workspace ClaudeCode.xcworkspace \
    -scheme ClaudeCode \
    -enableCodeCoverage YES
```

## 🚦 CI/CD

The project includes GitHub Actions workflow (`.github/workflows/ios-ci.yml`) that:
1. Installs Tuist
2. Generates the Xcode project
3. Builds the app
4. Runs tests
5. Reports code coverage

### Manual CI Build
```bash
# From project root
cd apps/ios
./scripts/build.sh Release
```

## ⚠️ Important Notes

### DO NOT Commit
- ❌ `ClaudeCode.xcworkspace`
- ❌ `ClaudeCode.xcodeproj`
- ❌ `*.xcworkspace`
- ❌ `*.xcodeproj`
- ❌ `.tuist-cache/`

These are generated files and should be in `.gitignore`.

### DO Commit
- ✅ `Project.swift`
- ✅ `Tuist.swift`
- ✅ `Tuist/Package.swift`
- ✅ `Tuist/Dependencies.swift`
- ✅ `Tuist/Package.resolved`
- ✅ Source files
- ✅ Resources
- ✅ Info.plist files

## 🐛 Troubleshooting

### "tuist: command not found"
```bash
curl -Ls https://install.tuist.io | bash
```

### "No such module" errors
```bash
tuist install
tuist generate
```

### Xcode project out of sync
```bash
tuist clean
tuist generate
```

### Build cache issues
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf .tuist-cache
tuist generate
```

## 📚 Resources

- [Tuist Documentation](https://docs.tuist.io)
- [Tuist Examples](https://github.com/tuist/examples)
- [Migration Guide](https://docs.tuist.io/guides/migration)
- [Community Forum](https://community.tuist.io)

## 🤝 Team Guidelines

1. **Always run `tuist generate` after pulling changes**
2. **Never edit `.xcodeproj` files directly**
3. **Commit `Package.resolved` for reproducible builds**
4. **Use `tuist edit` to modify configuration with autocomplete**
5. **Run tests locally before pushing**

## 📈 Benefits of Migration

- **No more merge conflicts** in `.xcodeproj` files
- **Consistent project settings** across team
- **Faster onboarding** for new developers
- **Simplified CI/CD** configuration
- **Better dependency management**
- **Modular architecture** support

---

For questions or issues, consult the Tuist documentation or reach out to the iOS team lead.