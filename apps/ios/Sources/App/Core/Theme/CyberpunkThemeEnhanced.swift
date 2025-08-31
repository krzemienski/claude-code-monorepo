import SwiftUI
import UIKit

// MARK: - Enhanced Cyberpunk Theme System
public struct CyberpunkThemeEnhanced {
    // MARK: - Neon Colors
    public static let neonCyan = Color(hex: "#00FFFF")
    public static let neonMagenta = Color(hex: "#FF00FF")
    public static let neonBlue = Color(hex: "#0080FF")
    public static let neonGreen = Color(hex: "#00FF88")
    public static let neonOrange = Color(hex: "#FF8800")
    public static let neonRed = Color(hex: "#FF0044")
    public static let neonPurple = Color(hex: "#8800FF")
    public static let neonYellow = Color(hex: "#FFFF00")
    
    // MARK: - Dark Backgrounds
    public static let darkBackground = LinearGradient(
        colors: [
            Color(hex: "#0A0A0F"),
            Color(hex: "#0F0F1A")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let darkCard = Color(hex: "#0D0D12").opacity(0.95)
    public static let darkCardBorder = Color(hex: "#1A1A2E").opacity(0.5)
    
    // MARK: - Gradient Effects
    public static let neonGradient = LinearGradient(
        colors: [neonCyan, neonMagenta, neonBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let pulseGradient = RadialGradient(
        colors: [neonCyan.opacity(0.8), neonCyan.opacity(0)],
        center: .center,
        startRadius: 0,
        endRadius: 100
    )
    
    // MARK: - Haptic Feedback
    public static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    public static func notificationOccurred(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - View Modifiers
public extension View {
    // Neon glow effect
    func neonGlow(color: Color = CyberpunkThemeEnhanced.neonCyan, intensity: CGFloat = 2) -> some View {
        self
            .shadow(color: color, radius: intensity)
            .shadow(color: color.opacity(0.5), radius: intensity * 2)
            .shadow(color: color.opacity(0.25), radius: intensity * 4)
    }
    
    // Glitch effect animation
    func glitchEffect(isActive: Bool = true) -> some View {
        modifier(GlitchEffectModifier(isActive: isActive))
    }
    
    // Holographic shimmer
    func holographicEffect() -> some View {
        modifier(HolographicModifier())
    }
    
    // Scanline effect
    func scanlineEffect(speed: Double = 2.0) -> some View {
        modifier(ScanlineModifier(speed: speed))
    }
    
    // Cyberpunk card style
    func cyberpunkCard(glowColor: Color = CyberpunkThemeEnhanced.neonCyan) -> some View {
        self
            .padding()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(CyberpunkThemeEnhanced.darkCard)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [glowColor.opacity(0.6), glowColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .blur(radius: 1)
                }
            )
            .neonGlow(color: glowColor, intensity: 1)
    }
}

// MARK: - Glitch Effect Modifier
struct GlitchEffectModifier: ViewModifier {
    let isActive: Bool
    @State private var offset: CGFloat = 0
    @State private var redOffset: CGFloat = 0
    @State private var blueOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    content
                        .offset(x: redOffset)
                        .opacity(0.5)
                        .blendMode(.screen)
                        .foregroundStyle(CyberpunkThemeEnhanced.neonRed)
                )
                .overlay(
                    content
                        .offset(x: blueOffset)
                        .opacity(0.5)
                        .blendMode(.screen)
                        .foregroundStyle(CyberpunkThemeEnhanced.neonCyan)
                )
                .offset(x: offset)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 0.1)
                            .repeatForever(autoreverses: true)
                    ) {
                        offset = CGFloat.random(in: -2...2)
                        redOffset = CGFloat.random(in: -1...1)
                        blueOffset = CGFloat.random(in: -1...1)
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Holographic Modifier
struct HolographicModifier: ViewModifier {
    @State private var shimmerOffset: CGFloat = -200
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 100)
                .offset(x: shimmerOffset)
                .mask(content)
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 2)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerOffset = 200
                }
            }
    }
}

// MARK: - Scanline Modifier
struct ScanlineModifier: ViewModifier {
    let speed: Double
    @State private var scanlinePosition: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    CyberpunkThemeEnhanced.neonGreen.opacity(0),
                                    CyberpunkThemeEnhanced.neonGreen.opacity(0.1),
                                    CyberpunkThemeEnhanced.neonGreen.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 20)
                        .offset(y: scanlinePosition)
                        .allowsHitTesting(false)
                        .onAppear {
                            withAnimation(
                                .linear(duration: speed)
                                    .repeatForever(autoreverses: false)
                            ) {
                                scanlinePosition = geometry.size.height
                            }
                        }
                }
            )
            .clipped()
    }
}

// MARK: - Particle Effects View
public struct ParticleEffectsView: View {
    let particleCount: Int
    @State private var particles: [Particle] = []
    
    public init(particleCount: Int = 30) {
        self.particleCount = particleCount
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .blur(radius: particle.blur)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                particles = (0..<particleCount).map { _ in
                    Particle(in: geometry.size)
                }
                animateParticles()
            }
        }
    }
    
    private func animateParticles() {
        for index in particles.indices {
            withAnimation(
                .linear(duration: Double.random(in: 10...20))
                    .repeatForever(autoreverses: false)
            ) {
                particles[index].position.y = -50
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...10)) {
                withAnimation(
                    .easeInOut(duration: Double.random(in: 2...4))
                        .repeatForever(autoreverses: true)
                ) {
                    particles[index].opacity = Double.random(in: 0.1...0.3)
                }
            }
        }
    }
}

// MARK: - Particle Model
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var color: Color
    var opacity: Double
    var blur: CGFloat
    
    init(in size: CGSize) {
        self.position = CGPoint(
            x: CGFloat.random(in: 0...size.width),
            y: CGFloat.random(in: 0...size.height)
        )
        self.size = CGFloat.random(in: 2...6)
        self.color = [
            CyberpunkThemeEnhanced.neonCyan,
            CyberpunkThemeEnhanced.neonMagenta,
            CyberpunkThemeEnhanced.neonBlue
        ].randomElement()!
        self.opacity = Double.random(in: 0.1...0.3)
        self.blur = CGFloat.random(in: 1...3)
    }
}

// MARK: - Animated Status Bar
public struct AnimatedStatusBar: View {
    @State private var statusText = "SYSTEM ONLINE"
    @State private var glowAnimation = false
    @State private var typewriterIndex = 0
    
    private let statusMessages = [
        "SYSTEM ONLINE",
        "NEURAL NETWORK ACTIVE",
        "QUANTUM ENCRYPTION ENABLED",
        "SYNAPTIC BRIDGE CONNECTED",
        "MATRIX SYNCHRONIZED"
    ]
    
    public init() {}
    
    public var body: some View {
        HStack {
            // Animated status indicator
            ZStack {
                Circle()
                    .fill(CyberpunkThemeEnhanced.neonGreen)
                    .frame(width: 8, height: 8)
                
                Circle()
                    .stroke(CyberpunkThemeEnhanced.neonGreen, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .scaleEffect(glowAnimation ? 1.5 : 1.0)
                    .opacity(glowAnimation ? 0 : 1)
            }
            
            // Typewriter effect text
            Text(String(statusText.prefix(typewriterIndex)))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(CyberpunkThemeEnhanced.neonCyan)
                .neonGlow(color: CyberpunkThemeEnhanced.neonCyan, intensity: 1)
            
            Spacer()
            
            // Animated bars
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    AnimatedBar(delay: Double(index) * 0.1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(CyberpunkThemeEnhanced.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(CyberpunkThemeEnhanced.neonCyan.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Glow animation
        withAnimation(
            .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: false)
        ) {
            glowAnimation = true
        }
        
        // Typewriter effect
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if typewriterIndex < statusText.count {
                typewriterIndex += 1
            } else {
                timer.invalidate()
                
                // Change status after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    statusText = statusMessages.randomElement()!
                    typewriterIndex = 0
                    startAnimations()
                }
            }
        }
    }
}

// MARK: - Animated Bar Component
struct AnimatedBar: View {
    let delay: Double
    @State private var height: CGFloat = 4
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(CyberpunkThemeEnhanced.neonGreen)
            .frame(width: 3, height: height)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    height = 12
                }
            }
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