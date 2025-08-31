import ProjectDescription

// MARK: - Project Configuration
let project = Project(
    name: "ClaudeCode",
    organizationName: "Claude Code",
    options: .options(
        developmentRegion: "en",
        xcodeProjectName: "ClaudeCode"
    ),
    packages: [
        .remote(url: "https://github.com/apple/swift-log.git", requirement: .upToNextMajor(from: "1.5.0")),
        .remote(url: "https://github.com/apple/swift-metrics.git", requirement: .upToNextMajor(from: "2.4.0")),
        .remote(url: "https://github.com/apple/swift-collections.git", requirement: .upToNextMajor(from: "1.1.0")),
        .remote(url: "https://github.com/LaunchDarkly/swift-eventsource.git", requirement: .upToNextMajor(from: "3.0.0")),
        .remote(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", requirement: .upToNextMajor(from: "4.2.0")),
        .remote(url: "https://github.com/danielgindi/Charts.git", requirement: .upToNextMajor(from: "5.0.0")),
        .remote(url: "https://github.com/nalexn/ViewInspector.git", requirement: .upToNextMajor(from: "0.9.0"))
    ],
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.10",
            "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
            "SUPPORTS_MACCATALYST": "YES",
            "MARKETING_VERSION": "1.0.0",
            "CURRENT_PROJECT_VERSION": "1",
            "GENERATE_INFOPLIST_FILE": "YES",
            "ENABLE_PREVIEWS": "YES",
            "DEVELOPMENT_LANGUAGE": "en"
        ],
        configurations: [
            .debug(name: "Debug", settings: [
                "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
                "SWIFT_COMPILATION_MODE": "singlefile",
                "ENABLE_TESTABILITY": "YES",
                "DEBUG_INFORMATION_FORMAT": "dwarf",
                "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
                "GCC_OPTIMIZATION_LEVEL": "0",
                "ONLY_ACTIVE_ARCH": "YES",
                "COPY_PHASE_STRIP": "NO"
            ]),
            .release(name: "Release", settings: [
                "SWIFT_OPTIMIZATION_LEVEL": "-O",
                "SWIFT_COMPILATION_MODE": "wholemodule",
                "ENABLE_TESTABILITY": "NO",
                "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
                "VALIDATE_PRODUCT": "YES",
                "GCC_OPTIMIZATION_LEVEL": "s",
                "COPY_PHASE_STRIP": "YES"
            ])
        ]
    ),
    targets: [
        // MARK: - Main App Target
        .target(
            name: "ClaudeCode",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.claudecode.ios",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Claude Code",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "UILaunchScreen": [
                    "UIColorName": "AccentColor",
                    "UIImageName": "LaunchIcon"
                ],
                "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                "UISupportedInterfaceOrientations~ipad": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationPortraitUpsideDown",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight"
                ],
                "LSRequiresIPhoneOS": true,
                "UIRequiredDeviceCapabilities": ["armv7"],
                "UIStatusBarStyle": "UIStatusBarStyleDefault",
                "UIViewControllerBasedStatusBarAppearance": false,
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": false,
                    "NSExceptionDomains": [
                        "localhost": [
                            "NSTemporaryExceptionAllowsInsecureHTTPLoads": true,
                            "NSTemporaryExceptionMinimumTLSVersion": "1.0",
                            "NSTemporaryExceptionRequiresForwardSecrecy": false
                        ]
                    ]
                ],
                "ITSAppUsesNonExemptEncryption": false,
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": true,
                    "UISceneConfigurations": [:]
                ]
            ]),
            sources: [
                .glob("Sources/App/**", excluding: ["**/*.md", "**/*.txt"]),
                .glob("Sources/Features/**", excluding: ["**/*.md", "**/*.txt"])
            ],
            resources: [
                .glob(pattern: "Sources/App/Resources/**", excluding: ["**/.DS_Store"]),
                .glob(pattern: "Sources/App/Theme/**/*.css"),
                .glob(pattern: "Sources/Assets.xcassets"),
                .glob(pattern: "Sources/**/Localizable.strings")
            ],
            dependencies: [
                .external(name: "Logging", condition: .none),
                .external(name: "Metrics", condition: .none),
                .external(name: "Collections", condition: .none),
                .external(name: "LDSwiftEventSource", condition: .none),
                .external(name: "KeychainAccess", condition: .none),
                .external(name: "DGCharts", condition: .none)
            ],
            settings: .settings(
                base: [
                    "PRODUCT_NAME": "$(TARGET_NAME)",
                    "SWIFT_EMIT_LOC_STRINGS": "YES",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                    "CODE_SIGN_STYLE": "Automatic",
                    "DEVELOPMENT_TEAM": "",
                    "PROVISIONING_PROFILE_SPECIFIER": "",
                    "ENABLE_HARDENED_RUNTIME": "YES",
                    "COMBINE_HIDPI_IMAGES": "YES"
                ],
                configurations: [
                    .debug(name: "Debug", settings: [
                        "CODE_SIGN_IDENTITY": "iPhone Developer",
                        "PROVISIONING_PROFILE": "",
                        "OTHER_SWIFT_FLAGS": "-DDEBUG -enable-testing"
                    ]),
                    .release(name: "Release", settings: [
                        "CODE_SIGN_IDENTITY": "iPhone Distribution",
                        "PROVISIONING_PROFILE": "",
                        "OTHER_SWIFT_FLAGS": "-DRELEASE"
                    ])
                ]
            )
        ),
        
        // MARK: - Unit Tests Target
        .target(
            name: "ClaudeCodeTests",
            destinations: [.iPhone, .iPad],
            product: .unitTests,
            bundleId: "com.claudecode.ios.tests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: [
                .glob("Tests/**", excluding: ["**/*.md", "**/*.txt", "**/UITests/**", "**/*.bak"])
            ],
            resources: [],
            dependencies: [
                .target(name: "ClaudeCode"),
                .external(name: "Logging", condition: .none),
                .external(name: "ViewInspector", condition: .none)
            ],
            settings: .settings(
                base: [
                    "PRODUCT_NAME": "$(TARGET_NAME)",
                    "SWIFT_EMIT_LOC_STRINGS": "NO",
                    "BUNDLE_LOADER": "$(TEST_HOST)",
                    "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/ClaudeCode.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ClaudeCode",
                    "ENABLE_TESTING_SEARCH_PATHS": "YES"
                ],
                configurations: [
                    .debug(name: "Debug", settings: [
                        "GCC_C_LANGUAGE_STANDARD": "gnu11",
                        "OTHER_SWIFT_FLAGS": "-DDEBUG -enable-testing"
                    ]),
                    .release(name: "Release", settings: [
                        "GCC_C_LANGUAGE_STANDARD": "gnu11",
                        "OTHER_SWIFT_FLAGS": "-DRELEASE"
                    ])
                ]
            )
        ),
        
        // MARK: - UI Tests Target
        .target(
            name: "ClaudeCodeUITests",
            destinations: [.iPhone, .iPad],
            product: .uiTests,
            bundleId: "com.claudecode.ios.uitests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: [
                .glob("UITests/**", excluding: ["**/*.md", "**/*.txt"])
            ],
            dependencies: [
                .target(name: "ClaudeCode")
            ],
            settings: .settings(
                base: [
                    "PRODUCT_NAME": "$(TARGET_NAME)",
                    "SWIFT_EMIT_LOC_STRINGS": "NO",
                    "TEST_TARGET_NAME": "ClaudeCode",
                    "UI_TESTING_BUNDLE_ID": "com.claudecode.ios"
                ]
            )
        )
    ],
    schemes: [
        // MARK: - Main Development Scheme
        .scheme(
            name: "ClaudeCode",
            shared: true,
            buildAction: .buildAction(targets: [.init(stringLiteral: "ClaudeCode")]),
            testAction: .targets(
                ["ClaudeCodeTests"],
                configuration: "Debug",
                options: .options(
                    language: .init("en"),
                    region: "US",
                    coverage: true,
                    codeCoverageTargets: [.init(stringLiteral: "ClaudeCode")]
                )
            ),
            runAction: .runAction(
                configuration: "Debug",
                executable: .init(stringLiteral: "ClaudeCode"),
                arguments: .arguments(
                    environmentVariables: [
                        "CLAUDE_CODE_ENV": "development",
                        "CLAUDE_CODE_DEBUG": "1",
                        "CLAUDE_CODE_LOG_LEVEL": "debug"
                    ]
                )
            ),
            archiveAction: .archiveAction(
                configuration: "Release",
                revealArchiveInOrganizer: true
            ),
            profileAction: .profileAction(
                configuration: "Release",
                executable: .init(stringLiteral: "ClaudeCode")
            )
        ),
        
        // MARK: - Testing Focused Scheme
        .scheme(
            name: "ClaudeCode-Tests",
            shared: true,
            buildAction: .buildAction(targets: [.init(stringLiteral: "ClaudeCode"), .init(stringLiteral: "ClaudeCodeTests")]),
            testAction: .targets(
                ["ClaudeCodeTests"],
                configuration: "Debug",
                options: .options(
                    language: .init("en"),
                    region: "US",
                    coverage: true,
                    codeCoverageTargets: [.init(stringLiteral: "ClaudeCode")]
                )
            )
        ),
        
        // MARK: - UI Testing Scheme
        .scheme(
            name: "ClaudeCode-UITests",
            shared: true,
            buildAction: .buildAction(targets: [.init(stringLiteral: "ClaudeCode"), .init(stringLiteral: "ClaudeCodeUITests")]),
            testAction: .targets(
                ["ClaudeCodeUITests"],
                configuration: "Debug",
                options: .options(
                    language: .init("en"),
                    region: "US",
                    coverage: false
                )
            ),
            runAction: .runAction(
                configuration: "Debug",
                executable: .init(stringLiteral: "ClaudeCode")
            )
        )
    ]
)
