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
    
    public var body: some View {
        AppNavigationStack {
            contentView
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HeaderComponent(
                            isLoading: $viewModel.isLoading,
                            settingsAction: navigateToSettings
                        )
                    }
                }
                .task {
                    await loadInitialData()
                }
                .refreshable {
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
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.primary, Theme.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("What would you like to work on today?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Quick Stats
                HStack(spacing: 16) {
                    StatCard(
                        value: "\(viewModel.sessionCount)",
                        label: "Sessions",
                        icon: "bubble.left.and.bubble.right",
                        color: .blue
                    )
                    
                    StatCard(
                        value: "\(viewModel.projectCount)",
                        label: "Projects",
                        icon: "folder",
                        color: .orange
                    )
                    
                    StatCard(
                        value: formatTokenCount(viewModel.totalTokens),
                        label: "Tokens",
                        icon: "bolt",
                        color: .green
                    )
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
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
        SessionListComponent(
            sessions: viewModel.recentSessions,
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
            
            MetricsChart(metrics: viewModel.performanceMetrics)
                .frame(height: 200)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.secondaryBackground)
                )
        }
    }
    
    // MARK: - Status Section
    @ViewBuilder
    private var statusSection: some View {
        StatusBarComponent(
            metrics: SystemMetrics(
                tokenUsage: TokenUsage(
                    used: viewModel.tokensUsed,
                    limit: viewModel.tokenLimit
                ),
                memoryUsage: MemoryUsage(
                    used: viewModel.memoryUsed,
                    total: viewModel.memoryTotal
                ),
                performanceScore: viewModel.performanceScore
            ),
            isConnected: viewModel.isConnected,
            syncStatus: viewModel.syncStatus
        )
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
                badge: viewModel.unreadFileCount > 0 ? "\(viewModel.unreadFileCount)" : nil
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
                .fill(Theme.secondaryBackground)
        )
    }
}

private struct MetricsChart: View {
    let metrics: [PerformanceMetric]
    
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