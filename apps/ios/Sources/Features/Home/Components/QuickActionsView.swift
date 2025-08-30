import SwiftUI

/// Quick actions component for home view
/// Displays navigation pills with cyberpunk styling
struct QuickActionsView: View {
    let showWelcome: Bool
    
    // MARK: - Environment
    @Environment(\.colorSchemeContrast) var colorContrast
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // MARK: - State
    @State private var hoveredAction: String?
    
    // MARK: - Body
    var body: some View {
        AdaptiveStack(spacing: Theme.Spacing.md) {
            NavigationLink(destination: ProjectsListView()) {
                actionPill(
                    title: "Projects",
                    icon: "folder.fill",
                    color: projectsColor,
                    isHovered: hoveredAction == "projects"
                )
            }
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.2)) {
                    hoveredAction = isHovered ? "projects" : nil
                }
            }
            .accessibleNavigationLink(
                label: "Projects",
                hint: "View and manage your projects. Double tap to open."
            )
            .accessibleTouchTarget()
            
            NavigationLink(destination: SessionsView()) {
                actionPill(
                    title: "Sessions",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: sessionsColor,
                    isHovered: hoveredAction == "sessions"
                )
            }
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.2)) {
                    hoveredAction = isHovered ? "sessions" : nil
                }
            }
            .accessibleNavigationLink(
                label: "Sessions",
                hint: "View active chat sessions. Double tap to open."
            )
            .accessibleTouchTarget()
            
            NavigationLink(destination: MonitoringView()) {
                actionPill(
                    title: "Monitor",
                    icon: "chart.line.uptrend.xyaxis",
                    color: monitorColor,
                    isHovered: hoveredAction == "monitor"
                )
            }
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.2)) {
                    hoveredAction = isHovered ? "monitor" : nil
                }
            }
            .accessibleNavigationLink(
                label: "Monitor",
                hint: "View system monitoring and analytics. Double tap to open."
            )
            .accessibleTouchTarget()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .scaleEffect(showWelcome ? 1 : 0.9)
        .opacity(showWelcome ? 1 : 0)
        .animation(
            reduceMotion ? .none :
            .spring(response: 0.5, dampingFraction: 0.7).delay(0.2),
            value: showWelcome
        )
    }
    
    // MARK: - Subviews
    private func actionPill(
        title: String,
        icon: String,
        color: Color,
        isHovered: Bool
    ) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            
            Text(title)
                .fontWeight(.medium)
                .foregroundStyle(Theme.foreground)
        }
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal, horizontalSizeClass == .regular ? Theme.Spacing.lg : Theme.Spacing.md)
        .background(pillBackground(for: color, isHovered: isHovered))
        .overlay(pillBorder(for: color, isHovered: isHovered))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: isHovered ? color.opacity(0.4) : color.opacity(0.3),
            radius: isHovered ? 12 : 8,
            x: 0,
            y: isHovered ? 6 : 4
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
    }
    
    // MARK: - Styling
    private func pillBackground(for color: Color, isHovered: Bool) -> some View {
        ZStack {
            Theme.card
            
            LinearGradient(
                colors: [
                    color.opacity(isHovered ? 0.3 : 0.2),
                    color.opacity(isHovered ? 0.1 : 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func pillBorder(for color: Color, isHovered: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                LinearGradient(
                    colors: [
                        color.opacity(isHovered ? 0.8 : 0.6),
                        color.opacity(isHovered ? 0.4 : 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isHovered ? 2 : 1
            )
    }
    
    // MARK: - Colors
    private var projectsColor: Color {
        colorContrast == .increased ?
        AccessibilityColors.highContrastPrimary :
        Color(h: 280, s: 100, l: 50)
    }
    
    private var sessionsColor: Color {
        Color(h: 220, s: 100, l: 50)
    }
    
    private var monitorColor: Color {
        Color(h: 180, s: 100, l: 50)
    }
}

// MARK: - Preview
struct QuickActionsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.xl) {
            QuickActionsView(showWelcome: true)
            
            QuickActionsView(showWelcome: false)
        }
        .padding()
        .background(Theme.background)
    }
}