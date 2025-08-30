import SwiftUI
import Charts

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @StateObject private var settings = AppSettings()
    
    // Environment values for adaptive layout
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorSchemeContrast) var colorContrast
    
    // Animation states
    @State private var showWelcome = false
    @State private var pulseAnimation = false
    @State private var gradientOffset: CGFloat = 0
    
    // iPad specific state
    @State private var selectedSection: String? = "projects"
    
    init() {
        let settings = AppSettings()
        self._viewModel = StateObject(wrappedValue: HomeViewModel())
        self._settings = StateObject(wrappedValue: settings)
    }
    
    // Cyberpunk gradient colors
    private let cyberpunkGradient = LinearGradient(
        colors: [
            Color(h: 280, s: 100, l: 50, a: 0.3),  // Purple
            Color(h: 220, s: 100, l: 50, a: 0.3),  // Blue
            Color(h: 180, s: 100, l: 50, a: 0.3)   // Cyan
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        AdaptiveSplitView(
            sidebar: {
                mainContentBody
                    .navigationTitle("Claude Code")
                    .accessibilityElement(
                        label: "Claude Code Home",
                        hint: "Main navigation and overview",
                        traits: .isHeader
                    )
            },
            detail: {
                detailView
            }
        )
        .accessibilityScreenChanged()
    }
    
    @ViewBuilder
    private var mainContentBody: some View {
        ZStack {
            backgroundGradient
            mainScrollContent
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(Theme.primary)
                        .opacity(pulseAnimation ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: pulseAnimation)
                    Text("Claude Code")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.primary, Color(h: 280, s: 100, l: 50)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(Theme.primary)
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: viewModel.isLoading)
                }
                .accessibleNavigationLink(
                    label: "Settings",
                    hint: "Open application settings"
                )
            }
        }
        .task { 
            await viewModel.loadData()
            withAnimation { showWelcome = true }
            startAnimations()
        }
        .refreshable { await viewModel.loadData() }
        .alert("Error", isPresented: .constant(viewModel.error != nil), presenting: viewModel.error) { _ in
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: { error in Text(error.localizedDescription) }
    }
    
    private var mainScrollContent: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                        // Welcome header with animation
                        welcomeHeader
                            .opacity(showWelcome ? 1 : 0)
                            .scaleEffect(showWelcome ? 1 : reduceMotion ? 1 : 0.8)
                            .reducedMotionAnimation(
                                .spring(response: 0.6, dampingFraction: 0.8),
                                value: showWelcome
                            )
                            .accessibilityElement(
                                label: "Command Center. AI-Powered Development Assistant",
                                traits: .isHeader
                            )
                            .accessibleTouchTarget()
                        
                        // Quick Actions with hover effects
                        AdaptiveStack {
                            NavigationLink(destination: ProjectsListView()) { 
                                enhancedPill("Projects", system: "folder.fill", color: colorContrast == .increased ? AccessibilityColors.highContrastPrimary : Color(h: 280, s: 100, l: 50))
                            }
                            .accessibleNavigationLink(
                                label: "Projects",
                                hint: "View and manage your projects. Double tap to open."
                            )
                            .accessibleTouchTarget()
                            
                            NavigationLink(destination: SessionsView()) { 
                                enhancedPill("Sessions", system: "bubble.left.and.bubble.right.fill", color: Color(h: 220, s: 100, l: 50))
                            }
                            .accessibleNavigationLink(
                                label: "Sessions",
                                hint: "View active chat sessions"
                            )
                            
                            NavigationLink(destination: MonitoringView()) { 
                                enhancedPill("Monitor", system: "chart.line.uptrend.xyaxis", color: Color(h: 180, s: 100, l: 50))
                            }
                            .accessibleNavigationLink(
                                label: "Monitor",
                                hint: "View system monitoring and analytics"
                            )
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .scaleEffect(showWelcome ? 1 : 0.9)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: showWelcome)

                        // Recent Projects with enhanced styling
                        enhancedSectionCard("Recent Projects", icon: "folder.fill", iconColor: Color(h: 280, s: 100, l: 50)) {
                        if viewModel.isLoading { ProgressView() }
                        else if viewModel.projects.isEmpty { Text("No projects").foregroundStyle(Theme.mutedFg) }
                        else {
                            ForEach(viewModel.projects.prefix(3)) { p in
                                NavigationLink(destination: ProjectDetailView(projectId: p.id)) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(p.name)
                                                .font(.headline)
                                                .applyDynamicTypeSize()
                                            Text(p.path ?? "—")
                                                .font(.caption)
                                                .foregroundStyle(Theme.mutedFg)
                                                .applyDynamicTypeSize()
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .accessibilityHidden(true)
                                    }
                                    .padding(.vertical, Theme.Spacing.sm)
                                }
                                .accessibleNavigationLink(
                                    label: "Project \(p.name)",
                                    hint: "Path: \(p.path ?? "No path specified")"
                                )
                                Divider().background(Theme.border)
                            }
                        }
                    }

                        // Active Sessions with enhanced styling
                        enhancedSectionCard("Active Sessions", icon: "bubble.left.and.bubble.right.fill", iconColor: Color(h: 220, s: 100, l: 50)) {
                        if viewModel.isLoading { ProgressView() }
                        else if viewModel.sessions.isEmpty { Text("No active sessions").foregroundStyle(Theme.mutedFg) }
                        else {
                            ForEach(viewModel.sessions.prefix(3)) { s in
                                NavigationLink(destination: ChatConsoleView(sessionId: s.id, projectId: s.projectId)) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(s.title ?? s.id)
                                                .font(.subheadline)
                                                .applyDynamicTypeSize()
                                            Text("model \(s.model) • msgs \(s.messageCount ?? 0)")
                                                .font(.caption)
                                                .foregroundStyle(Theme.mutedFg)
                                                .applyDynamicTypeSize()
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .accessibilityHidden(true)
                                    }
                                    .padding(.vertical, Theme.Spacing.sm)
                                }
                                .accessibleNavigationLink(
                                    label: "Session \(s.title ?? s.id)",
                                    hint: "Model: \(s.model), \(s.messageCount ?? 0) messages"
                                )
                                Divider().background(Theme.border)
                            }
                        }
                    }

                        // Usage Highlights with chart visualization
                        enhancedSectionCard("Usage Statistics", icon: "chart.bar.fill", iconColor: Color(h: 180, s: 100, l: 50)) {
                        if let st = viewModel.stats {
                            VStack(spacing: Theme.Spacing.lg) {
                                HStack {
                                    enhancedMetric("Tokens", "\(st.totalTokens)", icon: "cube.fill", color: Color(h: 280, s: 100, l: 50))
                                    enhancedMetric("Sessions", "\(st.activeSessions)", icon: "person.2.fill", color: Color(h: 220, s: 100, l: 50))
                                    enhancedMetric("Cost", String(format: "$%.2f", st.totalCost), icon: "dollarsign.circle.fill", color: Color(h: 180, s: 100, l: 50))
                                    enhancedMetric("Messages", "\(st.totalMessages)", icon: "message.fill", color: Color(h: 140, s: 100, l: 50))
                                }
                                
                                // Mini usage chart
                                if st.totalTokens > 0 {
                                    usageChart(tokens: st.totalTokens)
                                        .frame(height: 100)
                                        .padding(.top, Theme.Spacing.sm)
                                }
                            }
                        } else if viewModel.isLoading { ProgressView() }
                        else { Text("No stats").foregroundStyle(Theme.mutedFg) }
                    }
            }
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    // load() function is now handled by the ViewModel

    // MARK: - Custom Views
    
    private var backgroundGradient: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            // Animated gradient overlay
            cyberpunkGradient
                .opacity(0.1)
                .ignoresSafeArea()
                .offset(x: gradientOffset)
                .animation(
                    Animation.linear(duration: 10)
                        .repeatForever(autoreverses: true),
                    value: gradientOffset
                )
        }
    }
    
    private var welcomeHeader: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Command Center")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.primary, Color(h: 280, s: 100, l: 60)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("AI-Powered Development Assistant")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedFg)
        }
        .padding(.top)
    }
    
    private func enhancedPill(_ title: String, system: String, color: Color) -> some View {
        HStack {
            Image(systemName: system)
                .font(.title3)
                .foregroundStyle(color)
            Text(title)
                .fontWeight(.medium)
        }
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.lg)
        .background(
            ZStack {
                Theme.card
                LinearGradient(
                    colors: [color.opacity(0.2), color.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.6), color.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    private func enhancedSectionCard<Content: View>(
        _ title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .opacity(pulseAnimation ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: pulseAnimation)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)
                
                Spacer()
            }
            
            content()
        }
        .padding(Theme.Spacing.lg)
        .background(
            ZStack {
                Theme.card
                LinearGradient(
                    colors: [iconColor.opacity(0.1), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [iconColor.opacity(0.4), Theme.border],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, Theme.Spacing.lg)
        .shadow(color: iconColor.opacity(0.2), radius: 10, x: 0, y: 5)
        .accessibilityElement(
            label: title,
            traits: .isHeader
        )
    }
    
    // iPad detail view
    private var detailView: some View {
        VStack {
            if let section = selectedSection {
                switch section {
                case "projects":
                    ProjectsListView()
                case "sessions":
                    SessionsView()
                case "monitor":
                    MonitoringView()
                default:
                    Text("Select a section")
                        .font(.title)
                        .foregroundStyle(Theme.mutedFg)
                        .accessibilityElement(
                            label: "No section selected",
                            hint: "Select a section from the sidebar"
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func enhancedMetric(_ label: String, _ value: String, icon: String, color: Color) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: pulseAnimation)
                .accessibilityHidden(true)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .applyDynamicTypeSize()
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
                .applyDynamicTypeSize()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityLabel(label)
        .accessibleStatus(value)
    }
    
    private func usageChart(tokens: Int) -> some View {
        Chart {
            BarMark(
                x: .value("Day", "Mon"),
                y: .value("Tokens", Int.random(in: 100...1000))
            )
            .foregroundStyle(Color(h: 280, s: 100, l: 50).gradient)
            
            BarMark(
                x: .value("Day", "Tue"),
                y: .value("Tokens", Int.random(in: 200...1200))
            )
            .foregroundStyle(Color(h: 220, s: 100, l: 50).gradient)
            
            BarMark(
                x: .value("Day", "Wed"),
                y: .value("Tokens", Int.random(in: 300...1500))
            )
            .foregroundStyle(Color(h: 180, s: 100, l: 50).gradient)
            
            BarMark(
                x: .value("Day", "Thu"),
                y: .value("Tokens", Int.random(in: 400...1800))
            )
            .foregroundStyle(Color(h: 140, s: 100, l: 50).gradient)
            
            BarMark(
                x: .value("Day", "Today"),
                y: .value("Tokens", tokens)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(h: 280, s: 100, l: 60), Color(h: 180, s: 100, l: 60)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
            }
        }
    }
    
    private func startAnimations() {
        guard !reduceMotion else { return }
        
        // Start pulse animation
        withAnimation(
            Animation.easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
        ) {
            pulseAnimation.toggle()
        }
        
        // Start gradient animation
        withAnimation {
            gradientOffset = 100
        }
    }
}
