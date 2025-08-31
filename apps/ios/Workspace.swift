import ProjectDescription

// MARK: - Workspace Configuration
let workspace = Workspace(
    name: "ClaudeCode",
    projects: [
        ".",
        // Future modules will be added here:
        // "Modules/Core",
        // "Modules/Networking", 
        // "Modules/UI",
        // "Modules/Analytics"
    ],
    schemes: [
        // MARK: - Development Workspace Scheme
        .scheme(
            name: "ClaudeCode-Dev",
            shared: true,
            buildAction: .buildAction(
                targets: [
                    .project(path: ".", target: "ClaudeCode")
                ]
            ),
            testAction: .targets(
                [
                    .testableTarget(target: .project(path: ".", target: "ClaudeCodeTests"))
                ],
                configuration: "Debug",
                options: .options(
                    language: .init("en"),
                    region: "US",
                    coverage: true,
                    codeCoverageTargets: [
                        .project(path: ".", target: "ClaudeCode")
                    ]
                )
            ),
            runAction: .runAction(
                configuration: "Debug",
                executable: .project(path: ".", target: "ClaudeCode"),
                arguments: .arguments(
                    environmentVariables: [
                        "CLAUDE_CODE_ENV": "development",
                        "CLAUDE_CODE_DEBUG": "1",
                        "CLAUDE_CODE_LOG_LEVEL": "debug",
                        "CLAUDE_CODE_API_HOST": "localhost:3000",
                        "CLAUDE_CODE_ENABLE_LOGGING": "1",
                        "CLAUDE_CODE_MOCK_NETWORK": "0"
                    ]
                )
            ),
            profileAction: .profileAction(
                configuration: "Debug",
                executable: .project(path: ".", target: "ClaudeCode")
            )
        ),
        
        // MARK: - Performance Profiling Workspace Scheme
        .scheme(
            name: "ClaudeCode-Performance",
            shared: true,
            buildAction: .buildAction(
                targets: [
                    .project(path: ".", target: "ClaudeCode")
                ]
            ),
            testAction: .targets(
                [
                    .testableTarget(target: .project(path: ".", target: "ClaudeCodeTests"))
                ],
                configuration: "Release",
                options: .options(
                    language: .init("en"),
                    region: "US",
                    coverage: false
                )
            ),
            runAction: .runAction(
                configuration: "Release",
                executable: .project(path: ".", target: "ClaudeCode"),
                arguments: .arguments(
                    environmentVariables: [
                        "CLAUDE_CODE_ENV": "performance",
                        "CLAUDE_CODE_DEBUG": "0",
                        "CLAUDE_CODE_LOG_LEVEL": "error",
                        "CLAUDE_CODE_PERFORMANCE_MONITORING": "1",
                        "CLAUDE_CODE_METRICS_ENABLED": "1"
                    ]
                )
            ),
            profileAction: .profileAction(
                configuration: "Release",
                executable: .project(path: ".", target: "ClaudeCode")
            )
        ),
        
        // MARK: - Complete Build Workspace Scheme
        .scheme(
            name: "ClaudeCode-All",
            shared: true,
            buildAction: .buildAction(
                targets: [
                    .project(path: ".", target: "ClaudeCode"),
                    .project(path: ".", target: "ClaudeCodeTests"),
                    .project(path: ".", target: "ClaudeCodeUITests")
                ]
            ),
            testAction: .targets(
                [
                    .testableTarget(target: .project(path: ".", target: "ClaudeCodeTests")),
                    .testableTarget(target: .project(path: ".", target: "ClaudeCodeUITests"))
                ],
                configuration: "Debug",
                options: .options(
                    language: .init("en"),
                    region: "US",
                    coverage: true,
                    codeCoverageTargets: [
                        .project(path: ".", target: "ClaudeCode")
                    ]
                )
            ),
            runAction: .runAction(
                configuration: "Debug",
                executable: .project(path: ".", target: "ClaudeCode"),
                arguments: .arguments(
                    environmentVariables: [
                        "CLAUDE_CODE_ENV": "testing",
                        "CLAUDE_CODE_DEBUG": "1",
                        "CLAUDE_CODE_LOG_LEVEL": "info",
                        "CLAUDE_CODE_TEST_MODE": "1"
                    ]
                )
            ),
            archiveAction: .archiveAction(
                configuration: "Release",
                revealArchiveInOrganizer: true
            )
        )
    ],
    fileHeaderTemplate: .string(
        """
        //
        // {{file}}.swift
        // ClaudeCode
        //
        // Created on {{date}}.
        // Copyright © {{year}} Claude Code. All rights reserved.
        //
        """
    ),
    additionalFiles: [
        .glob(pattern: "*.md"),
        .glob(pattern: "docs/**"),
        .glob(pattern: "scripts/**"),
        .glob(pattern: ".tuist-version"),
        .glob(pattern: ".gitignore")
    ]
)