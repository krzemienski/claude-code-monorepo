import SwiftUI

// MARK: - Loading Indicator Component

/// A customizable loading indicator with multiple styles and accessibility support
public struct LoadingIndicator: View {
    public enum Style {
        case dots
        case pulse
        case spinner
        case wave
    }
    
    let style: Style
    let color: Color
    let size: CGFloat
    let message: String?
    
    @State private var isAnimating = false
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(
        style: Style = .dots,
        color: Color = Theme.primary,
        size: CGFloat = 8,
        message: String? = nil
    ) {
        self.style = style
        self.color = color
        self.size = size
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: Theme.Spacing.adaptive(Theme.Spacing.md)) {
            Group {
                switch style {
                case .dots:
                    dotsIndicator
                case .pulse:
                    pulseIndicator
                case .spinner:
                    spinnerIndicator
                case .wave:
                    waveIndicator
                }
            }
            .frame(height: size * 3)
            
            if let message = message {
                Text(message)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.mutedFg)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(
            label: message ?? "Loading",
            traits: .updatesFrequently
        )
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
    
    // MARK: - Dots Style
    
    private var dotsIndicator: some View {
        HStack(spacing: size / 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
    }
    
    // MARK: - Pulse Style
    
    private var pulseIndicator: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: size * 2, height: size * 2)
                    .scaleEffect(isAnimating ? 2.5 : 1.0)
                    .opacity(isAnimating ? 0.0 : 0.6)
                    .animation(
                        Animation.easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.5),
                        value: isAnimating
                    )
            }
            
            Circle()
                .fill(color)
                .frame(width: size * 2, height: size * 2)
        }
    }
    
    // MARK: - Spinner Style
    
    private var spinnerIndicator: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    colors: [color.opacity(0), color],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: size / 2, lineCap: .round)
            )
            .frame(width: size * 3, height: size * 3)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                Animation.linear(duration: 1)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
    }
    
    // MARK: - Wave Style
    
    private var waveIndicator: some View {
        HStack(spacing: size / 3) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: size / 4)
                    .fill(color)
                    .frame(width: size / 2, height: size * 3)
                    .scaleEffect(y: isAnimating ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
    }
}

// MARK: - Preview Provider

struct LoadingIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            LoadingIndicator(style: .dots, message: "Loading messages...")
            LoadingIndicator(style: .pulse, color: Theme.neonCyan)
            LoadingIndicator(style: .spinner, color: Theme.neonPink, size: 12)
            LoadingIndicator(style: .wave, color: Theme.neonPurple, message: "Processing...")
        }
        .padding()
        .background(Theme.background)
        .previewDisplayName("Loading Indicators")
    }
}