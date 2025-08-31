import SwiftUI

// MARK: - ⚡ Text Glow Modifier
public struct TextGlowModifier: ViewModifier {
    let color: Color
    @State private var glowIntensity: Double = 0.7
    
    public func body(content: Content) -> some View {
        content
            .foregroundStyle(color)
            .shadow(color: color.opacity(glowIntensity), radius: 2)
            .shadow(color: color.opacity(glowIntensity * 0.7), radius: 5)
            .shadow(color: color.opacity(glowIntensity * 0.5), radius: 10)
            .onAppear {
                withAnimation(CyberpunkTheme.Animations.pulse) {
                    glowIntensity = 1.0
                }
            }
    }
}

// MARK: - 🎨 Border Glow Modifier
public struct BorderGlowModifier: ViewModifier {
    let color: Color
    @State private var phase: CGFloat = 0
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                color,
                                color.opacity(0.5),
                                color,
                                color.opacity(0.5),
                                color
                            ]),
                            center: .center,
                            angle: .degrees(phase)
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: color.opacity(0.5), radius: 5)
            .onAppear {
                withAnimation(Animation.linear(duration: 4).repeatForever(autoreverses: false)) {
                    phase = 360
                }
            }
    }
}

// MARK: - 📊 Scanline Effect
public struct ScanlineModifier: ViewModifier {
    @State private var offset: CGFloat = -1000
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    CyberpunkTheme.Colors.neonCyan.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 50)
                        .offset(y: offset)
                        .onAppear {
                            withAnimation(CyberpunkTheme.Animations.scan) {
                                offset = geometry.size.height + 50
                            }
                        }
                }
                .allowsHitTesting(false)
            )
    }
}

// MARK: - ⚡ Glitch Effect
public struct GlitchModifier: ViewModifier {
    @State private var glitchOffset: CGFloat = 0
    @State private var showGlitch = false
    
    public func body(content: Content) -> some View {
        ZStack {
            content
                .offset(x: showGlitch ? glitchOffset : 0)
                .foregroundStyle(CyberpunkTheme.Colors.neonCyan)
                .opacity(showGlitch ? 0.5 : 0)
            
            content
                .offset(x: showGlitch ? -glitchOffset : 0)
                .foregroundStyle(CyberpunkTheme.Colors.neonMagenta)
                .opacity(showGlitch ? 0.5 : 0)
            
            content
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation(CyberpunkTheme.Animations.glitch) {
                    showGlitch = true
                    glitchOffset = CGFloat.random(in: -2...2)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(CyberpunkTheme.Animations.glitch) {
                        showGlitch = false
                        glitchOffset = 0
                    }
                }
            }
        }
    }
}

// MARK: - 🎨 Neon Button Style
public struct NeonButtonStyle: ButtonStyle {
    let primaryColor: Color
    @State private var isPressed = false
    @State private var glowIntensity: Double = 0.5
    
    public init(color: Color = CyberpunkTheme.Colors.neonCyan) {
        self.primaryColor = color
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CyberpunkTheme.Fonts.body)
            .foregroundStyle(primaryColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(CyberpunkTheme.Colors.darkBgSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(primaryColor, lineWidth: 2)
                    )
            )
            .shadow(color: primaryColor.opacity(glowIntensity), radius: 10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onChange(of: configuration.isPressed) { pressed in
                withAnimation(.easeInOut(duration: 0.1)) {
                    glowIntensity = pressed ? 1.0 : 0.5
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

// MARK: - View Extensions
extension View {
    public func cyberpunkGlow(_ color: Color = CyberpunkTheme.Colors.neonCyan) -> some View {
        modifier(TextGlowModifier(color: color))
    }
    
    public func cyberpunkBorder(_ color: Color = CyberpunkTheme.Colors.neonMagenta) -> some View {
        modifier(BorderGlowModifier(color: color))
    }
    
    public func scanlineEffect() -> some View {
        modifier(ScanlineModifier())
    }
    
    public func glitchEffect() -> some View {
        modifier(GlitchModifier())
    }
}