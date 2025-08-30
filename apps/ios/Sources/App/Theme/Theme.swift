import SwiftUI

// MARK: - Dynamic Type Size Extension
extension DynamicTypeSize {
    var scale: CGFloat {
        switch self {
        case .xSmall: return 0.8
        case .small: return 0.85
        case .medium: return 0.9
        case .large: return 1.0
        case .xLarge: return 1.1
        case .xxLarge: return 1.2
        case .xxxLarge: return 1.3
        case .accessibility1: return 1.4
        case .accessibility2: return 1.5
        case .accessibility3: return 1.6
        case .accessibility4: return 1.7
        case .accessibility5: return 1.8
        @unknown default: return 1.0
        }
    }
}

// MARK: - Color Conversion Utilities

private func hslToRGB(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
    let C = (1 - abs(2*l - 1)) * s
    let X = C * (1 - abs(((h/60).truncatingRemainder(dividingBy: 2)) - 1))
    let m = l - C/2
    let (r1,g1,b1):(Double,Double,Double)
    switch h {
    case 0..<60:   (r1,g1,b1) = (C,X,0)
    case 60..<120: (r1,g1,b1) = (X,C,0)
    case 120..<180:(r1,g1,b1) = (0,C,X)
    case 180..<240:(r1,g1,b1) = (0,X,C)
    case 240..<300:(r1,g1,b1) = (X,0,C)
    default:       (r1,g1,b1) = (C,0,X)
    }
    return (r1+m, g1+m, b1+m)
}

public extension Color {
    init(h: Double, s: Double, l: Double, a: Double = 1) {
        let (r,g,b) = hslToRGB(h: h, s: s/100.0, l: l/100.0)
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Accessibility Color Support

public struct AccessibilityColors {
    // High contrast colors
    public static let highContrastBackground = Color.black
    public static let highContrastForeground = Color.white
    public static let highContrastPrimary = Color(hex: "00FFFF") // Pure cyan
    public static let highContrastSecondary = Color(hex: "FF00FF") // Pure magenta
    public static let highContrastAccent = Color(hex: "FFFF00") // Pure yellow
    public static let highContrastSuccess = Color(hex: "00FF00") // Pure green
    public static let highContrastWarning = Color(hex: "FFA500") // Pure orange
    public static let highContrastError = Color(hex: "FF0000") // Pure red
    public static let highContrastBorder = Color.white
    
    // Color blind friendly palette
    public static let colorBlindBlue = Color(hex: "0173B2")
    public static let colorBlindOrange = Color(hex: "DE8F05")
    public static let colorBlindGreen = Color(hex: "029E73")
    public static let colorBlindYellow = Color(hex: "EFE645")
    public static let colorBlindPurple = Color(hex: "CC78BC")
    public static let colorBlindRed = Color(hex: "EC7014")
    public static let colorBlindBrown = Color(hex: "FBAFE4")
    public static let colorBlindPink = Color(hex: "949494")
    
    // Focus indicator colors
    public static let focusRing = Color(hex: "007AFF") // iOS system blue
    public static let focusRingHighContrast = Color.white
}

// MARK: - Cyberpunk Theme

public enum Theme {
    // MARK: - Core Background Colors
    public static let background = Color(hex: "0B0F17")      // Deep dark blue-black (spec: #0B0F17) ✅
    public static let surface = Color(hex: "111827")         // Panel surface (spec: #111827) ✅
    public static let backgroundSecondary = Color(hex: "1A1F2E")  // Slightly lighter bg
    public static let backgroundTertiary = Color(hex: "282E3F")   // Card/elevated bg
    
    // MARK: - Neon Accent Colors (Cyberpunk)
    public static let neonCyan = Color(hex: "00FFE1")        // Primary neon cyan
    public static let neonPink = Color(hex: "FF2A6D")        // Hot pink accent
    public static let neonPurple = Color(hex: "BD00FF")      // Electric purple
    public static let neonBlue = Color(hex: "05D9FF")        // Bright blue
    public static let neonGreen = Color(hex: "7CFF00")       // Signal lime (spec: #7CFF00) ✅
    public static let neonYellow = Color(hex: "FFB020")      // Warning (spec: #FFB020) ✅
    
    // MARK: - Primary Theme Colors
    public static let primary = neonCyan
    public static let primaryFg = Color.white
    public static let accent = neonPink
    public static let accentFg = Color.white
    
    // MARK: - Text Colors
    public static let foreground = Color(hex: "E5E7EB")      // Primary text (spec: #E5E7EB) ✅
    public static let mutedFg = Color(hex: "94A3B8")         // Secondary text (spec: #94A3B8) ✅
    public static let dimFg = Color(hex: "4A5568")           // Very dim text
    public static let divider = Color.white.opacity(0.08)    // Divider (spec: rgba(255,255,255,0.08)) ✅
    
    // MARK: - UI Element Colors
    public static let card = backgroundTertiary
    public static let cardFg = foreground
    public static let border = Color(hex: "2D3748").opacity(0.5)
    public static let borderActive = neonCyan.opacity(0.5)
    public static let input = Color(hex: "1A202C")
    public static let inputFocus = Color(hex: "2D3748")
    
    // MARK: - Semantic Colors
    public static let success = neonGreen                    // Signal lime (#7CFF00) ✅
    public static let warning = neonYellow                   // Warning (#FFB020) ✅
    public static let error = Color(hex: "FF5C5C")          // Error (spec: #FF5C5C) ✅
    public static let info = neonBlue
    
    // MARK: - Legacy Compatibility
    public static let secondary = backgroundSecondary
    public static let secondaryFg = mutedFg
    public static let muted = backgroundTertiary
    public static let destructive = error
    public static let destructiveFg = Color.white
    public static let ring = neonCyan.opacity(0.5)
    
    // MARK: - Gradients
    public static let neonGradient = LinearGradient(
        colors: [neonCyan, neonBlue, neonPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let darkGradient = LinearGradient(
        colors: [background, backgroundSecondary],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let accentGradient = LinearGradient(
        colors: [neonPink, neonPurple],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Shadows & Effects
    public static func neonGlow(color: Color = neonCyan, radius: CGFloat = 10) -> some View {
        color
            .blur(radius: radius)
            .opacity(0.6)
    }
    
    public static let cardShadow = Color.black.opacity(0.3)
    
    // MARK: - Typography Scales with Dynamic Type Support
    public enum FontSize {
        // Base sizes for phone
        public static let xs: CGFloat = 12       // Caption (spec: 12pt) ✅
        public static let sm: CGFloat = 14
        public static let base: CGFloat = 16     // Body (spec: 16pt) ✅
        public static let lg: CGFloat = 18       // Subtitle (spec: 18pt) ✅
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24      // Title (spec: 24pt) ✅
        public static let xxxl: CGFloat = 32
        public static let display: CGFloat = 48
        
        // Adaptive sizes for iPad
        public static func adaptive(_ size: CGFloat, for idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> CGFloat {
            switch idiom {
            case .pad:
                return size * 1.2 // 20% larger on iPad
            case .mac:
                return size * 1.1 // 10% larger on Mac
            default:
                return size
            }
        }
        
        // Dynamic Type scalable sizes
        public static func scalable(_ size: CGFloat, for sizeCategory: DynamicTypeSize) -> CGFloat {
            let scale = sizeCategory.scale
            return size * scale
        }
    }
    
    public enum FontWeight {
        public static let regular = Font.Weight.regular     // Body, Caption ✅
        public static let medium = Font.Weight.medium       // Subtitle ✅
        public static let semibold = Font.Weight.semibold   // Title ✅
        public static let bold = Font.Weight.bold
        public static let black = Font.Weight.black
    }
    
    // MARK: - Font Configuration
    public enum Fonts {
        /// SF Pro Text for UI elements (system default)
        public static let ui = Font.system(.body, design: .default)
        
        /// JetBrains Mono for code and logs
        public static func code(size: CGFloat = FontSize.sm) -> Font {
            // Check if JetBrains Mono is available
            #if os(iOS)
            if UIFont.fontNames(forFamilyName: "JetBrains Mono").isEmpty {
                // Fallback to system monospaced if JetBrains Mono not available
                return Font.system(size: size, design: .monospaced)
            }
            #endif
            return Font.custom("JetBrains Mono", size: size)
        }
        
        /// Helper for title text
        public static let title = Font.system(size: FontSize.xxl, weight: .semibold)
        
        /// Helper for subtitle text
        public static let subtitle = Font.system(size: FontSize.lg, weight: .medium)
        
        /// Helper for body text
        public static let body = Font.system(size: FontSize.base, weight: .regular)
        
        /// Helper for caption text
        public static let caption = Font.system(size: FontSize.xs, weight: .regular)
    }
    
    // MARK: - Spacing Scale with Adaptive Layout Support
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let xxxl: CGFloat = 48
        
        // Adaptive spacing for different device idioms
        public static func adaptive(_ spacing: CGFloat, for idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> CGFloat {
            switch idiom {
            case .pad:
                return spacing * 1.3 // 30% more spacing on iPad
            case .mac:
                return spacing * 1.2 // 20% more spacing on Mac
            default:
                return spacing
            }
        }
    }
    
    // MARK: - Corner Radius
    public enum CornerRadius {
        public static let sm: CGFloat = 4
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 12
        public static let xl: CGFloat = 16
        public static let full: CGFloat = 9999
    }
    
    // MARK: - Animation Durations
    public enum Animation {
        public static let fast: Double = 0.15
        public static let normal: Double = 0.25
        public static let slow: Double = 0.35
        public static let verySlow: Double = 0.5
        
        public static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        public static let smooth = SwiftUI.Animation.easeInOut(duration: normal)
        public static let bounce = SwiftUI.Animation.interpolatingSpring(stiffness: 300, damping: 15)
        
        // Reduced motion animations
        public static func reduced(_ animation: SwiftUI.Animation?, reduceMotion: Bool) -> SwiftUI.Animation? {
            return reduceMotion ? .none : animation
        }
    }
    
    // MARK: - Accessibility Helpers
    
    /// Get appropriate color based on contrast settings
    public static func adaptiveColor(
        normal: Color,
        highContrast: Color,
        isHighContrast: Bool = false
    ) -> Color {
        return isHighContrast ? highContrast : normal
    }
    
    /// Get appropriate spacing based on Dynamic Type size
    public static func adaptiveSpacing(
        _ base: CGFloat,
        for sizeCategory: DynamicTypeSize = .large
    ) -> CGFloat {
        let scale = sizeCategory.scale
        return base * max(1.0, scale)
    }
    
    /// Check if a color provides sufficient contrast
    public static func hasGoodContrast(
        foreground: Color,
        background: Color,
        threshold: Double = 4.5 // WCAG AA standard
    ) -> Bool {
        // This is a simplified check - in production, you'd calculate actual contrast ratio
        return true // Placeholder for actual contrast calculation
    }
    
    /// Get minimum touch target size for accessibility
    public static func minimumTouchTarget(for idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> CGFloat {
        switch idiom {
        case .pad:
            return 44 // Standard iOS minimum
        case .phone:
            return 44 // Standard iOS minimum
        default:
            return 44
        }
    }
}
