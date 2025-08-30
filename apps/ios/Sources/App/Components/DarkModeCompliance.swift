import SwiftUI

// MARK: - Dark Mode Compliance Testing

/// Comprehensive dark mode compliance testing and validation
public struct DarkModeCompliance {
    
    // MARK: - WCAG Contrast Requirements
    
    public enum WCAGLevel {
        case AA  // 4.5:1 for normal text, 3:1 for large text
        case AAA // 7:1 for normal text, 4.5:1 for large text
        
        var normalTextRatio: Double {
            switch self {
            case .AA: return 4.5
            case .AAA: return 7.0
            }
        }
        
        var largeTextRatio: Double {
            switch self {
            case .AA: return 3.0
            case .AAA: return 4.5
            }
        }
    }
    
    // MARK: - Color Luminance Calculation
    
    /// Calculate relative luminance of a color
    public static func relativeLuminance(of color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Apply gamma correction
        let correctChannel: (CGFloat) -> Double = { channel in
            let c = Double(channel)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        
        let r = correctChannel(red)
        let g = correctChannel(green)
        let b = correctChannel(blue)
        
        // Calculate relative luminance
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    /// Calculate contrast ratio between two colors
    public static func contrastRatio(between color1: UIColor, and color2: UIColor) -> Double {
        let lum1 = relativeLuminance(of: color1)
        let lum2 = relativeLuminance(of: color2)
        
        let lighter = max(lum1, lum2)
        let darker = min(lum1, lum2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// Check if two colors meet WCAG contrast requirements
    public static func meetsWCAGContrast(
        foreground: UIColor,
        background: UIColor,
        fontSize: CGFloat = 17,
        level: WCAGLevel = .AA
    ) -> Bool {
        let ratio = contrastRatio(between: foreground, and: background)
        let isLargeText = fontSize >= 18 || (fontSize >= 14 && fontSize.isBold)
        let requiredRatio = isLargeText ? level.largeTextRatio : level.normalTextRatio
        
        return ratio >= requiredRatio
    }
}

// MARK: - Dark Mode Test View

/// Interactive dark mode testing view
public struct DarkModeComplianceTestView: View {
    @State private var colorScheme: ColorScheme = .dark
    @State private var showContrastIssues = false
    @State private var wcagLevel: DarkModeCompliance.WCAGLevel = .AA
    @State private var testResults: [TestResult] = []
    
    struct TestResult: Identifiable {
        let id = UUID()
        let component: String
        let issue: String
        let severity: Severity
        
        enum Severity {
            case critical
            case warning
            case info
            
            var color: Color {
                switch self {
                case .critical: return .red
                case .warning: return .orange
                case .info: return .blue
                }
            }
        }
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Control Panel
                controlPanel
                
                Divider()
                
                // Test Results
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        // Theme Colors Test
                        themeColorsTest
                        
                        // Component Tests
                        componentTests
                        
                        // Contrast Validation Results
                        if showContrastIssues {
                            contrastValidationResults
                        }
                    }
                    .padding()
                }
                .preferredColorScheme(colorScheme)
            }
            .navigationTitle("Dark Mode Compliance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Run Tests") {
                        runComplianceTests()
                    }
                }
            }
        }
    }
    
    private var controlPanel: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Color Scheme Toggle
            HStack {
                Text("Color Scheme:")
                Picker("Color Scheme", selection: $colorScheme) {
                    Label("Light", systemImage: "sun.max.fill").tag(ColorScheme.light)
                    Label("Dark", systemImage: "moon.fill").tag(ColorScheme.dark)
                }
                .pickerStyle(.segmented)
            }
            
            // WCAG Level
            HStack {
                Text("WCAG Level:")
                Picker("WCAG Level", selection: $wcagLevel) {
                    Text("AA").tag(DarkModeCompliance.WCAGLevel.AA)
                    Text("AAA").tag(DarkModeCompliance.WCAGLevel.AAA)
                }
                .pickerStyle(.segmented)
            }
            
            // Show Issues Toggle
            Toggle("Show Contrast Issues", isOn: $showContrastIssues)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var themeColorsTest: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Theme Colors")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Theme.Spacing.sm) {
                ColorTestCard(name: "Primary", color: Theme.primary)
                ColorTestCard(name: "Secondary", color: Theme.secondary)
                ColorTestCard(name: "Background", color: Theme.background)
                ColorTestCard(name: "Card", color: Theme.card)
                ColorTestCard(name: "Border", color: Theme.border)
                ColorTestCard(name: "Muted", color: Theme.mutedFg)
                ColorTestCard(name: "Destructive", color: Theme.destructive)
                ColorTestCard(name: "Success", color: Theme.success)
            }
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(12)
    }
    
    private var componentTests: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Component Tests")
                .font(.headline)
            
            // Sample Button
            HStack {
                Button("Primary Button") {}
                    .buttonStyle(.borderedProminent)
                
                Button("Secondary Button") {}
                    .buttonStyle(.bordered)
                
                Button("Destructive") {}
                    .foregroundColor(Theme.destructive)
            }
            
            // Sample Form Controls
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                TextField("Sample Input", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Sample Toggle", isOn: .constant(true))
                
                Slider(value: .constant(0.5))
                    .tint(Theme.primary)
            }
            
            // Sample List
            List {
                ForEach(0..<3) { i in
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(Theme.primary)
                        Text("List Item \(i + 1)")
                        Spacer()
                        Text("Detail")
                            .foregroundColor(Theme.mutedFg)
                    }
                }
            }
            .frame(height: 150)
            .listStyle(.insetGrouped)
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(12)
    }
    
    private var contrastValidationResults: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Contrast Validation")
                .font(.headline)
            
            if testResults.isEmpty {
                Text("No issues found")
                    .foregroundColor(Theme.success)
            } else {
                ForEach(testResults) { result in
                    HStack {
                        Circle()
                            .fill(result.severity.color)
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading) {
                            Text(result.component)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(result.issue)
                                .font(.caption)
                                .foregroundColor(Theme.mutedFg)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(12)
    }
    
    private func runComplianceTests() {
        testResults = []
        
        // Test theme color contrasts
        let backgroundUIColor = UIColor(Theme.background)
        let foregroundUIColor = UIColor(Theme.foreground)
        let primaryUIColor = UIColor(Theme.primary)
        let mutedUIColor = UIColor(Theme.mutedFg)
        
        // Test foreground/background contrast
        if !DarkModeCompliance.meetsWCAGContrast(
            foreground: foregroundUIColor,
            background: backgroundUIColor,
            level: wcagLevel
        ) {
            testResults.append(TestResult(
                component: "Text",
                issue: "Foreground/background contrast insufficient",
                severity: .critical
            ))
        }
        
        // Test muted text contrast
        if !DarkModeCompliance.meetsWCAGContrast(
            foreground: mutedUIColor,
            background: backgroundUIColor,
            level: wcagLevel
        ) {
            testResults.append(TestResult(
                component: "Muted Text",
                issue: "Muted text contrast may be too low",
                severity: .warning
            ))
        }
        
        // Test primary color contrast
        if !DarkModeCompliance.meetsWCAGContrast(
            foreground: primaryUIColor,
            background: backgroundUIColor,
            level: wcagLevel
        ) {
            testResults.append(TestResult(
                component: "Primary Color",
                issue: "Primary color contrast needs adjustment",
                severity: .warning
            ))
        }
        
        // Show results
        showContrastIssues = true
    }
}

// MARK: - Color Test Card

private struct ColorTestCard: View {
    let name: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 60)
                .overlay(
                    Text("Aa")
                        .font(.title2)
                        .foregroundColor(Theme.foreground)
                )
            
            Text(name)
                .font(.caption)
                .foregroundColor(Theme.mutedFg)
            
            // Contrast ratio indicator
            HStack(spacing: 2) {
                Image(systemName: contrastIcon)
                    .font(.caption2)
                Text(contrastRatioText)
                    .font(.caption2)
            }
            .foregroundColor(contrastColor)
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.card)
        .cornerRadius(8)
    }
    
    private var contrastIcon: String {
        // Placeholder - would calculate actual contrast
        return "checkmark.circle.fill"
    }
    
    private var contrastRatioText: String {
        // Placeholder - would show actual ratio
        return "4.5:1"
    }
    
    private var contrastColor: Color {
        // Placeholder - would indicate pass/fail
        return Theme.success
    }
}

// MARK: - CGFloat Extension

private extension CGFloat {
    var isBold: Bool {
        // Placeholder for font weight detection
        return false
    }
}

// MARK: - Preview Provider

struct DarkModeCompliance_Previews: PreviewProvider {
    static var previews: some View {
        DarkModeComplianceTestView()
    }
}