import SwiftUI

/// Particle Effects View for loading states and animations
public struct ParticleEffectsView: View {
    let particleCount: Int
    let colors: [Color]
    @State private var particles: [Particle] = []
    @State private var isAnimating = false
    
    public init(
        particleCount: Int = 50,
        colors: [Color] = [
            CyberpunkTheme.neonCyan,
            CyberpunkTheme.neonMagenta,
            CyberpunkTheme.neonBlue
        ]
    ) {
        self.particleCount = particleCount
        self.colors = colors
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .blur(radius: particle.blur)
                        .opacity(particle.opacity)
                        .position(
                            x: particle.position.x,
                            y: particle.position.y
                        )
                        .animation(
                            Animation.linear(duration: particle.duration)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                isAnimating = true
            }
        }
        .allowsHitTesting(false)
    }
    
    private func createParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 2...8),
                color: colors.randomElement() ?? CyberpunkTheme.neonCyan,
                opacity: Double.random(in: 0.3...0.8),
                blur: CGFloat.random(in: 0...2),
                duration: Double.random(in: 8...15)
            )
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let size: CGFloat
    let color: Color
    let opacity: Double
    let blur: CGFloat
    let duration: Double
}

/// Matrix Rain Effect for cyberpunk aesthetic
public struct MatrixRainEffect: View {
    @State private var columns: [MatrixColumn] = []
    let columnCount: Int
    
    public init(columnCount: Int = 20) {
        self.columnCount = columnCount
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(columns) { column in
                    MatrixColumnView(column: column, height: geometry.size.height)
                }
            }
            .onAppear {
                createColumns(width: geometry.size.width)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func createColumns(width: CGFloat) {
        let spacing = width / CGFloat(columnCount)
        columns = (0..<columnCount).map { index in
            MatrixColumn(
                xPosition: CGFloat(index) * spacing + spacing / 2,
                delay: Double.random(in: 0...2)
            )
        }
    }
}

struct MatrixColumn: Identifiable {
    let id = UUID()
    let xPosition: CGFloat
    let delay: Double
}

struct MatrixColumnView: View {
    let column: MatrixColumn
    let height: CGFloat
    @State private var offset: CGFloat = -50
    
    private let characters = "01アイウエオカキクケコサシスセソタチツテト"
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                Text(String(characters.randomElement() ?? "0"))
                    .font(.system(size: 12, weight: .light, design: .monospaced))
                    .foregroundStyle(
                        CyberpunkTheme.neonGreen.opacity(
                            1.0 - Double(index) * 0.05
                        )
                    )
            }
        }
        .position(x: column.xPosition, y: offset)
        .onAppear {
            withAnimation(
                Animation.linear(duration: Double.random(in: 5...10))
                    .delay(column.delay)
                    .repeatForever(autoreverses: false)
            ) {
                offset = height + 200
            }
        }
    }
}

/// Glitch Effect for text and UI elements
public struct GlitchEffect: ViewModifier {
    @State private var offset1: CGFloat = 0
    @State private var offset2: CGFloat = 0
    @State private var isGlitching = false
    
    public func body(content: Content) -> some View {
        ZStack {
            content
                .foregroundStyle(CyberpunkTheme.neonCyan)
                .offset(x: isGlitching ? offset1 : 0)
                .opacity(isGlitching ? 0.8 : 0)
            
            content
                .foregroundStyle(CyberpunkTheme.neonMagenta)
                .offset(x: isGlitching ? offset2 : 0)
                .opacity(isGlitching ? 0.8 : 0)
            
            content
        }
        .onAppear {
            startGlitchAnimation()
        }
    }
    
    private func startGlitchAnimation() {
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 3...8), repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                isGlitching = true
                offset1 = CGFloat.random(in: -2...2)
                offset2 = CGFloat.random(in: -2...2)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.05)) {
                    isGlitching = false
                    offset1 = 0
                    offset2 = 0
                }
            }
        }
    }
}

/// Loading Spinner with cyberpunk aesthetic
public struct CyberpunkLoadingSpinner: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    let size: CGFloat
    
    public init(size: CGFloat = 50) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            CyberpunkTheme.neonCyan,
                            CyberpunkTheme.neonMagenta,
                            CyberpunkTheme.neonBlue,
                            CyberpunkTheme.neonCyan
                        ]),
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
            
            // Inner ring
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            CyberpunkTheme.neonMagenta,
                            CyberpunkTheme.neonCyan,
                            CyberpunkTheme.neonPurple,
                            CyberpunkTheme.neonMagenta
                        ]),
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: size * 0.7, height: size * 0.7)
                .rotationEffect(.degrees(-rotation * 1.5))
                .scaleEffect(scale)
            
            // Center dot
            Circle()
                .fill(CyberpunkTheme.neonCyan)
                .frame(width: size * 0.2, height: size * 0.2)
                .blur(radius: scale == 1.0 ? 0 : 2)
        }
        .onAppear {
            withAnimation(
                .linear(duration: 2)
                    .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
            
            withAnimation(
                .easeInOut(duration: 1)
                    .repeatForever(autoreverses: true)
            ) {
                scale = 1.2
            }
        }
    }
}

// MARK: - View Extensions
public extension View {
    func glitchEffect() -> some View {
        modifier(GlitchEffect())
    }
}