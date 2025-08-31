import SwiftUI
import Charts

/// Animated Status Bar with real-time performance visualization
public struct AnimatedStatusBar: View {
    @StateObject private var viewModel = StatusBarViewModel()
    @State private var pulseAnimation = false
    @State private var dataFlowAnimation = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main status bar
            mainStatusBar
            
            // Expandable performance details
            if viewModel.isExpanded {
                performanceDetails
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .background(CyberpunkTheme.darkCard)
        .cyberpunkCard()
        .onAppear {
            viewModel.startMonitoring()
            if !reduceMotion {
                startAnimations()
            }
        }
    }
    
    // MARK: - Main Status Bar
    private var mainStatusBar: some View {
        HStack(spacing: 20) {
            // Connection Status with animated pulse
            connectionStatus
            
            Divider()
                .frame(height: 30)
                .background(CyberpunkTheme.darkBorder)
            
            // Live Token Usage
            tokenUsageIndicator
            
            Divider()
                .frame(height: 30)
                .background(CyberpunkTheme.darkBorder)
            
            // Memory Usage with animation
            memoryUsageIndicator
            
            Divider()
                .frame(height: 30)
                .background(CyberpunkTheme.darkBorder)
            
            // Performance Score
            performanceScoreIndicator
            
            Spacer()
            
            // Expand/Collapse button
            expandButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Connection Status
    private var connectionStatus: some View {
        HStack(spacing: 10) {
            ZStack {
                // Pulse animation
                Circle()
                    .fill(viewModel.isConnected ? CyberpunkTheme.neonGreen : CyberpunkTheme.neonMagenta)
                    .frame(width: 10, height: 10)
                
                if viewModel.isConnected && !reduceMotion {
                    Circle()
                        .stroke(CyberpunkTheme.neonGreen, lineWidth: 2)
                        .scaleEffect(pulseAnimation ? 2.5 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.isConnected ? "ONLINE" : "OFFLINE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(viewModel.isConnected ? CyberpunkTheme.neonGreen : CyberpunkTheme.neonMagenta)
                
                Text("\(viewModel.latency)ms")
                    .font(.system(size: 9, weight: .light, design: .monospaced))
                    .foregroundStyle(Theme.mutedFg)
            }
        }
        .onTapGesture {
            CyberpunkTheme.lightImpact()
            viewModel.testConnection()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection status: \(viewModel.isConnected ? "Online" : "Offline"), Latency: \(viewModel.latency) milliseconds")
    }
    
    // MARK: - Token Usage Indicator
    private var tokenUsageIndicator: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(CyberpunkTheme.neonCyan)
                    .neonGlow(color: CyberpunkTheme.neonCyan, intensity: 2)
                
                Text("TOKENS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(CyberpunkTheme.neonCyan)
            }
            
            ZStack(alignment: .leading) {
                // Background bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(CyberpunkTheme.darkBackground)
                    .frame(width: 100, height: 6)
                
                // Animated fill bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: tokenGradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 100 * viewModel.tokenPercentage, height: 6)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.tokenPercentage)
                
                // Data flow animation overlay
                if !reduceMotion && dataFlowAnimation {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 20, height: 6)
                        .offset(x: dataFlowAnimation ? 80 : -20)
                        .animation(
                            .linear(duration: 2)
                                .repeatForever(autoreverses: false),
                            value: dataFlowAnimation
                        )
                }
            }
            
            Text("\(viewModel.tokensUsed.formatted()) / \(viewModel.tokenLimit.formatted())")
                .font(.system(size: 9, weight: .light, design: .monospaced))
                .foregroundStyle(Theme.mutedFg)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Token usage: \(Int(viewModel.tokenPercentage * 100))%")
    }
    
    // MARK: - Memory Usage Indicator
    private var memoryUsageIndicator: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 12))
                    .foregroundStyle(CyberpunkTheme.neonMagenta)
                    .neonGlow(color: CyberpunkTheme.neonMagenta, intensity: 2)
                
                Text("MEMORY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(CyberpunkTheme.neonMagenta)
            }
            
            // Circular progress indicator
            ZStack {
                Circle()
                    .stroke(CyberpunkTheme.darkBackground, lineWidth: 3)
                    .frame(width: 30, height: 30)
                
                Circle()
                    .trim(from: 0, to: viewModel.memoryPercentage)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                CyberpunkTheme.neonMagenta,
                                CyberpunkTheme.neonPurple,
                                CyberpunkTheme.neonMagenta
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.memoryPercentage)
                
                Text("\(Int(viewModel.memoryPercentage * 100))%")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CyberpunkTheme.neonMagenta)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Memory usage: \(Int(viewModel.memoryPercentage * 100))%")
    }
    
    // MARK: - Performance Score
    private var performanceScoreIndicator: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "speedometer")
                    .font(.system(size: 12))
                    .foregroundStyle(performanceColor)
                    .neonGlow(color: performanceColor, intensity: 2)
                
                Text("PERFORMANCE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(performanceColor)
            }
            
            HStack(spacing: 4) {
                Text("\(Int(viewModel.performanceScore))")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(performanceColor)
                
                VStack {
                    Image(systemName: performanceTrend)
                        .font(.system(size: 8))
                        .foregroundStyle(performanceColor)
                    Text("FPS: \(viewModel.currentFPS)")
                        .font(.system(size: 7, weight: .light, design: .monospaced))
                        .foregroundStyle(Theme.mutedFg)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Performance score: \(Int(viewModel.performanceScore)), FPS: \(viewModel.currentFPS)")
    }
    
    // MARK: - Expand Button
    private var expandButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.isExpanded.toggle()
            }
            CyberpunkTheme.selectionFeedback()
        } label: {
            Image(systemName: viewModel.isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12))
                .foregroundStyle(CyberpunkTheme.neonBlue)
                .rotationEffect(.degrees(viewModel.isExpanded ? 180 : 0))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isExpanded)
        }
        .accessibilityLabel(viewModel.isExpanded ? "Collapse details" : "Expand details")
    }
    
    // MARK: - Performance Details
    private var performanceDetails: some View {
        VStack(spacing: 16) {
            // Real-time performance chart
            performanceChart
            
            // Metrics grid
            metricsGrid
        }
        .padding()
        .background(CyberpunkTheme.darkBackground)
    }
    
    private var performanceChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REAL-TIME METRICS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(CyberpunkTheme.neonCyan)
            
            Chart(viewModel.performanceHistory) { metric in
                LineMark(
                    x: .value("Time", metric.timestamp),
                    y: .value("Score", metric.score)
                )
                .foregroundStyle(CyberpunkTheme.neonCyan)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                AreaMark(
                    x: .value("Time", metric.timestamp),
                    y: .value("Score", metric.score)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            CyberpunkTheme.neonCyan.opacity(0.3),
                            CyberpunkTheme.neonCyan.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: 100)
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(CyberpunkTheme.darkBorder)
                    AxisValueLabel()
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(Theme.mutedFg)
                }
            }
        }
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            MetricCard(title: "CPU", value: "\(viewModel.cpuUsage)%", color: CyberpunkTheme.neonOrange)
            MetricCard(title: "NETWORK", value: "\(viewModel.networkSpeed) MB/s", color: CyberpunkTheme.neonGreen)
            MetricCard(title: "DISK I/O", value: "\(viewModel.diskIO) MB/s", color: CyberpunkTheme.neonPurple)
            MetricCard(title: "THREADS", value: "\(viewModel.activeThreads)", color: CyberpunkTheme.neonCyan)
            MetricCard(title: "CACHE HIT", value: "\(viewModel.cacheHitRate)%", color: CyberpunkTheme.neonMagenta)
            MetricCard(title: "ERRORS", value: "\(viewModel.errorCount)", color: CyberpunkTheme.neonPink)
        }
    }
    
    // MARK: - Helper Properties
    private var tokenGradientColors: [Color] {
        switch viewModel.tokenPercentage {
        case 0..<0.5:
            return [CyberpunkTheme.neonGreen, CyberpunkTheme.neonCyan]
        case 0.5..<0.8:
            return [CyberpunkTheme.neonCyan, CyberpunkTheme.neonOrange]
        default:
            return [CyberpunkTheme.neonOrange, CyberpunkTheme.neonMagenta]
        }
    }
    
    private var performanceColor: Color {
        switch viewModel.performanceScore {
        case 90...100:
            return CyberpunkTheme.neonGreen
        case 70..<90:
            return CyberpunkTheme.neonOrange
        default:
            return CyberpunkTheme.neonMagenta
        }
    }
    
    private var performanceTrend: String {
        viewModel.performanceTrend > 0 ? "arrow.up.circle.fill" : 
        viewModel.performanceTrend < 0 ? "arrow.down.circle.fill" : "minus.circle.fill"
    }
    
    private func startAnimations() {
        pulseAnimation = true
        dataFlowAnimation = true
    }
}

// MARK: - Metric Card Component
struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .neonGlow(color: color, intensity: 2)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(CyberpunkTheme.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - View Model
class StatusBarViewModel: ObservableObject {
    @Published var isConnected = true
    @Published var latency = 42
    @Published var tokensUsed = 45_000
    @Published var tokenLimit = 100_000
    @Published var memoryPercentage: CGFloat = 0.45
    @Published var performanceScore: Double = 95
    @Published var performanceTrend: Double = 5
    @Published var currentFPS = 60
    @Published var isExpanded = false
    
    @Published var cpuUsage = 35
    @Published var networkSpeed = 125
    @Published var diskIO = 89
    @Published var activeThreads = 12
    @Published var cacheHitRate = 92
    @Published var errorCount = 0
    
    @Published var performanceHistory: [PerformanceMetric] = []
    
    private var timer: Timer?
    
    var tokenPercentage: CGFloat {
        CGFloat(tokensUsed) / CGFloat(tokenLimit)
    }
    
    func startMonitoring() {
        // Initialize with some data
        for i in 0..<20 {
            let timestamp = Date().addingTimeInterval(Double(i - 20) * 3)
            performanceHistory.append(
                PerformanceMetric(
                    timestamp: timestamp,
                    score: Double.random(in: 85...100)
                )
            )
        }
        
        // Start real-time updates
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            self.updateMetrics()
        }
    }
    
    func testConnection() {
        // Simulate connection test
        latency = Int.random(in: 20...150)
    }
    
    private func updateMetrics() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            // Update performance metrics
            performanceScore = Double.random(in: 85...100)
            performanceTrend = Double.random(in: -10...10)
            currentFPS = Int.random(in: 55...60)
            
            // Update resource usage
            tokensUsed = min(tokensUsed + Int.random(in: 100...500), tokenLimit)
            memoryPercentage = CGFloat.random(in: 0.3...0.7)
            
            // Update system metrics
            cpuUsage = Int.random(in: 20...60)
            networkSpeed = Int.random(in: 50...200)
            diskIO = Int.random(in: 30...150)
            activeThreads = Int.random(in: 8...16)
            cacheHitRate = Int.random(in: 85...98)
            
            // Add to history
            performanceHistory.append(
                PerformanceMetric(timestamp: Date(), score: performanceScore)
            )
            
            // Keep only last 20 data points
            if performanceHistory.count > 20 {
                performanceHistory.removeFirst()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct PerformanceMetric: Identifiable {
    let id = UUID()
    let timestamp: Date
    let score: Double
}