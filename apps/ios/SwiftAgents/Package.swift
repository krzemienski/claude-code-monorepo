// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftAgents",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        // Executables for each agent
        .executable(name: "DocRefactorAgent", targets: ["DocRefactorAgent"]),
        .executable(name: "CodeVerifierAgent", targets: ["CodeVerifierAgent"]),
        .executable(name: "TestEngineerAgent", targets: ["TestEngineerAgent"]),
        .executable(name: "AgentOrchestrator", targets: ["AgentOrchestrator"]),
        
        // Library for shared components
        .library(name: "SwiftAgentsCore", targets: ["SwiftAgentsCore"])
    ],
    dependencies: [
        // Swift Syntax for code parsing
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
        
        // Markdown parsing
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.3.0"),
        
        // Argument parsing for CLI
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        
        // JSON encoding/decoding utilities
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        
        // Async algorithms for concurrent processing
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        
        // Snapshot testing
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.15.0")
    ],
    targets: [
        // Core library with shared components
        .target(
            name: "SwiftAgentsCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            path: "Sources/Core"
        ),
        
        // Agent A: Documentation Refactorer
        .executableTarget(
            name: "DocRefactorAgent",
            dependencies: [
                "SwiftAgentsCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/DocRefactorAgent"
        ),
        
        // Agent B: Code Verifier
        .executableTarget(
            name: "CodeVerifierAgent",
            dependencies: [
                "SwiftAgentsCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/CodeVerifierAgent"
        ),
        
        // Agent C: Test Engineer
        .executableTarget(
            name: "TestEngineerAgent",
            dependencies: [
                "SwiftAgentsCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Sources/TestEngineerAgent"
        ),
        
        // Agent Orchestrator
        .executableTarget(
            name: "AgentOrchestrator",
            dependencies: [
                "SwiftAgentsCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/AgentOrchestrator"
        ),
        
        // Test targets
        .testTarget(
            name: "SwiftAgentsCoreTests",
            dependencies: ["SwiftAgentsCore"],
            path: "Tests/CoreTests"
        ),
        
        .testTarget(
            name: "DocRefactorAgentTests",
            dependencies: ["DocRefactorAgent", "SwiftAgentsCore"],
            path: "Tests/DocRefactorAgentTests"
        ),
        
        .testTarget(
            name: "CodeVerifierAgentTests",
            dependencies: ["CodeVerifierAgent", "SwiftAgentsCore"],
            path: "Tests/CodeVerifierAgentTests"
        ),
        
        .testTarget(
            name: "TestEngineerAgentTests",
            dependencies: ["TestEngineerAgent", "SwiftAgentsCore"],
            path: "Tests/TestEngineerAgentTests"
        )
    ]
)