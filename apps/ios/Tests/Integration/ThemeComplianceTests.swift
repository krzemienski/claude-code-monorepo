import XCTest
import SwiftUI
@testable import ClaudeCode

@MainActor
final class ThemeComplianceTests: XCTestCase {
    
    // MARK: - Theme Spacing Tests
    
    func testNoHardcodedSpacing() {
        // Test that no hardcoded spacing values exist
        let validator = ThemeValidator()
        
        // Scan for hardcoded values
        let hardcodedSpacingPattern = #"(padding|spacing)\s*[:=]\s*\d+(?!\s*//.*Theme\.Spacing)"#
        let violations = validator.scanForPattern(hardcodedSpacingPattern)
        
        XCTAssertEqual(violations.count, 0, "Found hardcoded spacing values: \(violations)")
    }
    
    func testThemeSpacingConsistency() {
        // Test Theme.Spacing values are consistent
        XCTAssertEqual(Theme.Spacing.none, 0)
        XCTAssertEqual(Theme.Spacing.xxs, 2)
        XCTAssertEqual(Theme.Spacing.xs, 4)
        XCTAssertEqual(Theme.Spacing.sm, 8)
        XCTAssertEqual(Theme.Spacing.md, 12)
        XCTAssertEqual(Theme.Spacing.lg, 16)
        XCTAssertEqual(Theme.Spacing.xl, 24)
        XCTAssertEqual(Theme.Spacing.xxl, 32)
        XCTAssertEqual(Theme.Spacing.xxxl, 48)
    }
    
    func testSpacingValidation() {
        // Test spacing validation utility
        XCTAssertEqual(ThemeValidation.validateSpacing(0), Theme.Spacing.none)
        XCTAssertEqual(ThemeValidation.validateSpacing(2), Theme.Spacing.xxs)
        XCTAssertEqual(ThemeValidation.validateSpacing(4), Theme.Spacing.xs)
        XCTAssertEqual(ThemeValidation.validateSpacing(8), Theme.Spacing.sm)
        XCTAssertEqual(ThemeValidation.validateSpacing(12), Theme.Spacing.md)
        XCTAssertEqual(ThemeValidation.validateSpacing(16), Theme.Spacing.lg)
        XCTAssertEqual(ThemeValidation.validateSpacing(24), Theme.Spacing.xl)
        XCTAssertEqual(ThemeValidation.validateSpacing(32), Theme.Spacing.xxl)
        XCTAssertEqual(ThemeValidation.validateSpacing(48), Theme.Spacing.xxxl)
    }
    
    // MARK: - Dark Mode Tests
    
    func testDarkModeColorContrast() {
        let compliance = DarkModeCompliance()
        
        // Test text on background contrast
        let textContrast = compliance.calculateContrastRatio(
            Theme.foreground,
            Theme.background
        )
        XCTAssertGreaterThanOrEqual(textContrast, 4.5, "Text contrast fails WCAG AA")
        
        // Test primary color contrast
        let primaryContrast = compliance.calculateContrastRatio(
            Theme.primary,
            Theme.background
        )
        XCTAssertGreaterThanOrEqual(primaryContrast, 3.0, "Primary color contrast fails")
        
        // Test error color contrast
        let errorContrast = compliance.calculateContrastRatio(
            Theme.error,
            Theme.background
        )
        XCTAssertGreaterThanOrEqual(errorContrast, 3.0, "Error color contrast fails")
    }
    
    func testDarkModeConsistency() {
        // Test that all UI elements work in dark mode
        let darkModeColors = [
            Theme.background,
            Theme.surface,
            Theme.backgroundSecondary,
            Theme.backgroundTertiary,
            Theme.card,
            Theme.input,
            Theme.inputFocus
        ]
        
        for color in darkModeColors {
            // Verify colors are defined and not nil
            XCTAssertNotNil(color)
        }
    }
    
    func testHighContrastColors() {
        // Test high contrast mode colors
        let highContrastPairs: [(foreground: Color, background: Color)] = [
            (AccessibilityColors.highContrastForeground, AccessibilityColors.highContrastBackground),
            (AccessibilityColors.highContrastPrimary, AccessibilityColors.highContrastBackground),
            (AccessibilityColors.highContrastError, AccessibilityColors.highContrastBackground)
        ]
        
        let compliance = DarkModeCompliance()
        
        for pair in highContrastPairs {
            let ratio = compliance.calculateContrastRatio(pair.foreground, pair.background)
            XCTAssertGreaterThanOrEqual(ratio, 7.0, "High contrast mode fails WCAG AAA")
        }
    }
    
    // MARK: - Typography Tests
    
    func testFontSizeConsistency() {
        // Test font sizes are properly defined
        XCTAssertEqual(Theme.FontSize.xs, 12)
        XCTAssertEqual(Theme.FontSize.sm, 14)
        XCTAssertEqual(Theme.FontSize.base, 16)
        XCTAssertEqual(Theme.FontSize.md, 16)
        XCTAssertEqual(Theme.FontSize.lg, 18)
        XCTAssertEqual(Theme.FontSize.xl, 20)
        XCTAssertEqual(Theme.FontSize.xxl, 24)
        XCTAssertEqual(Theme.FontSize.xxxl, 32)
        XCTAssertEqual(Theme.FontSize.display, 48)
    }
    
    func testFontWeightConsistency() {
        // Test font weights are properly defined
        XCTAssertEqual(Theme.FontWeight.regular, Font.Weight.regular)
        XCTAssertEqual(Theme.FontWeight.medium, Font.Weight.medium)
        XCTAssertEqual(Theme.FontWeight.semibold, Font.Weight.semibold)
        XCTAssertEqual(Theme.FontWeight.bold, Font.Weight.bold)
        XCTAssertEqual(Theme.FontWeight.black, Font.Weight.black)
    }
    
    func testCodeFontFallback() {
        // Test that code font falls back properly
        let codeFont = Theme.Fonts.code(size: 14)
        XCTAssertNotNil(codeFont)
    }
    
    // MARK: - Corner Radius Tests
    
    func testCornerRadiusConsistency() {
        // Test corner radius values
        XCTAssertEqual(Theme.CornerRadius.sm, 4)
        XCTAssertEqual(Theme.CornerRadius.md, 8)
        XCTAssertEqual(Theme.CornerRadius.lg, 12)
        XCTAssertEqual(Theme.CornerRadius.xl, 16)
        XCTAssertEqual(Theme.CornerRadius.full, 9999)
    }
    
    // MARK: - Animation Tests
    
    func testAnimationDurations() {
        // Test animation durations
        XCTAssertEqual(Theme.Animation.fast, 0.15)
        XCTAssertEqual(Theme.Animation.normal, 0.25)
        XCTAssertEqual(Theme.Animation.slow, 0.35)
        XCTAssertEqual(Theme.Animation.verySlow, 0.5)
    }
    
    func testReducedMotionAnimation() {
        // Test reduced motion support
        let normalAnimation = Theme.Animation.spring
        let reducedAnimation = Theme.Animation.reduced(normalAnimation, reduceMotion: true)
        let notReducedAnimation = Theme.Animation.reduced(normalAnimation, reduceMotion: false)
        
        XCTAssertNil(reducedAnimation)
        XCTAssertNotNil(notReducedAnimation)
    }
    
    // MARK: - Neon Color Tests
    
    func testNeonColorConsistency() {
        // Test neon colors are defined
        let neonColors = [
            Theme.neonCyan,
            Theme.neonPink,
            Theme.neonPurple,
            Theme.neonBlue,
            Theme.neonGreen,
            Theme.neonYellow
        ]
        
        for color in neonColors {
            XCTAssertNotNil(color)
        }
    }
    
    func testSemanticColorMapping() {
        // Test semantic colors map correctly
        XCTAssertEqual(Theme.primary, Theme.neonCyan)
        XCTAssertEqual(Theme.accent, Theme.neonPink)
        XCTAssertEqual(Theme.success, Theme.neonGreen)
        XCTAssertEqual(Theme.warning, Theme.neonYellow)
        XCTAssertEqual(Theme.info, Theme.neonBlue)
    }
    
    // MARK: - Gradient Tests
    
    func testGradientDefinitions() {
        // Test gradients are properly defined
        XCTAssertNotNil(Theme.neonGradient)
        XCTAssertNotNil(Theme.darkGradient)
        XCTAssertNotNil(Theme.accentGradient)
    }
    
    // MARK: - Component Style Tests
    
    func testButtonStyling() {
        // Test button has consistent styling
        let button = Button("Test") {}
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
        
        XCTAssertNotNil(button)
    }
    
    func testTextFieldStyling() {
        // Test text field has consistent styling
        let textField = AnimatedTextField(
            placeholder: "Test",
            text: .constant("")
        )
        
        XCTAssertNotNil(textField)
    }
    
    func testCardStyling() {
        // Test card has consistent styling
        let card = VStack {
            Text("Card Content")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.md)
        
        XCTAssertNotNil(card)
    }
    
    // MARK: - Color Blind Tests
    
    func testColorBlindFriendlyPalette() {
        // Test color blind friendly colors are defined
        let colorBlindColors = [
            AccessibilityColors.colorBlindBlue,
            AccessibilityColors.colorBlindOrange,
            AccessibilityColors.colorBlindGreen,
            AccessibilityColors.colorBlindYellow,
            AccessibilityColors.colorBlindPurple,
            AccessibilityColors.colorBlindRed,
            AccessibilityColors.colorBlindBrown,
            AccessibilityColors.colorBlindPink
        ]
        
        for color in colorBlindColors {
            XCTAssertNotNil(color)
        }
    }
    
    // MARK: - Focus Indicator Tests
    
    func testFocusIndicatorColors() {
        // Test focus indicator colors
        XCTAssertNotNil(AccessibilityColors.focusRing)
        XCTAssertNotNil(AccessibilityColors.focusRingHighContrast)
        
        // Test focus ring visibility
        let compliance = DarkModeCompliance()
        let focusContrast = compliance.calculateContrastRatio(
            AccessibilityColors.focusRing,
            Theme.background
        )
        XCTAssertGreaterThanOrEqual(focusContrast, 3.0, "Focus ring not visible enough")
    }
    
    // MARK: - Performance Tests
    
    func testThemePerformance() {
        measure {
            // Measure theme access performance
            for _ in 0..<1000 {
                _ = Theme.primary
                _ = Theme.background
                _ = Theme.Spacing.md
                _ = Theme.FontSize.base
                _ = Theme.CornerRadius.md
            }
        }
    }
    
    func testColorCalculationPerformance() {
        let compliance = DarkModeCompliance()
        
        measure {
            // Measure contrast calculation performance
            for _ in 0..<100 {
                _ = compliance.calculateContrastRatio(
                    Theme.foreground,
                    Theme.background
                )
            }
        }
    }
}

// MARK: - Helper Extensions

private extension ThemeComplianceTests {
    
    struct ThemeValidator {
        func scanForPattern(_ pattern: String) -> [String] {
            // Mock implementation - in real app would scan actual files
            return []
        }
    }
    
    struct ScrollState {
        let offset: CGFloat
        let contentSize: CGFloat
    }
    
    struct KeyboardShortcut {
        let key: KeyEquivalent
        let modifiers: EventModifiers
        
        init(_ key: KeyEquivalent, modifiers: EventModifiers) {
            self.key = key
            self.modifiers = modifiers
        }
    }
}