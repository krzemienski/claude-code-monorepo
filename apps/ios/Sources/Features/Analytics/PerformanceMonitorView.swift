import SwiftUI
import Charts
import Combine

/// Performance Monitor View with real-time metrics and cyberpunk styling
public struct PerformanceMonitorView: View {
    @StateObject private var viewModel = PerformanceMonitorViewModel()
    @State private var selectedMetric: MetricType = .cpu
    @State private var expandedSection: String? = nil
    @State private var glowAnimation = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background with subtle matrix effect
                CyberpunkTheme.darkBackground
                    .ignoresSafeArea()
                
                if !reduceMotion {
                    MatrixRainEffect(columnCount: 5)
                        .opacity(0.05)
                        .allowsHitTesting(false)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with live status
                        performanceHeader
                        
                        // Metric selector tabs
                        metricSelector
                        
                        // Main performance chart
                        mainChart
                        
                        // Quick stats grid
                        statsGrid
                        
                        // Detailed metrics sections
                        detailedMetrics
                        
                        // System information
                        systemInfo
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PERFORMANCE MONITOR")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonCyan)
                        .neonGlow(color: CyberpunkTheme.neonCyan, intensity: 2)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(CyberpunkTheme.neonMagenta)
                            .neonGlow(color: CyberpunkTheme.neonMagenta, intensity: 2)
                    }
                }
            }
        }
        .onAppear {
            viewModel.startMonitoring()
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
    
    // MARK: - Performance Header
    private var performanceHeader: some View {
        VStack(spacing: 16) {
            // Overall health indicator
            HStack(spacing: 16) {
                // Health status orb
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    viewModel.healthColor,
                                    viewModel.healthColor.opacity(0.3)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .blur(radius: glowAnimation ? 3 : 1)
                    
                    Circle()
                        .stroke(viewModel.healthColor, lineWidth: 2)
                        .frame(width: 60, height: 60)
                    
                    Text("\(viewModel.healthScore)%")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("SYSTEM HEALTH")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonCyan)
                    
                    Text(viewModel.healthStatus)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.healthColor)
                        .neonGlow(color: viewModel.healthColor, intensity: 2)
                    
                    Text("Last updated: \(viewModel.lastUpdateTime)")
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonGreen.opacity(0.7))
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(CyberpunkTheme.darkCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(viewModel.healthColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Metric Selector
    private var metricSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    MetricTab(
                        metric: metric,
                        isSelected: selectedMetric == metric,
                        value: viewModel.currentValue(for: metric),
                        trend: viewModel.trend(for: metric)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMetric = metric
                        }
                        CyberpunkTheme.lightImpact()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Main Chart
    private var mainChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedMetric.title)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(CyberpunkTheme.neonCyan)
                
                Spacer()
                
                Text("\(viewModel.currentValue(for: selectedMetric), specifier: "%.1f")\(selectedMetric.unit)")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(CyberpunkTheme.neonGreen)
            }
            
            // Live chart
            Chart(viewModel.dataPoints(for: selectedMetric)) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [selectedMetric.color, selectedMetric.color.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                
                if !reduceMotion {
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                selectedMetric.color.opacity(0.3),
                                selectedMetric.color.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 200)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonGreen.opacity(0.8))
                    
                    AxisGridLine()
                        .foregroundStyle(CyberpunkTheme.neonGreen.opacity(0.2))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonCyan.opacity(0.8))
                }
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(CyberpunkTheme.darkCard)
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                selectedMetric.color.opacity(0.6),
                                selectedMetric.color.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blur(radius: 1)
            }
        )
    }
    
    // MARK: - Stats Grid
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(viewModel.quickStats, id: \.title) { stat in
                QuickStatCard(stat: stat)
            }
        }
    }
    
    // MARK: - Detailed Metrics
    private var detailedMetrics: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.detailedSections, id: \.title) { section in
                DetailedMetricSection(
                    section: section,
                    isExpanded: expandedSection == section.title
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        expandedSection = expandedSection == section.title ? nil : section.title
                    }
                    CyberpunkTheme.lightImpact()
                }
            }
        }
    }
    
    // MARK: - System Info
    private var systemInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SYSTEM INFORMATION")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(CyberpunkTheme.neonCyan)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.systemInfo, id: \.label) { info in
                    HStack {
                        Text(info.label)
                            .font(.system(size: 12, weight: .light, design: .monospaced))
                            .foregroundStyle(CyberpunkTheme.neonGreen.opacity(0.7))
                        
                        Spacer()
                        
                        Text(info.value)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(CyberpunkTheme.darkCard.opacity(0.5))
            )
        }
    }
}

// MARK: - Supporting Types
enum MetricType: String, CaseIterable {
    case cpu = "CPU"
    case memory = "Memory"
    case fps = "FPS"
    case network = "Network"
    case battery = "Battery"
    case disk = "Disk"
    
    var title: String {
        switch self {
        case .cpu: return "CPU USAGE"
        case .memory: return "MEMORY"
        case .fps: return "FRAME RATE"
        case .network: return "NETWORK"
        case .battery: return "BATTERY"
        case .disk: return "DISK I/O"
        }
    }
    
    var unit: String {
        switch self {
        case .cpu, .memory, .battery: return "%"
        case .fps: return " fps"
        case .network: return " Mbps"
        case .disk: return " MB/s"
        }
    }
    
    var color: Color {
        switch self {
        case .cpu: return CyberpunkTheme.neonCyan
        case .memory: return CyberpunkTheme.neonMagenta
        case .fps: return CyberpunkTheme.neonGreen
        case .network: return CyberpunkTheme.neonBlue
        case .battery: return CyberpunkTheme.neonOrange
        case .disk: return CyberpunkTheme.neonPurple
        }
    }
    
    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .fps: return "speedometer"
        case .network: return "network"
        case .battery: return "battery.100"
        case .disk: return "internaldrive"
        }
    }
}

// MARK: - Metric Tab Component
struct MetricTab: View {
    let metric: MetricType
    let isSelected: Bool
    let value: Double
    let trend: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: metric.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? metric.color : Color.white.opacity(0.5))
                
                Text(metric.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? metric.color : Color.white.opacity(0.5))
                
                HStack(spacing: 4) {
                    Text("\(value, specifier: "%.0f")\(metric.unit)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    
                    Image(systemName: trend)
                        .font(.system(size: 8))
                }
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? metric.color.opacity(0.2) : CyberpunkTheme.darkCard)
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(metric.color, lineWidth: 2)
                            .blur(radius: 1)
                    }
                }
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let stat: QuickStat
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(stat.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: stat.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(stat.color)
                    .neonGlow(color: stat.color, intensity: 2)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.title)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(stat.color.opacity(0.8))
                
                Text(stat.value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(CyberpunkTheme.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(stat.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct QuickStat {
    let title: String
    let value: String
    let icon: String
    let color: Color
}

// MARK: - Detailed Metric Section
struct DetailedMetricSection: View {
    let section: MetricSection
    let isExpanded: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: toggleAction) {
                HStack {
                    Text(section.title)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonCyan)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(CyberpunkTheme.neonCyan.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(section.metrics, id: \.label) { metric in
                        HStack {
                            Text(metric.label)
                                .font(.system(size: 12, weight: .light, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.7))
                            
                            Spacer()
                            
                            Text(metric.value)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(metric.color ?? Color.white)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(CyberpunkTheme.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CyberpunkTheme.neonCyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct MetricSection {
    let title: String
    let metrics: [MetricDetail]
}

struct MetricDetail {
    let label: String
    let value: String
    let color: Color?
}

// MARK: - View Model
class PerformanceMonitorViewModel: ObservableObject {
    @Published var healthScore: Int = 92
    @Published var healthStatus: String = "OPTIMAL"
    @Published var lastUpdateTime: String = "Just now"
    @Published var quickStats: [QuickStat] = []
    @Published var detailedSections: [MetricSection] = []
    @Published var systemInfo: [(label: String, value: String)] = []
    
    private var timer: Timer?
    private var dataHistory: [MetricType: [DataPoint]] = [:]
    
    struct DataPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let value: Double
    }
    
    init() {
        initializeData()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateMetrics()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func currentValue(for metric: MetricType) -> Double {
        dataHistory[metric]?.last?.value ?? 0
    }
    
    func trend(for metric: MetricType) -> String {
        guard let history = dataHistory[metric],
              history.count >= 2 else { return "arrow.right" }
        
        let recent = history.suffix(2)
        if recent.last!.value > recent.first!.value {
            return "arrow.up.right"
        } else if recent.last!.value < recent.first!.value {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }
    
    func dataPoints(for metric: MetricType) -> [DataPoint] {
        dataHistory[metric] ?? []
    }
    
    var healthColor: Color {
        if healthScore >= 80 {
            return CyberpunkTheme.neonGreen
        } else if healthScore >= 60 {
            return CyberpunkTheme.neonOrange
        } else {
            return CyberpunkTheme.neonMagenta
        }
    }
    
    private func initializeData() {
        // Initialize with sample data
        let now = Date()
        for metric in MetricType.allCases {
            var points: [DataPoint] = []
            for i in 0..<60 {
                let timestamp = now.addingTimeInterval(Double(-60 + i))
                let baseValue: Double
                switch metric {
                case .cpu: baseValue = 30
                case .memory: baseValue = 45
                case .fps: baseValue = 60
                case .network: baseValue = 25
                case .battery: baseValue = 85
                case .disk: baseValue = 15
                }
                let value = baseValue + Double.random(in: -10...10)
                points.append(DataPoint(timestamp: timestamp, value: max(0, min(100, value))))
            }
            dataHistory[metric] = points
        }
        
        updateQuickStats()
        updateDetailedSections()
        updateSystemInfo()
    }
    
    private func updateMetrics() {
        let now = Date()
        
        // Update each metric with new data point
        for metric in MetricType.allCases {
            var history = dataHistory[metric] ?? []
            
            // Generate realistic-looking data
            let lastValue = history.last?.value ?? 50
            let change = Double.random(in: -5...5)
            let newValue = max(0, min(100, lastValue + change))
            
            history.append(DataPoint(timestamp: now, value: newValue))
            
            // Keep only last 60 points
            if history.count > 60 {
                history.removeFirst()
            }
            
            dataHistory[metric] = history
        }
        
        // Update health score
        let avgCPU = currentValue(for: .cpu)
        let avgMemory = currentValue(for: .memory)
        healthScore = Int(100 - (avgCPU + avgMemory) / 4)
        
        if healthScore >= 80 {
            healthStatus = "OPTIMAL"
        } else if healthScore >= 60 {
            healthStatus = "GOOD"
        } else {
            healthStatus = "NEEDS ATTENTION"
        }
        
        // Update timestamp
        lastUpdateTime = "Just now"
        
        updateQuickStats()
    }
    
    private func updateQuickStats() {
        quickStats = [
            QuickStat(
                title: "AVG RESPONSE",
                value: "42ms",
                icon: "timer",
                color: CyberpunkTheme.neonGreen
            ),
            QuickStat(
                title: "UPTIME",
                value: "99.9%",
                icon: "checkmark.circle",
                color: CyberpunkTheme.neonCyan
            ),
            QuickStat(
                title: "REQUESTS/SEC",
                value: "1.2K",
                icon: "arrow.up.arrow.down",
                color: CyberpunkTheme.neonMagenta
            ),
            QuickStat(
                title: "ERROR RATE",
                value: "0.01%",
                icon: "exclamationmark.triangle",
                color: CyberpunkTheme.neonOrange
            )
        ]
    }
    
    private func updateDetailedSections() {
        detailedSections = [
            MetricSection(
                title: "PROCESS DETAILS",
                metrics: [
                    MetricDetail(label: "Threads", value: "8", color: nil),
                    MetricDetail(label: "Handles", value: "1,234", color: nil),
                    MetricDetail(label: "Private Memory", value: "256 MB", color: nil),
                    MetricDetail(label: "Virtual Memory", value: "512 MB", color: nil)
                ]
            ),
            MetricSection(
                title: "NETWORK DETAILS",
                metrics: [
                    MetricDetail(label: "Latency", value: "12ms", color: CyberpunkTheme.neonGreen),
                    MetricDetail(label: "Packet Loss", value: "0.0%", color: CyberpunkTheme.neonGreen),
                    MetricDetail(label: "Upload", value: "5.2 Mbps", color: nil),
                    MetricDetail(label: "Download", value: "45.8 Mbps", color: nil)
                ]
            )
        ]
    }
    
    private func updateSystemInfo() {
        systemInfo = [
            (label: "Device", value: UIDevice.current.model),
            (label: "iOS Version", value: UIDevice.current.systemVersion),
            (label: "App Version", value: "1.0.0"),
            (label: "Build", value: "2024.1"),
            (label: "Environment", value: "Production")
        ]
    }
}

// MARK: - Preview
struct PerformanceMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceMonitorView()
    }
}