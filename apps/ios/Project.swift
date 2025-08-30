import ProjectDescription

let project = Project(
    name: "ClaudeCode",
    organizationName: "Claude Code",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.10"
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    targets: [
        .target(
            name: "ClaudeCode",
            destinations: .iOS,
            product: .app,
            bundleId: "com.claudecode.ios",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                "UISupportedInterfaceOrientations~ipad": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationPortraitUpsideDown",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight"
                ],
                "LSRequiresIPhoneOS": true,
                "UIRequiredDeviceCapabilities": ["armv7"],
                "CFBundleDisplayName": "Claude Code",
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "1",
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": false,
                    "NSExceptionDomains": [
                        "localhost": [
                            "NSTemporaryExceptionAllowsInsecureHTTPLoads": true
                        ]
                    ]
                ]
            ]),
            sources: ["Sources/**"],
            resources: [
                "Sources/App/Theme/Tokens.css"
            ],
            dependencies: [
                .external(name: "Logging"),
                .external(name: "Metrics"),
                .external(name: "Collections"),
                .external(name: "LDSwiftEventSource"),
                .external(name: "KeychainAccess"),
                .external(name: "DGCharts")
            ],
            settings: .settings(
                base: [
                    "INFOPLIST_FILE": "Sources/App/Info.plist"
                ]
            )
        ),
        .target(
            name: "ClaudeCodeTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.claudecode.ios.tests",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "ClaudeCode"),
                .external(name: "Logging")
            ],
            settings: .settings(
                base: [
                    "INFOPLIST_FILE": "Tests/Info.plist"
                ]
            )
        ),
        .target(
            name: "ClaudeCodeUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "com.claudecode.ios.uitests",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .default,
            sources: ["UITests/**"],
            dependencies: [
                .target(name: "ClaudeCode")
            ],
            settings: .settings(
                base: [
                    "INFOPLIST_FILE": "UITests/Info.plist"
                ]
            )
        )
    ]
)
