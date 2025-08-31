import SwiftUI
import Charts

/// 📊 Enhanced Analytics View with Real-time Metrics
public struct EnhancedAnalyticsView: View {
    @StateObject private var metricsViewModel = MetricsViewModel()
    @State private var selectedTimeRange: TimeRange = .hour
    @State private var animateCharts = false
    
    enum TimeRange: String, CaseIterable {
        case hour = "1H"
        case day = "24H"
        case week = "7D"
        case month = "30D"
        
        var displayName: String { rawValue }
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: CyberpunkTheme.Spacing.lg) {
                // Header with time range selector
                headerSection
                
                // Performance metrics cards
                performanceMetricsGrid
                
                // Token usage chart
                tokenUsageChart
                
                // Cost tracking
                costTrackingSection
                
                // Session statistics
                sessionStatsSection
            }
            .padding()
        }
        .background(CyberpunkTheme.Colors.darkBg)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task {
                await metricsViewModel.loadMetrics()
                withAnimation(.easeInOut(duration: 0.8)) {
                    animateCharts = true
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("Real-time Metrics")
                .font(CyberpunkTheme.Fonts.display)
                .cyberpunkGlow(CyberpunkTheme.Colors.neonCyan)
            
            Spacer()
            
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName)
                        .tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .background(CyberpunkTheme.Colors.darkBgSecondary)
            .cyberpunkBorder(CyberpunkTheme.Colors.neonPurple)
        }
        .padding(.vertical)
    }
    
    // MARK: - Performance Metrics Grid
    private var performanceMetricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "FPS",
                value: String(format: "%.0f", metricsViewModel.currentFPS),
                unit: "fps",
                color: CyberpunkTheme.Colors.neonGreen,
                icon: "speedometer"
            )
            
            MetricCard(
                title: "Memory",
                value: String(format: "%.1f", metricsViewModel.memoryUsageMB),
                unit: "MB",
                color: CyberpunkTheme.Colors.neonPink,
                icon: "memorychip"
            )
            
            MetricCard(
                title: "CPU",
                value: String(format: "%.0f", metricsViewModel.cpuUsage),
                unit: "%",
                color: CyberpunkTheme.Colors.neonBlue,
                icon: "cpu"
            )
            
            MetricCard(
                title: "Latency",
                value: String(format: "%.0f", metricsViewModel.apiLatency),
                unit: "ms",
                color: CyberpunkTheme.Colors.electricYellow,
                icon: "network"
            )
        }
    }
    
    // MARK: - Token Usage Chart
    private var tokenUsageChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token Usage")
                .font(CyberpunkTheme.Fonts.heading)
                .cyberpunkGlow(CyberpunkTheme.Colors.neonMagenta)
            
            Chart(metricsViewModel.tokenUsageData) { dataPoint in
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Tokens", dataPoint.tokens)
                )
                .foregroundStyle(CyberpunkTheme.Colors.neonCyan)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                AreaMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Tokens", dataPoint.tokens)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            CyberpunkTheme.Colors.neonCyan.opacity(0.3),
                            CyberpunkTheme.Colors.neonCyan.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: 200)
            .chartYScale(domain: 0...10000)
            .chartXAxis {
                AxisMarks(preset: .aligned)
            }
            .opacity(animateCharts ? 1 : 0)
            .animation(.easeInOut(duration: 0.8), value: animateCharts)
        }
        .padding()
        .background(CyberpunkTheme.Colors.darkBgSecondary)
        .cyberpunkBorder(CyberpunkTheme.Colors.neonCyan)
    }
    
    // MARK: - Cost Tracking Section
    private var costTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Analysis")
                .font(CyberpunkTheme.Fonts.heading)
                .cyberpunkGlow(CyberpunkTheme.Colors.neonGreen)
            
            HStack(spacing: 20) {
                CostMetric(
                    label: "Today",
                    value: metricsViewModel.todayCost,
                    trend: .up(12.5)
                )
                
                CostMetric(
                    label: "This Week",
                    value: metricsViewModel.weekCost,
                    trend: .down(5.2)
                )
                
                CostMetric(
                    label: "This Month",
                    value: metricsViewModel.monthCost,
                    trend: .up(23.7)
                )
            }
        }
        .padding()
        .background(CyberpunkTheme.Colors.darkBgSecondary)
        .cyberpunkBorder(CyberpunkTheme.Colors.neonGreen)
    }
    
    // MARK: - Session Statistics
    private var sessionStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Statistics")
                .font(CyberpunkTheme.Fonts.heading)
                .cyberpunkGlow(CyberpunkTheme.Colors.neonPurple)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatItem(label: "Active", value: "\(metricsViewModel.activeSessions)")
                StatItem(label: "Total", value: "\(metricsViewModel.totalSessions)")
                StatItem(label: "Avg Duration", value: metricsViewModel.avgDuration)
                StatItem(label: "Messages", value: "\(metricsViewModel.totalMessages)")
                StatItem(label: "Tools Used", value: "\(metricsViewModel.toolsExecuted)")
                StatItem(label: "Success Rate", value: "\(metricsViewModel.successRate)%")
            }
        }
        .padding()
        .background(CyberpunkTheme.Colors.darkBgSecondary)
        .cyberpunkBorder(CyberpunkTheme.Colors.neonPurple)
    }
}

// MARK: - Metric Card Component
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
            
            Text(title)
                .font(CyberpunkTheme.Fonts.caption)
                .foregroundStyle(Color.white.opacity(0.7))
            
            HStack(baseline: .bottom, spacing: 4) {
                Text(value)
                    .font(CyberpunkTheme.Fonts.display)
                    .cyberpunkGlow(color)
                
                Text(unit)
                    .font(CyberpunkTheme.Fonts.caption)
                    .foregroundStyle(color.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(CyberpunkTheme.Colors.darkBgTertiary)
        .cyberpunkBorder(color)
        .onAppear {
            withAnimation(CyberpunkTheme.Animations.pulse) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Cost Metric Component
struct CostMetric: View {
    let label: String
    let value: Double
    let trend: Trend
    
    enum Trend {
        case up(Double)
        case down(Double)
        case neutral
        
        var color: Color {
            switch self {
            case .up: return CyberpunkTheme.Colors.neonGreen
            case .down: return CyberpunkTheme.Colors.neonPink
            case .neutral: return CyberpunkTheme.Colors.electricYellow
            }
        }
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
        
        var value: String {
            switch self {
            case .up(let val), .down(let val):
                return String(format: "%.1f%%", val)
            case .neutral:
                return "0%"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(CyberpunkTheme.Fonts.caption)
                .foregroundStyle(Color.white.opacity(0.7))
            
            Text(String(format: "$%.2f", value))
                .font(CyberpunkTheme.Fonts.heading)
                .cyberpunkGlow(CyberpunkTheme.Colors.neonGreen)
            
            HStack(spacing: 4) {
                Image(systemName: trend.icon)
                    .font(.caption)
                Text(trend.value)
                    .font(CyberpunkTheme.Fonts.caption)
            }
            .foregroundStyle(trend.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Stat Item Component
struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(CyberpunkTheme.Fonts.body)
                .cyberpunkGlow(CyberpunkTheme.Colors.neonCyan)
            
            Text(label)
                .font(CyberpunkTheme.Fonts.caption)
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cyberpunk Spacing
extension CyberpunkTheme {
    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let none: CGFloat = 0
    }
}