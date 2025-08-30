// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "Logging": .framework,
        "Metrics": .framework,
        "Collections": .framework,
        "LDSwiftEventSource": .framework,
        "KeychainAccess": .framework,
        "DGCharts": .framework
        // "Shout": .framework - Removed, not compatible with iOS
    ]
)
#endif

let package = Package(
    name: "ClaudeCodeDependencies",
    dependencies: [
        // Logging & Metrics
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.4.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        
        // Networking & Streaming
        .package(url: "https://github.com/LaunchDarkly/swift-eventsource.git", from: "3.0.0"),
        
        // Security
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.0"),
        
        // UI Components
        .package(url: "https://github.com/danielgindi/Charts.git", from: "5.0.0")
        
        // SSH - Removed as it's not compatible with iOS (requires libssh2)
        // .package(url: "https://github.com/jakeheis/Shout.git", from: "0.5.7")
    ]
)