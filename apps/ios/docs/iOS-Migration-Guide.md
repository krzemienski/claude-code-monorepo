# iOS Migration Guide

## Overview
This guide covers critical migration paths for the ClaudeCode iOS application, including version updates, dependency changes, and architectural improvements.

## Table of Contents
1. [iOS Version Migration (17.0 → 16.0)](#ios-version-migration)
2. [SSH Library Removal](#ssh-library-removal)
3. [Bundle ID Standardization](#bundle-id-standardization)
4. [Actor Concurrency Adoption](#actor-concurrency-adoption)
5. [Breaking Changes](#breaking-changes)
6. [Timeline & Phases](#timeline--phases)

---

## iOS Version Migration

### Context
The project is migrating from iOS 17.0 to iOS 16.0 as the minimum deployment target to support a wider range of devices while maintaining iOS 17+ progressive enhancements.

### Migration Steps

#### 1. Update Project Configuration
```swift
// Project.swift
deploymentTargets: .iOS("16.0")  // Changed from 17.0
```

#### 2. Add Availability Checks
Replace direct iOS 17+ API usage with conditional compilation:

```swift
// ❌ Before (iOS 17+ only)
Image(systemName: "star")
    .symbolEffect(.pulse, value: animationTrigger)

// ✅ After (iOS 16+ compatible)
if #available(iOS 17.0, *) {
    Image(systemName: "star")
        .symbolEffect(.pulse, value: animationTrigger)
} else {
    Image(systemName: "star")
        .scaleEffect(animationTrigger ? 1.2 : 1.0)
        .animation(.easeInOut, value: animationTrigger)
}
```

#### 3. Update Observable Pattern
For iOS 16 compatibility:

```swift
// ❌ iOS 17+ @Observable
@Observable
class ViewModel {
    var data: String = ""
}

// ✅ iOS 16+ @ObservableObject
class ViewModel: ObservableObject {
    @Published var data: String = ""
}
```

#### 4. Navigation API Adjustments
```swift
// iOS 17+ NavigationStack features
if #available(iOS 17.0, *) {
    NavigationStack(path: $path) {
        // Advanced navigation
    }
} else {
    NavigationView {
        // iOS 16 navigation
    }
}
```

### Affected Files
- `Project.swift` - deployment target
- `MCPSettingsView.swift` - symbol effects
- `AccessibilityHelpers.swift` - accessibility APIs
- `ChatConsoleView.swift` - animations
- All ViewModels using @Observable

---

## SSH Library Removal

### Context
The Shout SSH library has been removed as it's not compatible with iOS. Remote monitoring now uses backend API integration.

### Migration Steps

#### 1. Remove Shout Dependency
```swift
// Package.swift or Tuist/Package.swift
// ❌ Remove this line
.package(url: "https://github.com/jakeheis/Shout.git", from: "0.5.7")
```

#### 2. Replace SSH Implementation
```swift
// ❌ Before - Direct SSH
import Shout

class MonitoringService {
    func connectSSH() throws {
        let ssh = try SSH(host: "server.com")
        let result = try ssh.run("ls -la")
    }
}

// ✅ After - Backend API
class MonitoringService {
    func fetchSystemStats() async throws -> SystemStats {
        return try await apiClient.get("/api/monitoring/stats")
    }
}
```

#### 3. Update UI Components
```swift
// MonitoringView.swift
// ❌ Remove SSH UI elements
TextField("SSH Host", text: $sshHost)
SecureField("SSH Password", text: $sshPassword)

// ✅ Replace with API-based monitoring
Text("Monitoring via Backend API")
Button("Refresh Stats") {
    Task {
        stats = try await monitoringService.fetchStats()
    }
}
```

### Affected Components
- `MonitoringViewModel.swift` - replace SSH with MockMonitoringService
- `FileBrowserView.swift` - remove SSH file browsing
- `FilePreviewView.swift` - remove SSH file preview
- `DEVELOPMENT_GUIDE.md` - update documentation
- Remove all references to `SSHClient`, `SSHHost`, `Shout`

### Alternative Solutions
1. **Backend Proxy**: Implement SSH functionality in backend, expose via REST API
2. **WebSocket Bridge**: Use WebSocket for real-time terminal emulation
3. **Cloud Monitoring**: Integrate with cloud monitoring services (CloudWatch, Datadog)

---

## Bundle ID Standardization

### Context
Standardizing the bundle identifier to `com.claudecode.ios` across all configurations and documentation.

### Migration Steps

#### 1. Update Project Configuration
```swift
// Project.swift
bundleId: "com.claudecode.ios"  // Standardized
```

#### 2. Update Info.plist
```xml
<key>CFBundleIdentifier</key>
<string>com.claudecode.ios</string>
```

#### 3. Update Provisioning Profiles
1. Go to Apple Developer Portal
2. Update App ID to `com.claudecode.ios`
3. Regenerate provisioning profiles
4. Download and install in Xcode

#### 4. Update Keychain Access
```swift
// KeychainService.swift
let service = "com.claudecode.ios.keychain"
```

#### 5. Update App Store Connect
1. Update bundle ID in App Information
2. Update any TestFlight builds
3. Update App Store listing

### Verification Checklist
- [ ] Xcode project builds with new bundle ID
- [ ] Keychain data migrates correctly
- [ ] Push notifications work (if applicable)
- [ ] App Store Connect recognizes the app
- [ ] TestFlight distribution works

---

## Actor Concurrency Adoption

### Context
Migrating from traditional concurrency patterns to Swift's actor model for thread safety and memory management.

### Migration Steps

#### 1. Convert Shared State to Actors
```swift
// ❌ Before - Class with locks
class DataManager {
    private let queue = DispatchQueue(label: "data.queue")
    private var cache: [String: Data] = [:]
    
    func get(_ key: String, completion: @escaping (Data?) -> Void) {
        queue.async {
            completion(self.cache[key])
        }
    }
}

// ✅ After - Actor
actor DataManager {
    private var cache: [String: Data] = [:]
    
    func get(_ key: String) -> Data? {
        return cache[key]
    }
}
```

#### 2. Update View Models
```swift
// ❌ Before - DispatchQueue
class ViewModel: ObservableObject {
    @Published var data: [Item] = []
    private let queue = DispatchQueue(label: "vm.queue")
    
    func loadData() {
        queue.async { [weak self] in
            let items = self?.fetchItems() ?? []
            DispatchQueue.main.async {
                self?.data = items
            }
        }
    }
}

// ✅ After - Actor + MainActor
@MainActor
class ViewModel: ObservableObject {
    @Published var data: [Item] = []
    private let dataActor = DataActor()
    
    func loadData() async {
        data = await dataActor.fetchItems()
    }
}
```

#### 3. Implement Task Management
```swift
// Use ActorBasedTaskManagement.swift
class Feature {
    private let taskCoordinator = ActorTaskCoordinator()
    
    func startLongRunningTask() {
        Task {
            await taskCoordinator.register(
                task: performWork()
            )
        }
    }
    
    deinit {
        Task {
            await taskCoordinator.cancelAll()
        }
    }
}
```

#### 4. Memory Management with Actors
```swift
// Use ActorBasedMemoryManagement.swift
actor CacheManager {
    private let cache = ActorMemoryCache<String, Data>(maxSize: 100)
    
    func get(_ key: String) async -> Data? {
        return await cache.get(key)
    }
    
    func store(_ key: String, data: Data) async {
        await cache.set(key, value: data, ttl: 300)
    }
}
```

### Benefits
- **Thread Safety**: Compile-time guarantees against data races
- **Memory Safety**: Automatic prevention of retain cycles
- **Performance**: Better CPU utilization through structured concurrency
- **Debugging**: Clearer async stack traces and error handling

---

## Breaking Changes

### API Changes
1. **Removed APIs**:
   - `SSHClient` - use backend API
   - `SSHHost` - no longer needed
   - SSH-related UI components

2. **Modified APIs**:
   - Monitoring service now async/await
   - File browser uses backend API
   - All ViewModels use @MainActor

3. **New APIs**:
   - `ActorTaskCoordinator` for task management
   - `ActorMemoryCache` for caching
   - `ActorWeakSet` for observer patterns

### Configuration Changes
1. **Bundle ID**: Must update to `com.claudecode.ios`
2. **Deployment Target**: Now iOS 16.0 minimum
3. **Dependencies**: Shout package removed
4. **Build Settings**: Updated for iOS 16.0

### UI Changes
1. **Monitoring View**: Simplified, no SSH options
2. **File Browser**: Backend-based only
3. **Settings**: Removed SSH configuration

---

## Timeline & Phases

### Phase 1: Version Alignment (Week 1)
- [x] Update deployment target to iOS 16.0
- [x] Add iOS 17+ availability checks
- [x] Test on iOS 16.4 simulator
- [x] Update documentation

### Phase 2: SSH Removal (Week 1-2)
- [x] Remove Shout dependency
- [x] Implement MockMonitoringService
- [x] Update UI components
- [x] Clean up documentation

### Phase 3: Bundle ID Standardization (Week 2)
- [x] Update all configurations
- [ ] Regenerate provisioning profiles
- [ ] Update App Store Connect
- [ ] Test distribution

### Phase 4: Actor Migration (Week 2-3)
- [x] Implement actor utilities
- [ ] Convert critical components
- [ ] Update ViewModels
- [ ] Performance testing

### Phase 5: Testing & Validation (Week 3-4)
- [ ] Full regression testing
- [ ] Performance benchmarking
- [ ] Memory leak detection
- [ ] App Store submission

## Rollback Plan

### If Issues Arise
1. **Version Rollback**: Git revert to pre-migration commit
2. **Dependency Restore**: Re-add Shout if needed (with iOS limitation notes)
3. **Bundle ID**: Can maintain both IDs temporarily
4. **Actor Migration**: Can be done incrementally

### Backup Strategy
1. Tag current release: `git tag pre-migration-backup`
2. Create branch: `git checkout -b ios-16-migration`
3. Document all changes in PR
4. Keep old configuration files

## Support & Resources

### Documentation
- [iOS 16 Release Notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-16-release-notes)
- [Swift Concurrency Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Actor Migration WWDC](https://developer.apple.com/wwdc21/10133)

### Internal Resources
- `docs/iOS-16-Deployment-Guide.md`
- `docs/Actor-Concurrency-Architecture.md`
- `docs/iOS-Architecture-Analysis.md`

### Contact
- iOS Team: ios-team@claudecode.com
- Architecture: architecture@claudecode.com
- DevOps: devops@claudecode.com

---

## Appendix: Validation Checklist

### Pre-Migration
- [ ] Full backup of current state
- [ ] Document current bundle ID usage
- [ ] List all iOS 17+ API usage
- [ ] Inventory SSH functionality

### During Migration
- [ ] Run tests after each phase
- [ ] Update documentation immediately
- [ ] Communicate breaking changes
- [ ] Monitor crash reports

### Post-Migration
- [ ] Full regression test suite
- [ ] Performance benchmarks
- [ ] Memory profiling
- [ ] App Store submission test
- [ ] User acceptance testing

## Version History
- v1.0 - Initial migration guide
- v1.1 - Added actor concurrency details
- v1.2 - Updated SSH removal section
- v1.3 - Added rollback procedures