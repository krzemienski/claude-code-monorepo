import SwiftUI
import Foundation

/// 🎨 Cyberpunk Theme System with Neon Colors and Glow Effects
public struct CyberpunkTheme {
    // MARK: - Neon Color Palette
    public struct Colors {
        // Primary Neons
        public static let neonCyan = Color(hex: "#00FFFF")
        public static let neonMagenta = Color(hex: "#FF00FF")
        public static let neonBlue = Color(hex: "#0080FF")
        public static let neonPurple = Color(hex: "#9D00FF")
        public static let neonPink = Color(hex: "#FF0099")
        public static let neonGreen = Color(hex: "#00FF88")
        public static let electricYellow = Color(hex: "#FFFF00")
        
        // Dark Backgrounds
        public static let darkBg = Color(hex: "#0A0A0A")
        public static let darkBgSecondary = Color(hex: "#1A1A1A")
        public static let darkBgTertiary = Color(hex: "#252525")
        public static let darkBgOverlay = Color(hex: "#0A0A0A").opacity(0.85)
        
        // Gradients
        public static let neonGradient = LinearGradient(
            colors: [neonCyan, neonMagenta, neonBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let darkGradient = LinearGradient(
            colors: [darkBg, darkBgSecondary],
            startPoint: .top,
            endPoint: .bottom
        )
        
        public static let glowGradient = RadialGradient(
            colors: [neonCyan.opacity(0.3), Color.clear],
            center: .center,
            startRadius: 5,
            endRadius: 100
        )
    }
    
    // MARK: - Glow Effects
    public struct Glow {
        public static func neon(_ color: Color, intensity: Double = 1.0) -> some View {
            color
                .shadow(color: color.opacity(0.8 * intensity), radius: 2)
                .shadow(color: color.opacity(0.6 * intensity), radius: 5)
                .shadow(color: color.opacity(0.4 * intensity), radius: 10)
                .shadow(color: color.opacity(0.2 * intensity), radius: 20)
        }
        
        public static func text(_ color: Color) -> some ViewModifier {
            TextGlowModifier(color: color)
        }
        
        public static func border(_ color: Color) -> some ViewModifier {
            BorderGlowModifier(color: color)
        }
    }
    
    // MARK: - Animations
    public struct Animations {
        public static let pulse = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        public static let flicker = Animation.easeInOut(duration: 0.15).repeatForever(autoreverses: true)
        public static let scan = Animation.linear(duration: 3.0).repeatForever(autoreverses: false)
        public static let glitch = Animation.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.3)
        public static let neonBlink = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    }
    
    // MARK: - Typography
    public struct Fonts {
        public static let display = Font.system(.largeTitle, design: .monospaced).weight(.bold)
        public static let heading = Font.system(.title2, design: .monospaced).weight(.semibold)
        public static let body = Font.system(.body, design: .monospaced)
        public static let code = Font.system(.callout, design: .monospaced)
        public static let caption = Font.system(.caption, design: .monospaced)
    }
}