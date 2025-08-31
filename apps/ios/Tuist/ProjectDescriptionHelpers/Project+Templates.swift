import ProjectDescription

// MARK: - Project Templates Extension
public extension Project {
    
    /// Creates a framework project with standard configuration
    /// - Parameters:
    ///   - name: The name of the framework
    ///   - bundleId: The bundle identifier for the framework
    ///   - dependencies: External and internal dependencies
    ///   - testDependencies: Dependencies for the test target
    /// - Returns: A configured Project for a framework
    static func framework(
        name: String,
        bundleId: String = "com.claudecode.ios",
        dependencies: [TargetDependency] = [],
        testDependencies: [TargetDependency] = []
    ) -> Project {
        return Project(
            name: name,
            organizationName: "Claude Code",
            settings: .frameworkSettings(),
            targets: [
                .target(
                    name: name,
                    destinations: [.iPhone, .iPad],
                    product: .framework,
                    bundleId: "\(bundleId).\(name.lowercased())",
                    deploymentTargets: .iOS("16.0"),
                    infoPlist: .default,
                    sources: [
                        .glob("Sources/**", excluding: ["**/*.md", "**/*.txt"])
                    ],
                    resources: [
                        .glob(pattern: "Sources/Resources/**", excluding: ["**/.DS_Store"])
                    ],
                    dependencies: dependencies,
                    settings: .frameworkTargetSettings()
                ),
                .target(
                    name: "\(name)Tests",
                    destinations: [.iPhone, .iPad],
                    product: .unitTests,
                    bundleId: "\(bundleId).\(name.lowercased()).tests",
                    deploymentTargets: .iOS("16.0"),
                    infoPlist: .default,
                    sources: [
                        .glob("Tests/**", excluding: ["**/*.md", "**/*.txt"])
                    ],
                    dependencies: [
                        .target(name: name)
                    ] + testDependencies,
                    settings: .testTargetSettings()
                )
            ],
            schemes: [
                .scheme(
                    name: name,
                    shared: true,
                    buildAction: .buildAction(targets: [.init(stringLiteral: name)]),
                    testAction: .targets(
                        ["\(name)Tests"],
                        configuration: "Debug",
                        options: .options(
                            language: .init("en"),
                            region: "US",
                            coverage: true,
                            codeCoverageTargets: [.init(stringLiteral: name)]
                        )
                    )
                )
            ]
        )
    }
    
    /// Creates a feature module project with app and test targets
    /// - Parameters:
    ///   - name: The name of the feature module
    ///   - bundleId: The bundle identifier base
    ///   - coreDependencies: Core framework dependencies
    ///   - externalDependencies: External package dependencies
    /// - Returns: A configured Project for a feature module
    static func featureModule(
        name: String,
        bundleId: String = "com.claudecode.ios",
        coreDependencies: [TargetDependency] = [],
        externalDependencies: [TargetDependency] = []
    ) -> Project {
        let allDependencies = coreDependencies + externalDependencies
        
        return Project(
            name: name,
            organizationName: "Claude Code",
            settings: .featureSettings(),
            targets: [
                .target(
                    name: name,
                    destinations: [.iPhone, .iPad],
                    product: .staticLibrary,
                    bundleId: "\(bundleId).feature.\(name.lowercased())",
                    deploymentTargets: .iOS("16.0"),
                    infoPlist: .default,
                    sources: [
                        .glob("Sources/**", excluding: ["**/*.md", "**/*.txt"])
                    ],
                    resources: [
                        .glob(pattern: "Sources/Resources/**", excluding: ["**/.DS_Store"]),
                        .glob(pattern: "Sources/**/*.storyboard"),
                        .glob(pattern: "Sources/**/*.xib")
                    ],
                    dependencies: allDependencies,
                    settings: .featureTargetSettings()
                ),
                .target(
                    name: "\(name)Tests",
                    destinations: [.iPhone, .iPad],
                    product: .unitTests,
                    bundleId: "\(bundleId).feature.\(name.lowercased()).tests",
                    deploymentTargets: .iOS("16.0"),
                    infoPlist: .default,
                    sources: [
                        .glob("Tests/**", excluding: ["**/*.md", "**/*.txt"])
                    ],
                    dependencies: [
                        .target(name: name),
                        .external(name: "ViewInspector", condition: .none)
                    ],
                    settings: .testTargetSettings()
                )
            ],
            schemes: [
                .scheme(
                    name: "\(name)-Feature",
                    shared: true,
                    buildAction: .buildAction(targets: [.init(stringLiteral: name)]),
                    testAction: .targets(
                        ["\(name)Tests"],
                        configuration: "Debug",
                        options: .options(
                            language: .init("en"),
                            region: "US",
                            coverage: true,
                            codeCoverageTargets: [.init(stringLiteral: name)]
                        )
                    )
                )
            ]
        )
    }
    
    /// Creates an example app project for demonstrating framework usage
    /// - Parameters:
    ///   - name: The name of the example app
    ///   - frameworkDependencies: Framework targets to depend on
    /// - Returns: A configured Project for an example app
    static func exampleApp(
        name: String,
        frameworkDependencies: [TargetDependency] = []
    ) -> Project {
        return Project(
            name: name,
            organizationName: "Claude Code",
            settings: .exampleAppSettings(),
            targets: [
                .target(
                    name: name,
                    destinations: [.iPhone, .iPad],
                    product: .app,
                    bundleId: "com.claudecode.ios.example.\(name.lowercased())",
                    deploymentTargets: .iOS("16.0"),
                    infoPlist: .exampleAppInfoPlist(),
                    sources: [
                        .glob("Sources/**", excluding: ["**/*.md", "**/*.txt"])
                    ],
                    resources: [
                        .glob(pattern: "Sources/Resources/**", excluding: ["**/.DS_Store"])
                    ],
                    dependencies: frameworkDependencies,
                    settings: .exampleAppTargetSettings()
                )
            ],
            schemes: [
                .scheme(
                    name: name,
                    shared: true,
                    buildAction: .buildAction(targets: [.init(stringLiteral: name)]),
                    runAction: .runAction(
                        configuration: "Debug",
                        executable: .init(stringLiteral: name),
                        arguments: .arguments(
                            environmentVariables: [
                                "CLAUDE_CODE_ENV": "example",
                                "CLAUDE_CODE_DEBUG": "1"
                            ]
                        )
                    )
                )
            ]
        )
    }
}

// MARK: - Settings Extensions
public extension Settings {
    
    /// Standard settings for framework projects
    static func frameworkSettings() -> Settings {
        return .settings(
            base: [
                "SWIFT_VERSION": "5.10",
                "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
                "SUPPORTS_MACCATALYST": "YES",
                "ENABLE_PREVIEWS": "YES",
                "DEVELOPMENT_LANGUAGE": "en",
                "DEFINES_MODULE": "YES",
                "DYLIB_COMPATIBILITY_VERSION": "1",
                "DYLIB_CURRENT_VERSION": "1",
                "DYLIB_INSTALL_NAME_BASE": "@rpath",
                "INSTALL_PATH": "$(LOCAL_LIBRARY_DIR)/Frameworks",
                "SKIP_INSTALL": "YES"
            ],
            configurations: [
                .debug(name: "Debug", settings: debugSettings()),
                .release(name: "Release", settings: releaseSettings())
            ]
        )
    }
    
    /// Standard settings for feature module projects
    static func featureSettings() -> Settings {
        return .settings(
            base: [
                "SWIFT_VERSION": "5.10",
                "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
                "SUPPORTS_MACCATALYST": "YES",
                "ENABLE_PREVIEWS": "YES",
                "DEVELOPMENT_LANGUAGE": "en",
                "DEFINES_MODULE": "YES"
            ],
            configurations: [
                .debug(name: "Debug", settings: debugSettings()),
                .release(name: "Release", settings: releaseSettings())
            ]
        )
    }
    
    /// Settings for example app projects
    static func exampleAppSettings() -> Settings {
        return .settings(
            base: [
                "SWIFT_VERSION": "5.10",
                "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
                "SUPPORTS_MACCATALYST": "YES",
                "ENABLE_PREVIEWS": "YES",
                "DEVELOPMENT_LANGUAGE": "en",
                "GENERATE_INFOPLIST_FILE": "YES"
            ],
            configurations: [
                .debug(name: "Debug", settings: debugSettings()),
                .release(name: "Release", settings: releaseSettings())
            ]
        )
    }
    
    /// Target-specific settings for frameworks
    static func frameworkTargetSettings() -> Settings {
        return .settings(
            base: [
                "PRODUCT_NAME": "$(TARGET_NAME)",
                "SWIFT_EMIT_LOC_STRINGS": "YES",
                "CODE_SIGN_STYLE": "Automatic",
                "DEVELOPMENT_TEAM": "",
                "PROVISIONING_PROFILE_SPECIFIER": ""
            ]
        )
    }
    
    /// Target-specific settings for feature modules
    static func featureTargetSettings() -> Settings {
        return .settings(
            base: [
                "PRODUCT_NAME": "$(TARGET_NAME)",
                "SWIFT_EMIT_LOC_STRINGS": "YES"
            ]
        )
    }
    
    /// Target-specific settings for example apps
    static func exampleAppTargetSettings() -> Settings {
        return .settings(
            base: [
                "PRODUCT_NAME": "$(TARGET_NAME)",
                "SWIFT_EMIT_LOC_STRINGS": "YES",
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                "CODE_SIGN_STYLE": "Automatic",
                "DEVELOPMENT_TEAM": "",
                "PROVISIONING_PROFILE_SPECIFIER": ""
            ]
        )
    }
    
    /// Target-specific settings for test targets
    static func testTargetSettings() -> Settings {
        return .settings(
            base: [
                "PRODUCT_NAME": "$(TARGET_NAME)",
                "SWIFT_EMIT_LOC_STRINGS": "NO",
                "BUNDLE_LOADER": "$(TEST_HOST)",
                "ENABLE_TESTING_SEARCH_PATHS": "YES"
            ]
        )
    }
    
    /// Common debug build settings
    private static func debugSettings() -> [String: SettingValue] {
        return [
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
            "SWIFT_COMPILATION_MODE": "singlefile",
            "ENABLE_TESTABILITY": "YES",
            "DEBUG_INFORMATION_FORMAT": "dwarf",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
            "GCC_OPTIMIZATION_LEVEL": "0",
            "ONLY_ACTIVE_ARCH": "YES",
            "COPY_PHASE_STRIP": "NO",
            "OTHER_SWIFT_FLAGS": "-DDEBUG -enable-testing"
        ]
    }
    
    /// Common release build settings
    private static func releaseSettings() -> [String: SettingValue] {
        return [
            "SWIFT_OPTIMIZATION_LEVEL": "-O",
            "SWIFT_COMPILATION_MODE": "wholemodule",
            "ENABLE_TESTABILITY": "NO",
            "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
            "VALIDATE_PRODUCT": "YES",
            "GCC_OPTIMIZATION_LEVEL": "s",
            "COPY_PHASE_STRIP": "YES",
            "OTHER_SWIFT_FLAGS": "-DRELEASE"
        ]
    }
}

// MARK: - InfoPlist Extensions
public extension InfoPlist {
    
    /// Standard InfoPlist for example apps
    static func exampleAppInfoPlist() -> InfoPlist {
        return .extendingDefault(with: [
            "CFBundleDisplayName": "$(PRODUCT_NAME)",
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": "1",
            "UILaunchScreen": [
                "UIColorName": "AccentColor"
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
            "UIApplicationSceneManifest": [
                "UIApplicationSupportsMultipleScenes": true,
                "UISceneConfigurations": [:]
            ]
        ])
    }
}

// MARK: - Scheme Generation Helpers
public extension Scheme {
    
    /// Creates a comprehensive testing scheme for modules
    /// - Parameters:
    ///   - name: Scheme name
    ///   - targets: Build targets
    ///   - testTargets: Test targets
    /// - Returns: Configured scheme
    static func testingScheme(
        name: String,
        targets: [String],
        testTargets: [String]
    ) -> Scheme {
        return .scheme(
            name: "\(name)-Testing",
            shared: true,
            buildAction: .buildAction(targets: targets.map { TargetReference.init(stringLiteral: $0) }),
            testAction: .targets(
                testTargets.map { TestableTarget.init(stringLiteral: $0) },
                configuration: "Debug",
                options: .options(
                    language: .init("en"),
                    region: "US",
                    coverage: true,
                    codeCoverageTargets: targets.map { TargetReference.init(stringLiteral: $0) }
                )
            )
        )
    }
    
    /// Creates a performance profiling scheme
    /// - Parameters:
    ///   - name: Scheme name
    ///   - target: Main target for profiling
    /// - Returns: Configured profiling scheme
    static func profilingScheme(
        name: String,
        target: String
    ) -> Scheme {
        return .scheme(
            name: "\(name)-Performance",
            shared: true,
            buildAction: .buildAction(targets: [.init(stringLiteral: target)]),
            runAction: .runAction(
                configuration: "Release",
                executable: .init(stringLiteral: target),
                arguments: .arguments(
                    environmentVariables: [
                        "CLAUDE_CODE_ENV": "performance",
                        "CLAUDE_CODE_DEBUG": "0",
                        "CLAUDE_CODE_PERFORMANCE_MONITORING": "1"
                    ]
                )
            ),
            profileAction: .profileAction(
                configuration: "Release",
                executable: .init(stringLiteral: target)
            )
        )
    }
}