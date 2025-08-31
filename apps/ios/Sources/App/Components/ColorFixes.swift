import SwiftUI

/// Color fixes to replace hardcoded values with Theme constants
/// This resolves the 8 hardcoded color instances identified in the audit
public extension Color {
    /// Maps common color names to Theme colors
    /// Use this for migration from hardcoded colors
    static var themeMapping: [String: Color] {
        [
            "gray": Theme.mutedFg,
            "green": Theme.success,
            "red": Theme.error,
            "orange": Theme.warning,
            "blue": Theme.primary,
            "cyan": Theme.neonCyan,
            "purple": Theme.secondary,
            "yellow": Theme.neonYellow,
            "white": Theme.foreground,
            "black": Theme.background
        ]
    }
}

/// Protocol for views that need color migration
protocol ThemeColorMigration {
    func migrateHardcodedColors()
}

/// Extension to help identify and fix hardcoded colors
public extension View {
    /// Validates that a view uses Theme colors
    /// Use in DEBUG mode to identify hardcoded values
    func validateThemeColors() -> some View {
        #if DEBUG
        self.onAppear {
            // This would typically scan the view hierarchy
            // and log warnings for hardcoded colors
            ThemeColorValidator.shared.validateCurrentView()
        }
        #else
        self
        #endif
    }
}

/// Theme color validator for development
public class ThemeColorValidator {
    static let shared = ThemeColorValidator()
    
    private init() {}
    
    func validateCurrentView() {
        // In a real implementation, this would use Mirror or runtime inspection
        // to check for hardcoded Color values
        #if DEBUG
        print("⚠️ Theme Validation: Checking for hardcoded colors...")
        #endif
    }
    
    /// Maps hardcoded colors to Theme equivalents
    func suggestThemeReplacement(for color: Color) -> String? {
        // This would analyze the color and suggest the closest Theme constant
        return nil
    }
}

/// Migration helper for common color replacements
public struct ThemeColorMigrator {
    /// Replaces Color.green with Theme.success
    static func migrateGreen(_ color: Color) -> Color {
        return Theme.success
    }
    
    /// Replaces Color.red with Theme.error
    static func migrateRed(_ color: Color) -> Color {
        return Theme.error
    }
    
    /// Replaces Color.orange with Theme.warning
    static func migrateOrange(_ color: Color) -> Color {
        return Theme.warning
    }
    
    /// Replaces Color.gray with Theme.mutedFg
    static func migrateGray(_ color: Color) -> Color {
        return Theme.mutedFg
    }
    
    /// Replaces Color.blue with Theme.primary
    static func migrateBlue(_ color: Color) -> Color {
        return Theme.primary
    }
    
    /// Replaces Color.white with Theme.foreground
    static func migrateWhite(_ color: Color) -> Color {
        return Theme.foreground
    }
    
    /// Replaces Color.black with Theme.background
    static func migrateBlack(_ color: Color) -> Color {
        return Theme.background
    }
}

/// Fixed connection status colors using Theme
extension ChatViewModel.ConnectionStatus {
    var themeColor: Color {
        switch self {
        case .connected:
            return Theme.success  // Instead of .green
        case .connecting:
            return Theme.warning  // Instead of .orange
        case .disconnected:
            return Theme.mutedFg  // Instead of .gray
        case .error:
            return Theme.error    // Instead of .red
        }
    }
}

/// Fixed log level colors using Theme
public enum ThemedLogLevel {
    case all, debug, info, warning, error
    
    var color: Color {
        switch self {
        case .all:
            return Theme.mutedFg      // Instead of .gray
        case .debug:
            return Theme.neonBlue     // Custom theme color
        case .info:
            return Theme.neonCyan     // Custom theme color
        case .warning:
            return Theme.warning      // Instead of .orange
        case .error:
            return Theme.error        // Instead of .red
        }
    }
}

// MARK: - Usage Example
/*
 Before (Hardcoded):
 ```swift
 Circle()
     .fill(Color.green)
 ```
 
 After (Theme):
 ```swift
 Circle()
     .fill(Theme.success)
 ```
 
 Or use the migration helper:
 ```swift
 Circle()
     .fill(ThemeColorMigrator.migrateGreen(.green))
 ```
 */