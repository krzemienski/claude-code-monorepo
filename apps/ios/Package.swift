// swift-tools-version: 5.10
import PackageDescription

Package(
    name: "ClaudeCode",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "ClaudeCode",
            targets: ["ClaudeCode"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.4.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
        .package(url: "https://github.com/LaunchDarkly/swift-eventsource.git", from: "3.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.0"),
        .package(url: "https://github.com/danielgindi/Charts.git", from: "5.0.0"),
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "ClaudeCode",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "LDSwiftEventSource", package: "swift-eventsource"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "DGCharts", package: "Charts")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ClaudeCodeTests",
            dependencies: [
                "ClaudeCode",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ViewInspector", package: "ViewInspector")
            ],
            path: "Tests"
        )
    ]
)