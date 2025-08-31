import SwiftUI
import UIKit

/// Enhanced Cyberpunk Theme with neon effects and animations
public struct CyberpunkTheme {
    // MARK: - Core Neon Colors
    public static let neonCyan = Color(hex: "#00FFFF")
    public static let neonMagenta = Color(hex: "#FF00FF")
    public static let neonBlue = Color(hex: "#0080FF")
    public static let neonPink = Color(hex: "#FF10F0")
    public static let neonGreen = Color(hex: "#00FF88")
    public static let neonOrange = Color(hex: "#FF8800")
    public static let neonPurple = Color(hex: "#8800FF")
    
    // MARK: - Dark Background Colors
    public static let darkBackground = Color(hex: "#0A0A0F")
    public static let darkCard = Color(hex: "#12121A")
    public static let darkBorder = Color(hex: "#1F1F2E")
    public static let darkOverlay = Color(hex: "#000000").opacity(0.8)
    
    // MARK: - Gradient Definitions
    public static let neonGradient = LinearGradient(
        colors: [neonCyan, neonMagenta, neonBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let pulseGradient = RadialGradient(
        colors: [neonCyan.opacity(0.8), neonCyan.opacity(0.2), Color.clear],
        center: .center,
        startRadius: 5,
        endRadius: 50
    )
    
    public static let glowGradient = LinearGradient(
        colors: [
            neonMagenta.opacity(0.3),
            neonCyan.opacity(0.3),
            neonBlue.opacity(0.3)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - View Modifiers
    public struct NeonGlow: ViewModifier {
        let color: Color
        let intensity: Double
        @State private var isAnimating = false
        
        public func body(content: Content) -> some View {
            content
                .shadow(color: color.opacity(0.8), radius: intensity * 2)
                .shadow(color: color.opacity(0.6), radius: intensity * 4)
                .shadow(color: color.opacity(0.4), radius: intensity * 8)
                .overlay(
                    content
                        .foregroundStyle(color)
                        .blur(radius: intensity * 0.5)
                        .opacity(isAnimating ? 0.6 : 0.3)
                        .animation(
                            .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                )
                .onAppear { isAnimating = true }
        }
    }
    
    public struct CyberpunkCard: ViewModifier {
        @State private var glowAnimation = false
        
        public func body(content: Content) -> some View {
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(darkCard)
                        
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [neonCyan.opacity(0.6), neonMagenta.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .blur(radius: glowAnimation ? 3 : 1)
                            .opacity(glowAnimation ? 0.8 : 0.4)
                    }
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                        glowAnimation = true
                    }
                }
        }
    }
    
    public struct HolographicEffect: ViewModifier {
        @State private var offset: CGFloat = 0
        
        public func body(content: Content) -> some View {
            content
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            neonCyan.opacity(0.2),
                            Color.clear,
                            neonMagenta.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .offset(x: offset, y: offset)
                    .animation(
                        .linear(duration: 3)
                            .repeatForever(autoreverses: true),
                        value: offset
                    )
                )
                .onAppear {
                    offset = 20
                }
        }
    }
    
    public struct ScanlineEffect: ViewModifier {
        @State private var scanlineOffset: CGFloat = -100
        
        public func body(content: Content) -> some View {
            content
                .overlay(
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        neonGreen.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 2)
                            .offset(y: scanlineOffset)
                            .animation(
                                .linear(duration: 4)
                                    .repeatForever(autoreverses: false),
                                value: scanlineOffset
                            )
                            .onAppear {
                                scanlineOffset = geometry.size.height + 100
                            }
                    }
                    .allowsHitTesting(false)
                )
        }
    }
    
    // MARK: - Animation Helpers
    public static func pulseAnimation(duration: Double = 2.0) -> Animation {
        Animation.easeInOut(duration: duration)
            .repeatForever(autoreverses: true)
    }
    
    public static func glowAnimation(duration: Double = 3.0) -> Animation {
        Animation.easeInOut(duration: duration)
            .repeatForever(autoreverses: true)
    }
    
    public static func scanAnimation(duration: Double = 4.0) -> Animation {
        Animation.linear(duration: duration)
            .repeatForever(autoreverses: false)
    }
    
    // MARK: - Haptic Feedback
    public static func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    public static func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    public static func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    public static func selectionFeedback() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    public static func notificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(type)
    }
}

// MARK: - View Extensions
public extension View {
    func neonGlow(color: Color = CyberpunkTheme.neonCyan, intensity: Double = 4) -> some View {
        modifier(CyberpunkTheme.NeonGlow(color: color, intensity: intensity))
    }
    
    func cyberpunkCard() -> some View {
        modifier(CyberpunkTheme.CyberpunkCard())
    }
    
    func holographicEffect() -> some View {
        modifier(CyberpunkTheme.HolographicEffect())
    }
    
    func scanlineEffect() -> some View {
        modifier(CyberpunkTheme.ScanlineEffect())
    }
}

// MARK: - Color Extension
extension Color {
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