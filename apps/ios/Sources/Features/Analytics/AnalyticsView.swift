import SwiftUI
import Charts

// MARK: - Analytics View (WF-08)
struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var selectedTimeRange = TimeRange.day
    @State private var selectedMetric = MetricType.sessions
    
    enum TimeRange: String, CaseIterable {
        case hour = "1H"
        case day = "24H"
        case week = "7D"
        case month = "30D"
        
        var title: String {
            switch self {
            case .hour: return "Last Hour"
            case .day: return "Last 24 Hours"
            case .week: return "Last 7 Days"
            case .month: return "Last 30 Days"
            }
        }
    }
    
    enum MetricType: String, CaseIterable {
        case sessions = "Sessions"
        case tokens = "Tokens"
        case costs = "Costs"
        case messages = "Messages"
        
        var icon: String {
            switch self {
            case .sessions: return "person.2.fill"
            case .tokens: return "text.badge.star"
            case .costs: return "dollarsign.circle.fill"
            case .messages: return "message.fill"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                // Header with Time Range Selector
                headerSection
                
                // KPI Cards
                kpiSection
                
                // Main Chart
                chartSection
                
                // Detailed Metrics
                detailedMetricsSection
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadStats()
        }
        .refreshable {
            await viewModel.loadStats()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("Analytics Dashboard")
                .font(Theme.Fonts.title)
                .foregroundColor(Theme.foreground)
            
            Spacer()
            
            // Time Range Picker
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue)
                        .tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 200)
            .onChange(of: selectedTimeRange) { _ in
                Task { await viewModel.loadStats(for: selectedTimeRange) }
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - KPI Section
    private var kpiSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: Theme.Spacing.lg) {
            // Active Sessions
            KPICard(
                title: "Active Sessions",
                value: "\(viewModel.stats?.activeSessions ?? 0)",
                icon: "person.2.fill",
                color: Theme.neonCyan,
                trend: viewModel.sessionsTrend
            )
            
            // Total Tokens
            KPICard(
                title: "Total Tokens",
                value: formatNumber(viewModel.stats?.totalTokens ?? 0),
                icon: "text.badge.star",
                color: Theme.neonPurple,
                trend: viewModel.tokensTrend
            )
            
            // Total Cost
            KPICard(
                title: "Total Cost",
                value: formatCurrency(viewModel.stats?.totalCost ?? 0),
                icon: "dollarsign.circle.fill",
                color: Theme.neonGreen,
                trend: viewModel.costTrend
            )
            
            // Total Messages
            KPICard(
                title: "Messages",
                value: formatNumber(viewModel.stats?.totalMessages ?? 0),
                icon: "message.fill",
                color: Theme.neonBlue,
                trend: viewModel.messagesTrend
            )
        }
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Metric Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(MetricType.allCases, id: \.self) { metric in
                        MetricButton(
                            metric: metric,
                            isSelected: selectedMetric == metric
                        ) {
                            selectedMetric = metric
                        }
                    }
                }
            }
            .padding(.horizontal, -Theme.Spacing.sm)
            
            // Chart View
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.surface)
                .overlay(
                    chartContent
                        .padding()
                )
                .frame(height: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
    }
    
    @ViewBuilder
    private var chartContent: some View {
        if !viewModel.timeSeriesData.isEmpty {
            Chart(viewModel.timeSeriesData) { point in
                switch selectedMetric {
                case .sessions:
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Sessions", point.sessions)
                    )
                    .foregroundStyle(Theme.neonCyan)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value("Sessions", point.sessions)
                    )
                    .foregroundStyle(Theme.neonCyan.opacity(0.1))
                    
                case .tokens:
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Tokens", point.tokens)
                    )
                    .foregroundStyle(Theme.neonPurple)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value("Tokens", point.tokens)
                    )
                    .foregroundStyle(Theme.neonPurple.opacity(0.1))
                    
                case .costs:
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Cost", point.cost)
                    )
                    .foregroundStyle(Theme.neonGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value("Cost", point.cost)
                    )
                    .foregroundStyle(Theme.neonGreen.opacity(0.1))
                    
                case .messages:
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Messages", point.messages)
                    )
                    .foregroundStyle(Theme.neonBlue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value("Messages", point.messages)
                    )
                    .foregroundStyle(Theme.neonBlue.opacity(0.1))
                }
            }
            .chartXAxis {
                AxisMarks(preset: .aligned) { _ in
                    AxisValueLabel()
                        .foregroundStyle(Theme.mutedFg)
                    AxisGridLine()
                        .foregroundStyle(Theme.divider)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Theme.mutedFg)
                    AxisGridLine()
                        .foregroundStyle(Theme.divider)
                }
            }
            .chartBackground { _ in
                Theme.background.opacity(0.5)
            }
        } else {
            VStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.mutedFg.opacity(0.5))
                Text("No data available")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.mutedFg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Detailed Metrics Section
    private var detailedMetricsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Session Details")
                .font(Theme.Fonts.subtitle)
                .foregroundColor(Theme.foreground)
            
            VStack(spacing: Theme.Spacing.md) {
                // Model Usage Breakdown
                if !viewModel.modelUsage.isEmpty {
                    MetricRow(
                        title: "Model Usage",
                        items: viewModel.modelUsage.map { model in
                            MetricItem(
                                label: model.name,
                                value: "\(model.percentage)%",
                                color: model.color
                            )
                        }
                    )
                }
                
                // Token Distribution
                MetricRow(
                    title: "Token Distribution",
                    items: [
                        MetricItem(label: "Input", value: formatNumber(viewModel.inputTokens), color: Theme.neonCyan),
                        MetricItem(label: "Output", value: formatNumber(viewModel.outputTokens), color: Theme.neonPurple),
                        MetricItem(label: "Cached", value: formatNumber(viewModel.cachedTokens), color: Theme.neonGreen)
                    ]
                )
                
                // Average Metrics
                MetricRow(
                    title: "Averages",
                    items: [
                        MetricItem(label: "Tokens/Session", value: formatNumber(viewModel.avgTokensPerSession), color: Theme.neonBlue),
                        MetricItem(label: "Cost/Session", value: formatCurrency(viewModel.avgCostPerSession), color: Theme.neonYellow),
                        MetricItem(label: "Messages/Session", value: "\(viewModel.avgMessagesPerSession)", color: Theme.neonPink)
                    ]
                )
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
    
    // MARK: - Helper Functions
    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

// MARK: - KPI Card Component
struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Spacer()
                
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12))
                        Text(String(format: "%.1f%%", abs(trend)))
                            .font(Theme.Fonts.caption)
                    }
                    .foregroundColor(trend >= 0 ? Theme.success : Theme.error)
                }
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.foreground)
            
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.mutedFg)
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Metric Button Component
struct MetricButton: View {
    let metric: AnalyticsView.MetricType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: metric.icon)
                    .font(.system(size: 14))
                Text(metric.rawValue)
                    .font(Theme.Fonts.caption)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? Theme.accent : Theme.surface)
            .foregroundColor(isSelected ? Theme.accentFg : Theme.mutedFg)
            .cornerRadius(Theme.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Metric Row Component
struct MetricRow: View {
    let title: String
    let items: [MetricItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.mutedFg)
            
            HStack(spacing: Theme.Spacing.lg) {
                ForEach(items, id: \.label) { item in
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        Text(item.label)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.mutedFg)
                        Text(item.value)
                            .font(Theme.Fonts.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.foreground)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

struct MetricItem {
    let label: String
    let value: String
    let color: Color
}

// MARK: - View Model
@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var stats: APIClient.SessionStats?
    @Published var timeSeriesData: [TimeSeriesPoint] = []
    @Published var modelUsage: [ModelUsage] = []
    
    @Published var sessionsTrend: Double = 0
    @Published var tokensTrend: Double = 0
    @Published var costTrend: Double = 0
    @Published var messagesTrend: Double = 0
    
    @Published var inputTokens: Int = 0
    @Published var outputTokens: Int = 0
    @Published var cachedTokens: Int = 0
    
    @Published var avgTokensPerSession: Int = 0
    @Published var avgCostPerSession: Double = 0
    @Published var avgMessagesPerSession: Int = 0
    
    private let settings = AppSettings.shared
    
    struct TimeSeriesPoint: Identifiable {
        let id = UUID()
        let date: Date
        let sessions: Int
        let tokens: Int
        let cost: Double
        let messages: Int
    }
    
    struct ModelUsage: Identifiable {
        let id = UUID()
        let name: String
        let percentage: Int
        let color: Color
    }
    
    func loadStats(for timeRange: AnalyticsView.TimeRange = .day) async {
        guard let client = APIClient(settings: settings) else { return }
        
        do {
            // Load session stats
            stats = try await client.sessionStats()
            
            // Generate mock time series data (replace with real API when available)
            generateTimeSeriesData(for: timeRange)
            
            // Calculate trends (mock data for now)
            calculateTrends()
            
            // Generate model usage breakdown (mock data)
            generateModelUsage()
            
            // Calculate token distribution (mock data)
            calculateTokenDistribution()
            
            // Calculate averages
            calculateAverages()
            
        } catch {
            print("Failed to load analytics: \(error)")
        }
    }
    
    private func generateTimeSeriesData(for timeRange: AnalyticsView.TimeRange) {
        // Generate mock time series data
        let now = Date()
        var data: [TimeSeriesPoint] = []
        
        let points: Int
        let interval: TimeInterval
        
        switch timeRange {
        case .hour:
            points = 12
            interval = 300 // 5 minutes
        case .day:
            points = 24
            interval = 3600 // 1 hour
        case .week:
            points = 7
            interval = 86400 // 1 day
        case .month:
            points = 30
            interval = 86400 // 1 day
        }
        
        for i in 0..<points {
            let date = now.addingTimeInterval(-Double(points - i - 1) * interval)
            let sessions = Int.random(in: 5...20)
            let tokens = Int.random(in: 1000...5000)
            let cost = Double.random(in: 0.5...5.0)
            let messages = Int.random(in: 10...50)
            
            data.append(TimeSeriesPoint(
                date: date,
                sessions: sessions,
                tokens: tokens,
                cost: cost,
                messages: messages
            ))
        }
        
        timeSeriesData = data
    }
    
    private func calculateTrends() {
        // Mock trend calculations
        sessionsTrend = Double.random(in: -10...20)
        tokensTrend = Double.random(in: -15...25)
        costTrend = Double.random(in: -5...15)
        messagesTrend = Double.random(in: -8...18)
    }
    
    private func generateModelUsage() {
        modelUsage = [
            ModelUsage(name: "Claude 3.5 Sonnet", percentage: 45, color: Theme.neonCyan),
            ModelUsage(name: "Claude 3 Opus", percentage: 30, color: Theme.neonPurple),
            ModelUsage(name: "Claude 3 Haiku", percentage: 25, color: Theme.neonGreen)
        ]
    }
    
    private func calculateTokenDistribution() {
        let total = stats?.totalTokens ?? 10000
        inputTokens = Int(Double(total) * 0.4)
        outputTokens = Int(Double(total) * 0.5)
        cachedTokens = Int(Double(total) * 0.1)
    }
    
    private func calculateAverages() {
        guard let stats = stats, stats.activeSessions > 0 else { return }
        avgTokensPerSession = stats.totalTokens / max(1, stats.activeSessions)
        avgCostPerSession = stats.totalCost / Double(max(1, stats.activeSessions))
        avgMessagesPerSession = stats.totalMessages / max(1, stats.activeSessions)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AnalyticsView()
    }
}