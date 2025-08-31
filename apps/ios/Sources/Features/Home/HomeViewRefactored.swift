import SwiftUI
import Charts

/// Refactored HomeView using modern NavigationStack and componentized architecture
public struct HomeViewRefactored: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    @StateObject private var settings = AppSettings()
    
    // Environment values
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorContrast
    
    // Animation states
    @State private var showWelcome = false
    @State private var selectedSection: HomeSection? = nil
    @State private var glowAnimation = false
    @State private var backgroundParticles = true
    
    public var body: some View {
        AppNavigationStack {
            ZStack {
                // Cyberpunk background with particle effects
                if !reduceMotion && backgroundParticles {
                    ParticleEffectsView(particleCount: 30)
                        .opacity(0.3)
                        .allowsHitTesting(false)
                }
                
                contentView
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            HeaderComponent(
                                isLoading: $viewModel.isLoading,
                                settingsAction: navigateToSettings
                            )
                            .holographicEffect()
                        }
                    }
            }
            .background(CyberpunkTheme.darkBackground)
            .task {
                await loadInitialData()
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        glowAnimation = true
                    }
                }
            }
            .refreshable {
                CyberpunkTheme.mediumImpact()
                await viewModel.refresh()
            }
        }
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if horizontalSizeClass == .regular {
            // iPad Layout
            AdaptiveSplitView(
                sidebar: {
                    sidebarContent
                },
                detail: {
                    detailContent
                }
            )
        } else {
            // iPhone Layout
            ScrollView {
                mainContent
            }
            .background(Theme.background)
        }
    }
    
    // MARK: - Sidebar Content (iPad)
    @ViewBuilder
    private var sidebarContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                welcomeSection
                quickActionsSection
                recentSessionsSection
                statusSection
            }
            .padding()
        }
        .background(Theme.background)
    }
    
    // MARK: - Detail Content (iPad)
    @ViewBuilder
    private var detailContent: some View {
        if let section = selectedSection {
            sectionDetailView(for: section)
        } else {
            ContentUnavailableView(
                "Select an Item",
                systemImage: "sidebar.left",
                description: Text("Choose an item from the sidebar to view details")
            )
        }
    }
    
    // MARK: - Main Content (iPhone)
    @ViewBuilder
    private var mainContent: some View {
        LazyVStack(spacing: 32) {
            welcomeSection
            quickActionsSection
            recentSessionsSection
            metricsSection
            statusSection
        }
        .padding()
    }
    
    // MARK: - Welcome Section
    @ViewBuilder
    private var welcomeSection: some View {
        if showWelcome {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(greetingText)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(CyberpunkTheme.neonGradient)
                            .glitchEffect()
                            .neonGlow(color: CyberpunkTheme.neonCyan, intensity: 3)
                        
                        Text("What would you like to work on today?")
                            .font(.system(size: 14, weight: .light, design: .monospaced))
                            .foregroundStyle(CyberpunkTheme.neonMagenta.opacity(0.8))
                    }
                    
                    Spacer()
                }
                
                // Quick Stats with cyberpunk styling
                HStack(spacing: 16) {
                    EnhancedStatCard(
                        value: "\(viewModel.sessions.count)",
                        label: "SESSIONS",
                        icon: "bubble.left.and.bubble.right",
                        color: CyberpunkTheme.neonCyan,
                        glowAnimation: glowAnimation
                    )
                    
                    EnhancedStatCard(
                        value: "\(viewModel.projects.count)",
                        label: "PROJECTS",
                        icon: "folder",
                        color: CyberpunkTheme.neonMagenta,
                        glowAnimation: glowAnimation
                    )
                    
                    EnhancedStatCard(
                        value: formatTokenCount(viewModel.stats?.totalTokens ?? 0),
                        label: "TOKENS",
                        icon: "bolt",
                        color: CyberpunkTheme.neonGreen,
                        glowAnimation: glowAnimation
                    )
                }
            }
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
            .onTapGesture {
                CyberpunkTheme.lightImpact()
            }
        }
    }
    
    // MARK: - Quick Actions Section
    @ViewBuilder
    private var quickActionsSection: some View {
        QuickActionsComponent(
            actions: createQuickActions(),
            columns: horizontalSizeClass == .regular ? 4 : 2
        )
    }
    
    // MARK: - Recent Sessions Section
    @ViewBuilder
    private var recentSessionsSection: some View {
        APISessionListComponent(
            sessions: viewModel.activeSessions,
            onSessionTap: { session in
                navigationCoordinator.navigate(to: .session(session.id))
            },
            onNewSession: {
                navigationCoordinator.presentSheet(.newSession)
            }
        )
    }
    
    // MARK: - Metrics Section
    @ViewBuilder
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Performance Metrics", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(Theme.primary)
            
            // MetricsChart placeholder
            Text("Performance metrics")
                .foregroundStyle(Theme.mutedFg)
                .frame(height: 200)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.backgroundSecondary)
                )
        }
    }
    
    // MARK: - Status Section
    @ViewBuilder
    private var statusSection: some View {
        AnimatedStatusBar()
            .scanlineEffect()
    }
    
    // MARK: - Helper Methods
    private func createQuickActions() -> [QuickAction] {
        [
            QuickAction(
                title: "New Session",
                icon: "plus.bubble",
                color: .blue
            ) {
                navigationCoordinator.presentSheet(.newSession)
            },
            
            QuickAction(
                title: "Browse Files",
                icon: "folder",
                color: .orange,
                badge: nil
            ) {
                navigationCoordinator.navigate(to: .file(""))
            },
            
            QuickAction(
                title: "Analytics",
                icon: "chart.bar",
                color: .green
            ) {
                navigationCoordinator.navigate(to: .analytics)
            },
            
            QuickAction(
                title: "Settings",
                icon: "gearshape",
                color: .gray
            ) {
                navigateToSettings()
            }
        ]
    }
    
    private func navigateToSettings() {
        navigationCoordinator.navigate(to: .settings)
    }
    
    private func loadInitialData() async {
        await viewModel.loadData()
        withAnimation(.easeInOut) {
            showWelcome = true
        }
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    @ViewBuilder
    private func sectionDetailView(for section: HomeSection) -> some View {
        switch section {
        case .sessions:
            SessionsDetailView()
        case .projects:
            ProjectsDetailView()
        case .analytics:
            AnalyticsView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Supporting Types
private enum HomeSection {
    case sessions
    case projects
    case analytics
    case settings
}

// Enhanced stat card with cyberpunk styling
private struct EnhancedStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    let glowAnimation: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .scaleEffect(glowAnimation && isHovered ? 1.2 : 1.0)
                    .opacity(glowAnimation && isHovered ? 0.5 : 1.0)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
                    .neonGlow(color: color, intensity: 2)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(color.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(CyberpunkTheme.darkCard)
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.6), color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blur(radius: isHovered ? 2 : 0)
            }
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
            if hovering {
                CyberpunkTheme.lightImpact()
            }
        }
    }
}

// Keep the original StatCard for backward compatibility
private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.backgroundSecondary)
        )
    }
}

// ChartMetric for chart visualization
private struct ChartMetric: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

private struct MetricsChart: View {
    let metrics: [ChartMetric]
    
    var body: some View {
        Chart(metrics) { metric in
            LineMark(
                x: .value("Time", metric.timestamp),
                y: .value("Performance", metric.value)
            )
            .foregroundStyle(Theme.primary)
            .interpolationMethod(.catmullRom)
            
            AreaMark(
                x: .value("Time", metric.timestamp),
                y: .value("Performance", metric.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.primary.opacity(0.3), Theme.primary.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

// MARK: - Preview Provider
struct HomeViewRefactored_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomeViewRefactored()
                .previewDisplayName("iPhone")
                .previewDevice("iPhone 15 Pro")
            
            HomeViewRefactored()
                .previewDisplayName("iPad")
                .previewDevice("iPad Pro (11-inch)")
        }
    }
}