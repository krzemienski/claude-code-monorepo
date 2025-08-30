import SwiftUI

// MARK: - Pulsing Avatar

/// An animated avatar component with pulse effect
public struct PulsingAvatar: View {
    let systemName: String
    let color: Color
    let size: CGFloat
    
    @State private var isPulsing = false
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(
        systemName: String,
        color: Color = Theme.primary,
        size: CGFloat = 40
    ) {
        self.systemName = systemName
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Pulse rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                    .frame(
                        width: Theme.FontSize.adaptive(size) + CGFloat(index * 20),
                        height: Theme.FontSize.adaptive(size) + CGFloat(index * 20)
                    )
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                        value: isPulsing
                    )
            }
            
            // Avatar circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: Theme.FontSize.adaptive(size),
                    height: Theme.FontSize.adaptive(size)
                )
            
            // Icon
            Image(systemName: systemName)
                .font(.system(size: Theme.FontSize.adaptive(size * 0.5)))
                .foregroundStyle(.white)
                .scaleEffect(isPulsing ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isPulsing)
        }
        .onAppear {
            isPulsing = true
        }
        .accessibilityElement(
            label: "Avatar",
            traits: .isImage
        )
    }
}

// MARK: - Animated Card

/// A card component with hover and press animations
public struct AnimatedCard<Content: View>: View {
    let content: () -> Content
    var padding: CGFloat = Theme.Spacing.md
    var cornerRadius: CGFloat = Theme.CornerRadius.lg
    
    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(
        padding: CGFloat = Theme.Spacing.md,
        cornerRadius: CGFloat = Theme.CornerRadius.lg,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content
    }
    
    public var body: some View {
        content()
            .padding(Theme.Spacing.adaptive(padding))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.card,
                                isHovered ? Theme.card.opacity(0.9) : Theme.card.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: Theme.primary.opacity(isHovered ? 0.2 : 0.1),
                        radius: isPressed ? 4 : 8,
                        x: 0,
                        y: isPressed ? 2 : 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Theme.primary.opacity(isHovered ? 0.4 : 0.2),
                                Theme.border
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 2 : 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
    }
}

// MARK: - Shimmering Text

/// Text with a shimmering animation effect
public struct ShimmeringText: View {
    let text: String
    let font: Font
    let gradient: LinearGradient
    
    @State private var shimmerOffset: CGFloat = -1
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(
        _ text: String,
        font: Font = .title,
        gradient: LinearGradient? = nil
    ) {
        self.text = text
        self.font = font
        self.gradient = gradient ?? LinearGradient(
            colors: [
                Theme.primary.opacity(0.3),
                Theme.primary,
                Theme.primary.opacity(0.3)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    public var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Theme.foreground)
            .overlay(
                GeometryReader { geometry in
                    Text(text)
                        .font(font)
                        .foregroundStyle(gradient)
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.clear,
                                            Color.white,
                                            Color.clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * 0.3)
                                .offset(x: geometry.size.width * shimmerOffset)
                        )
                }
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 2)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerOffset = 2
                }
            }
            .accessibilityElement(
                label: text,
                traits: .isStaticText
            )
    }
}

// MARK: - Animated Progress Bar

/// A progress bar with smooth animations and gradient effects
public struct AnimatedProgressBar: View {
    let progress: Double
    let total: Double
    var height: CGFloat = 8
    var showLabel: Bool = true
    
    @State private var animatedProgress: Double = 0
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(
        progress: Double,
        total: Double = 1.0,
        height: CGFloat = 8,
        showLabel: Bool = true
    ) {
        self.progress = progress
        self.total = total
        self.height = height
        self.showLabel = showLabel
    }
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return min(max(progress / total, 0), 1)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.adaptive(Theme.Spacing.xs)) {
            if showLabel {
                HStack {
                    Text("\(Int(percentage * 100))%")
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                        .foregroundStyle(Theme.foreground)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(progress)) / \(Int(total))")
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                        .foregroundStyle(Theme.mutedFg)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: height / 2)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.primary,
                                    Theme.primary.opacity(0.7),
                                    Theme.neonCyan
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * animatedProgress)
                        .overlay(
                            // Glow effect
                            RoundedRectangle(cornerRadius: height / 2)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animatedProgress)
                }
            }
            .frame(height: height)
        }
        .onAppear {
            animatedProgress = percentage
        }
        .onChange(of: percentage) { newValue in
            animatedProgress = newValue
        }
        .accessibilityElement(
            label: "Progress",
            value: "\(Int(percentage * 100)) percent complete"
        )
    }
}

// MARK: - Animated Tab Bar

/// A custom tab bar with animated selection indicator
public struct AnimatedTabBar<Selection: Hashable>: View {
    @Binding var selection: Selection
    let items: [(label: String, icon: String, value: Selection)]
    
    @Namespace private var tabBarNamespace
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(
        selection: Binding<Selection>,
        items: [(label: String, icon: String, value: Selection)]
    ) {
        self._selection = selection
        self.items = items
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.value) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = item.value
                    }
                } label: {
                    VStack(spacing: Theme.Spacing.adaptive(Theme.Spacing.xs)) {
                        Image(systemName: item.icon)
                            .font(.system(size: Theme.FontSize.adaptive(Theme.FontSize.xl)))
                            .scaleEffect(selection == item.value ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: selection == item.value)
                        
                        Text(item.label)
                            .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                    }
                    .foregroundStyle(
                        selection == item.value ? Theme.primary : Theme.mutedFg
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.adaptive(Theme.Spacing.sm))
                    .background(
                        ZStack {
                            if selection == item.value {
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .fill(Theme.primary.opacity(0.1))
                                    .matchedGeometryEffect(
                                        id: "tabSelection",
                                        in: tabBarNamespace
                                    )
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityElement(
                    label: item.label,
                    traits: selection == item.value ? [.isButton, .isSelected] : .isButton
                )
            }
        }
        .padding(Theme.Spacing.adaptive(Theme.Spacing.xs))
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .stroke(Theme.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - Typing Animation Text

/// Text that appears with a typing animation
public struct TypingAnimationText: View {
    let text: String
    let speed: Double
    
    @State private var displayedText = ""
    @State private var currentIndex = 0
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(
        _ text: String,
        speed: Double = 0.05
    ) {
        self.text = text
        self.speed = speed
    }
    
    public var body: some View {
        Text(displayedText)
            .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
            .foregroundStyle(Theme.foreground)
            .onAppear {
                animateText()
            }
            .onChange(of: text) { _ in
                displayedText = ""
                currentIndex = 0
                animateText()
            }
            .accessibilityElement(
                label: text,
                traits: .updatesFrequently
            )
    }
    
    private func animateText() {
        guard currentIndex < text.count else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            let index = text.index(text.startIndex, offsetBy: currentIndex)
            displayedText.append(text[index])
            currentIndex += 1
            animateText()
        }
    }
}

// MARK: - Preview Provider

struct AnimatedComponents_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 30) {
                PulsingAvatar(systemName: "person.fill", color: Theme.neonCyan)
                
                AnimatedCard {
                    Text("Animated Card Content")
                        .padding()
                }
                
                ShimmeringText("Shimmering Title", font: .largeTitle)
                
                AnimatedProgressBar(progress: 0.7, total: 1.0)
                    .padding(.horizontal)
                
                AnimatedTabBar(
                    selection: .constant(0),
                    items: [
                        ("Home", "house.fill", 0),
                        ("Search", "magnifyingglass", 1),
                        ("Profile", "person.fill", 2)
                    ]
                )
                .padding(.horizontal)
                
                TypingAnimationText("This text appears with a typing animation effect...")
            }
            .padding()
        }
        .background(Theme.background)
        .previewDisplayName("Animated Components")
    }
}