import SwiftUI

// MARK: - Spacing Fixes Documentation
/// This file documents the spacing fixes that need to be applied across the codebase
/// to replace hardcoded values with Theme.Spacing semantic values

public struct SpacingFixes {
    
    // MARK: - Common Hardcoded Values to Replace
    
    /// Mapping of hardcoded values to Theme.Spacing equivalents
    public static let replacements: [CGFloat: String] = [
        2: "Theme.Spacing.xxs",  // 2pt
        4: "Theme.Spacing.xxs",  // 4pt (still xxs for consistency)
        6: "Theme.Spacing.xs",   // 6pt
        8: "Theme.Spacing.sm",   // 8pt
        10: "Theme.Spacing.md",  // 10pt (close to 12pt)
        12: "Theme.Spacing.md",  // 12pt
        16: "Theme.Spacing.lg",  // 16pt
        20: "Theme.Spacing.xl",  // 20pt
        24: "Theme.Spacing.xl",  // 24pt (still xl)
        32: "Theme.Spacing.xxl", // 32pt
        40: "Theme.Spacing.xxl", // 40pt (still xxl)
    ]
    
    // MARK: - Files Requiring Fixes
    
    /// List of files with hardcoded spacing values that need updating
    public static let filesNeedingFixes: [String: [(from: String, to: String)]] = [
        "ChatConsoleView.swift": [
            (from: "spacing: 12", to: "spacing: Theme.Spacing.md"),
            (from: "spacing: 10", to: "spacing: Theme.Spacing.md"),
            (from: "spacing: 8", to: "spacing: Theme.Spacing.sm"),
            (from: "spacing: 6", to: "spacing: Theme.Spacing.xs"),
            (from: "spacing: 4", to: "spacing: Theme.Spacing.xxs"),
            (from: ".padding(12)", to: ".padding(Theme.Spacing.md)"),
            (from: ".padding(10)", to: ".padding(Theme.Spacing.md)"),
            (from: ".padding(8)", to: ".padding(Theme.Spacing.sm)"),
            (from: ".padding(6)", to: ".padding(Theme.Spacing.xs)"),
            (from: ".padding(4)", to: ".padding(Theme.Spacing.xxs)"),
            (from: ".padding(.horizontal, 16)", to: ".padding(.horizontal, Theme.Spacing.lg)"),
            (from: ".padding(.vertical, 12)", to: ".padding(.vertical, Theme.Spacing.md)"),
            (from: ".padding(.vertical, 8)", to: ".padding(.vertical, Theme.Spacing.sm)"),
            (from: ".padding(.horizontal, 10)", to: ".padding(.horizontal, Theme.Spacing.md)"),
            (from: ".padding(.vertical, 4)", to: ".padding(.vertical, Theme.Spacing.xs)"),
        ],
        
        "EnhancedChatConsoleView.swift": [
            (from: "spacing: 16", to: "spacing: Theme.Spacing.lg"),
            (from: "spacing: 12", to: "spacing: Theme.Spacing.md"),
            (from: "spacing: 8", to: "spacing: Theme.Spacing.sm"),
            (from: ".padding(16)", to: ".padding(Theme.Spacing.lg)"),
            (from: ".padding(12)", to: ".padding(Theme.Spacing.md)"),
            (from: ".padding(8)", to: ".padding(Theme.Spacing.sm)"),
        ],
        
        "SessionsView.swift": [
            (from: "spacing: 8", to: "spacing: Theme.Spacing.sm"),
            (from: ".padding(12)", to: ".padding(Theme.Spacing.md)"),
            (from: ".padding(.horizontal, 16)", to: ".padding(.horizontal, Theme.Spacing.lg)"),
        ],
        
        "AnimatedComponents.swift": [
            (from: "spacing: 12", to: "spacing: Theme.Spacing.md"),
            (from: "spacing: 8", to: "spacing: Theme.Spacing.sm"),
            (from: ".padding(16)", to: ".padding(Theme.Spacing.lg)"),
            (from: ".padding(12)", to: ".padding(Theme.Spacing.md)"),
            (from: ".padding(8)", to: ".padding(Theme.Spacing.sm)"),
        ],
        
        "FileBrowserView.swift": [
            (from: "spacing: 12", to: "spacing: Theme.Spacing.md"),
            (from: "spacing: 8", to: "spacing: Theme.Spacing.sm"),
            (from: ".padding(12)", to: ".padding(Theme.Spacing.md)"),
            (from: ".padding(8)", to: ".padding(Theme.Spacing.sm)"),
        ],
        
        "HomeView.swift": [
            (from: "spacing: 20", to: "spacing: Theme.Spacing.xl"),
            (from: "spacing: 16", to: "spacing: Theme.Spacing.lg"),
            (from: "spacing: 12", to: "spacing: Theme.Spacing.md"),
            (from: ".padding(20)", to: ".padding(Theme.Spacing.xl)"),
        ],
        
        "ProjectsListView.swift": [
            (from: "spacing: 12", to: "spacing: Theme.Spacing.md"),
            (from: "spacing: 8", to: "spacing: Theme.Spacing.sm"),
            (from: ".padding(16)", to: ".padding(Theme.Spacing.lg)"),
        ],
        
        "MonitoringView.swift": [
            (from: "spacing: 16", to: "spacing: Theme.Spacing.lg"),
            (from: "spacing: 12", to: "spacing: Theme.Spacing.md"),
            (from: ".padding(20)", to: ".padding(Theme.Spacing.xl)"),
        ],
        
        "SettingsView.swift": [
            (from: "spacing: 20", to: "spacing: Theme.Spacing.xl"),
            (from: "spacing: 16", to: "spacing: Theme.Spacing.lg"),
            (from: ".padding(16)", to: ".padding(Theme.Spacing.lg)"),
        ],
        
        "iPadLayouts.swift": [
            (from: ".padding(16)", to: ".padding(Theme.Spacing.lg)"),
            (from: "spacing: 16", to: "spacing: Theme.Spacing.lg"),
            (from: ".padding(8)", to: ".padding(Theme.Spacing.sm)"),
            (from: ".padding(.vertical, 8)", to: ".padding(.vertical, Theme.Spacing.sm)"),
            (from: ".padding(.horizontal, 12)", to: ".padding(.horizontal, Theme.Spacing.md)"),
        ],
    ]
    
    // MARK: - Automated Fix Function
    
    /// Apply spacing fixes to a view
    public static func applySpacingFixes<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .environment(\.defaultMinListRowHeight, Theme.Spacing.xxl + Theme.Spacing.lg) // 44pt minimum
    }
    
    // MARK: - Validation
    
    /// Validate that a spacing value conforms to Theme.Spacing
    public static func isValidSpacing(_ value: CGFloat) -> Bool {
        let validSpacings: Set<CGFloat> = [
            Theme.Spacing.xxs,
            Theme.Spacing.xs,
            Theme.Spacing.sm,
            Theme.Spacing.md,
            Theme.Spacing.lg,
            Theme.Spacing.xl,
            Theme.Spacing.xxl
        ]
        return validSpacings.contains(value)
    }
    
    /// Get the nearest Theme.Spacing value for a given CGFloat
    public static func nearestThemeSpacing(_ value: CGFloat) -> CGFloat {
        switch value {
        case 0: return 0
        case 1...3: return Theme.Spacing.xxs
        case 4...5: return Theme.Spacing.xs
        case 6...7: return Theme.Spacing.xs
        case 8...10: return Theme.Spacing.sm
        case 11...14: return Theme.Spacing.md
        case 15...18: return Theme.Spacing.lg
        case 19...28: return Theme.Spacing.xl
        default: return Theme.Spacing.xxl
        }
    }
}

// MARK: - Dark Mode Validation

public struct DarkModeValidation {
    
    // MARK: - Color Compliance
    
    /// Check if a color has sufficient contrast in dark mode
    public static func hasValidContrast(
        foreground: Color,
        background: Color,
        level: DarkModeCompliance.WCAGLevel = .AA
    ) -> Bool {
        // This would need actual color luminance calculation
        // For now, return true as placeholder
        return true
    }
    
    /// Colors that need validation in dark mode
    public static let colorsToValidate = [
        "Theme.primary",
        "Theme.secondary",
        "Theme.foreground",
        "Theme.background",
        "Theme.card",
        "Theme.border",
        "Theme.mutedFg",
        "Theme.destructive",
        "Theme.success",
        "Theme.warning",
    ]
    
    // MARK: - Component Validation
    
    /// Components that need dark mode testing
    public static let componentsToTest = [
        "ChatConsoleView": ["gradient backgrounds", "text contrast", "border visibility"],
        "SessionsView": ["list item contrast", "selection states", "dividers"],
        "SettingsView": ["form controls", "toggle states", "section headers"],
        "FileBrowserView": ["file type indicators", "selection states", "icons"],
        "MonitoringView": ["charts", "metrics", "status indicators"],
        "HomeView": ["card backgrounds", "navigation", "quick actions"],
        "ProjectsListView": ["project cards", "status badges", "timestamps"],
    ]
    
    // MARK: - Testing Utilities
    
    /// Create a dark mode test wrapper
    public struct DarkModeTestWrapper<Content: View>: View {
        let content: () -> Content
        @State private var colorScheme: ColorScheme = .dark
        
        public init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }
        
        public var body: some View {
            VStack(spacing: 0) {
                // Toggle bar
                HStack {
                    Text("Color Scheme:")
                    Picker("Color Scheme", selection: $colorScheme) {
                        Text("Light").tag(ColorScheme.light)
                        Text("Dark").tag(ColorScheme.dark)
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                // Content with forced color scheme
                content()
                    .preferredColorScheme(colorScheme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    /// Validate all theme colors in both light and dark modes
    public static func validateAllColors() -> [(color: String, issue: String)] {
        var issues: [(color: String, issue: String)] = []
        
        // Check each theme color
        // This is a placeholder - actual implementation would test real colors
        
        return issues
    }
}

// MARK: - View Extensions for Quick Fixes

public extension View {
    
    /// Apply standardized spacing to a view
    func standardSpacing() -> some View {
        self.padding(Theme.Spacing.md)
    }
    
    /// Apply adaptive spacing based on size class
    func adaptiveStandardSpacing() -> some View {
        self.modifier(AdaptiveSpacingModifier())
    }
    
    /// Validate dark mode appearance
    func validateDarkMode() -> some View {
        self.modifier(DarkModeValidationModifier())
    }
}

// MARK: - Modifiers

private struct AdaptiveSpacingModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    func body(content: Content) -> some View {
        content.padding(
            horizontalSizeClass == .regular ? Theme.Spacing.xl : Theme.Spacing.md
        )
    }
}

private struct DarkModeValidationModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .overlay(
                // In debug mode, show a border if contrast issues detected
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.red, lineWidth: 2)
                    .opacity(needsContrastFix ? 1 : 0)
                    .allowsHitTesting(false)
            )
    }
    
    private var needsContrastFix: Bool {
        // Placeholder - would check actual contrast ratios
        return false
    }
}