import SwiftUI

/// Reusable card component for home view sections
/// Provides consistent styling and animations for all home cards
struct HomeCardComponent<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content
    
    // MARK: - State
    @State private var pulseAnimation = false
    @State private var isExpanded = true
    
    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header
            cardHeader
            
            // Content
            if isExpanded {
                content()
                    .transition(expandTransition)
            }
        }
        .padding(cardPadding)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: 5
        )
        .onAppear {
            startAnimations()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
    }
    
    // MARK: - Subviews
    private var cardHeader: some View {
        HStack {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .opacity(pulseAnimation ? 0.5 : 1.0)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .animation(pulseAnimationStyle, value: pulseAnimation)
            
            // Title
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.foreground)
            
            Spacer()
            
            // Expand/Collapse button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
                    .frame(width: 24, height: 24)
                    .background(Theme.background.opacity(0.3))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
            .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand") this section")
        }
    }
    
    // MARK: - Styling
    @ViewBuilder
    private var cardBackground: some View {
        ZStack {
            if reduceTransparency {
                Theme.card
            } else {
                Theme.card.opacity(0.95)
            }
            
            LinearGradient(
                colors: [iconColor.opacity(0.1), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                LinearGradient(
                    colors: [iconColor.opacity(0.4), Theme.border],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    // MARK: - Computed Properties
    private var cardPadding: CGFloat {
        horizontalSizeClass == .regular ? Theme.Spacing.lg : Theme.Spacing.md
    }
    
    private var shadowColor: Color {
        reduceTransparency ? .clear : iconColor.opacity(0.2)
    }
    
    private var shadowRadius: CGFloat {
        reduceTransparency ? 0 : 10
    }
    
    private var expandTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        } else {
            return .asymmetric(
                insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
            )
        }
    }
    
    private var pulseAnimationStyle: Animation? {
        if reduceMotion {
            return .none
        } else {
            return Animation.easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
        }
    }
    
    // MARK: - Helper Functions
    private func startAnimations() {
        guard !reduceMotion else { return }
        withAnimation {
            pulseAnimation = true
        }
    }
}

// MARK: - Preview
struct HomeCardComponent_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.xl) {
            HomeCardComponent(
                title: "Recent Activity",
                icon: "clock.fill",
                iconColor: Color(h: 280, s: 100, l: 50)
            ) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(0..<3) { index in
                        HStack {
                            Text("Activity \(index + 1)")
                                .font(.subheadline)
                            Spacer()
                            Text("2m ago")
                                .font(.caption)
                                .foregroundStyle(Theme.mutedFg)
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                        
                        if index < 2 {
                            Divider()
                        }
                    }
                }
            }
            
            HomeCardComponent(
                title: "Statistics",
                icon: "chart.bar.fill",
                iconColor: Color(h: 180, s: 100, l: 50)
            ) {
                HStack(spacing: Theme.Spacing.lg) {
                    statItem(label: "Total", value: "42")
                    statItem(label: "Active", value: "7")
                    statItem(label: "Complete", value: "35")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Theme.background)
    }
    
    static func statItem(label: String, value: String) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.primary)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
        }
        .frame(maxWidth: .infinity)
    }
}