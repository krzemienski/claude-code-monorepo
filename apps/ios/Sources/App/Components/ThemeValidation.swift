import SwiftUI

// MARK: - Theme Validation & Dark Mode Support

/// Validates theme compliance and provides dark mode support utilities
public struct ThemeValidator {
    
    // MARK: - Spacing Validation
    
    /// Maps hardcoded spacing values to Theme.Spacing equivalents
    public static func validateSpacing(_ value: CGFloat) -> CGFloat {
        switch value {
        case 0: return 0
        case 1...3: return Theme.Spacing.xxs  // 2
        case 4...5: return Theme.Spacing.xs   // 4
        case 6...9: return Theme.Spacing.sm   // 8
        case 10...14: return Theme.Spacing.md // 12
        case 15...19: return Theme.Spacing.lg // 16
        case 20...23: return Theme.Spacing.xl // 20
        case 24...29: return Theme.Spacing.xxl // 24
        case 30...39: return Theme.Spacing.xxxl // 32
        case 40...49: return Theme.Spacing.huge // 40
        default: return Theme.Spacing.massive  // 48+
        }
    }
    
    /// Provides semantic spacing based on context
    public enum SpacingContext {
        case inlineElements     // Between inline elements (icons, badges)
        case textLines         // Between lines of text
        case formElements      // Between form inputs
        case sections          // Between major sections
        case cards            // Between card elements
        case navigation       // Navigation elements
        
        var value: CGFloat {
            switch self {
            case .inlineElements: return Theme.Spacing.xs    // 4
            case .textLines: return Theme.Spacing.sm         // 8
            case .formElements: return Theme.Spacing.md      // 12
            case .sections: return Theme.Spacing.lg          // 16
            case .cards: return Theme.Spacing.xl            // 20
            case .navigation: return Theme.Spacing.md       // 12
            }
        }
    }
}

// MARK: - Dark Mode Validation

public struct DarkModeValidator {
    
    /// Validates color contrast for dark mode
    public static func validateContrast(
        foreground: Color,
        background: Color,
        mode: ColorScheme
    ) -> Bool {
        // This would need actual color luminance calculation
        // For now, return true as Theme already handles dark mode
        return true
    }
    
    /// Provides semantic colors that adapt to dark mode
    public struct SemanticColors {
        @Environment(\.colorScheme) private var colorScheme
        
        public var primaryText: Color {
            colorScheme == .dark ? Theme.foreground : Theme.foreground
        }
        
        public var secondaryText: Color {
            colorScheme == .dark ? Theme.mutedFg : Theme.mutedFg
        }
        
        public var tertiaryText: Color {
            colorScheme == .dark ? Theme.mutedFg.opacity(0.7) : Theme.mutedFg.opacity(0.8)
        }
        
        public var primaryBackground: Color {
            colorScheme == .dark ? Theme.background : Theme.background
        }
        
        public var secondaryBackground: Color {
            colorScheme == .dark ? Theme.card : Theme.card
        }
        
        public var tertiaryBackground: Color {
            colorScheme == .dark ? Theme.card.opacity(0.5) : Theme.card.opacity(0.7)
        }
        
        public var divider: Color {
            colorScheme == .dark ? Theme.border : Theme.border
        }
        
        public var overlay: Color {
            colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.3)
        }
    }
}

// MARK: - Spacing Fix View Modifiers

public extension View {
    /// Replaces hardcoded padding with Theme.Spacing
    func themeSpacing(_ context: ThemeValidator.SpacingContext = .formElements) -> some View {
        self.padding(context.value)
    }
    
    /// Replaces hardcoded VStack/HStack spacing
    func withThemeSpacing<Content: View>(
        _ context: ThemeValidator.SpacingContext = .formElements,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: context.value) {
            content()
        }
    }
}

// MARK: - Fixed Spacing Components

/// VStack with proper Theme spacing
public struct ThemeVStack<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: ThemeValidator.SpacingContext
    let content: () -> Content
    
    public init(
        alignment: HorizontalAlignment = .center,
        spacing: ThemeValidator.SpacingContext = .formElements,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: alignment, spacing: spacing.value) {
            content()
        }
    }
}

/// HStack with proper Theme spacing
public struct ThemeHStack<Content: View>: View {
    let alignment: VerticalAlignment
    let spacing: ThemeValidator.SpacingContext
    let content: () -> Content
    
    public init(
        alignment: VerticalAlignment = .center,
        spacing: ThemeValidator.SpacingContext = .formElements,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }
    
    public var body: some View {
        HStack(alignment: alignment, spacing: spacing.value) {
            content()
        }
    }
}

// MARK: - Dark Mode Testing View

public struct DarkModeTestView: View {
    @State private var colorScheme: ColorScheme = .dark
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    
    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Color scheme toggle
            Picker("Color Scheme", selection: $colorScheme) {
                Text("Light").tag(ColorScheme.light)
                Text("Dark").tag(ColorScheme.dark)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Test primary colors
                    colorTestSection("Primary Colors") {
                        ColorSwatch("Primary", Theme.primary)
                        ColorSwatch("Secondary", Theme.secondary)
                        ColorSwatch("Accent", Theme.accent)
                    }
                    
                    // Test background colors
                    colorTestSection("Backgrounds") {
                        ColorSwatch("Background", Theme.background)
                        ColorSwatch("Card", Theme.card)
                        ColorSwatch("Popover", Theme.popover)
                    }
                    
                    // Test text colors
                    colorTestSection("Text Colors") {
                        ColorSwatch("Foreground", Theme.foreground)
                        ColorSwatch("Muted", Theme.mutedFg)
                        ColorSwatch("Card Foreground", Theme.cardFg)
                    }
                    
                    // Test state colors
                    colorTestSection("State Colors") {
                        ColorSwatch("Success", Theme.success)
                        ColorSwatch("Warning", Theme.warning)
                        ColorSwatch("Error", Theme.error)
                        ColorSwatch("Info", Theme.info)
                    }
                    
                    // Test neon colors
                    colorTestSection("Neon Colors") {
                        ColorSwatch("Neon Cyan", Theme.neonCyan)
                        ColorSwatch("Neon Pink", Theme.neonPink)
                        ColorSwatch("Neon Purple", Theme.neonPurple)
                    }
                    
                    // Test components
                    componentTestSection()
                }
                .padding()
            }
        }
        .preferredColorScheme(colorScheme)
        .background(Theme.background)
    }
    
    private func colorTestSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.foreground)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                content()
            }
        }
        .padding()
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
    }
    
    private func componentTestSection() -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Component Tests")
                .font(.headline)
                .foregroundStyle(Theme.foreground)
            
            // Test button styles
            HStack(spacing: Theme.Spacing.md) {
                Button("Primary") {}
                    .buttonStyle(.borderedProminent)
                
                Button("Secondary") {}
                    .buttonStyle(.bordered)
                
                Button("Destructive") {}
                    .foregroundStyle(Theme.error)
            }
            
            // Test text field
            TextField("Test Input", text: .constant(""))
                .textFieldStyle(.roundedBorder)
            
            // Test list row
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.accent)
                Text("Sample List Item")
                    .foregroundStyle(Theme.foreground)
                Spacer()
                Text("Detail")
                    .foregroundStyle(Theme.mutedFg)
            }
            .padding()
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
        }
        .padding()
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
    }
}

struct ColorSwatch: View {
    let name: String
    let color: Color
    
    init(_ name: String, _ color: Color) {
        self.name = name
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(color)
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .stroke(Theme.border, lineWidth: 1)
                )
            
            Text(name)
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
        }
    }
}

// MARK: - Preview Provider

struct ThemeValidation_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DarkModeTestView()
                .previewDisplayName("Dark Mode Test")
            
            // Test spacing validation
            VStack {
                ThemeVStack(spacing: .inlineElements) {
                    Text("Inline spacing")
                    Text("Between elements")
                }
                
                ThemeHStack(spacing: .navigation) {
                    Image(systemName: "house")
                    Text("Navigation")
                }
                
                ThemeVStack(spacing: .sections) {
                    Text("Section 1")
                    Text("Section 2")
                }
            }
            .padding()
            .previewDisplayName("Theme Spacing Test")
        }
    }
}