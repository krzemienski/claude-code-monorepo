import ProjectDescription

// Main Tuist configuration for Claude Code iOS app
// This defines project-wide settings and generation options
let tuist = Tuist(
    fullHandle: "claudecode/ios",
    project: .xcode(
        warningOptions: .options(
            asWarnings: [],
            suppressWarnings: false,
            suppressWarningsFromPaths: []
        )
    )
)