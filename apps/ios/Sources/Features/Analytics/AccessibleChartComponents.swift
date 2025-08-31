import SwiftUI
import Charts

/// Accessible chart component wrapper with VoiceOver support and cyberpunk styling
/// Addresses the chart accessibility gaps identified in the audit
public struct AccessibleChart<Content: View>: View {
    let title: String
    let summary: String
    let dataDescription: String
    let content: () -> Content
    
    @State private var selectedDataPoint: String?
    @State private var glowIntensity: Double = 2.0
    @State private var headerGlow = false
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init(
        title: String,
        summary: String,
        dataDescription: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.summary = summary
        self.dataDescription = dataDescription
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Chart header with cyberpunk glow
            chartHeader
            
            // Chart content with neon border
            ZStack {
                // Neon border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                CyberpunkTheme.neonCyan.opacity(0.6),
                                CyberpunkTheme.neonMagenta.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blur(radius: glowIntensity)
                    .opacity(0.8)
                
                // Chart with background
                content()
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(CyberpunkTheme.darkCard)
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(title)
                    .accessibilityValue(dataDescription)
                    .accessibilityHint("Chart data: \(summary)")
            }
            
            // Data table alternative for screen readers
            if UIAccessibility.isVoiceOverRunning {
                accessibleDataTable
            }
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowIntensity = 4.0
                    headerGlow = true
                }
            }
        }
    }
    
    private var chartHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [CyberpunkTheme.neonCyan, CyberpunkTheme.neonBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .neonGlow(color: CyberpunkTheme.neonCyan, intensity: headerGlow ? 3 : 2)
            
            Text(summary)
                .font(.system(size: 14, weight: .light, design: .monospaced))
                .foregroundStyle(CyberpunkTheme.neonMagenta.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
    }
    
    private var accessibleDataTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "table")
                    .font(.system(size: 14))
                    .foregroundStyle(CyberpunkTheme.neonGreen)
                    .neonGlow(color: CyberpunkTheme.neonGreen, intensity: 2)
                
                Text("DATA TABLE VIEW")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(CyberpunkTheme.neonGreen)
            }
            
            Text(dataDescription)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(CyberpunkTheme.darkCard)
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(CyberpunkTheme.neonGreen.opacity(0.5), lineWidth: 1)
                    .blur(radius: 1)
            }
        )
    }
}

/// Accessible bar chart component with cyberpunk styling
public struct AccessibleBarChart: View {
    let data: [ChartDataPoint]
    let title: String
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var selectedBar: ChartDataPoint?
    @State private var animateValues = false
    
    public struct ChartDataPoint: Identifiable {
        public let id = UUID()
        public let label: String
        public let value: Double
        public let color: Color
        
        public init(label: String, value: Double, color: Color? = nil) {
            self.label = label
            self.value = value
            // Use cyberpunk colors if no color specified
            self.color = color ?? [
                CyberpunkTheme.neonCyan,
                CyberpunkTheme.neonMagenta,
                CyberpunkTheme.neonBlue,
                CyberpunkTheme.neonGreen,
                CyberpunkTheme.neonPurple,
                CyberpunkTheme.neonOrange
            ].randomElement()!
        }
    }
    
    public init(title: String, data: [ChartDataPoint]) {
        self.title = title
        self.data = data
    }
    
    public var body: some View {
        AccessibleChart(
            title: title,
            summary: chartSummary,
            dataDescription: dataDescription
        ) {
            Chart(data) { point in
                BarMark(
                    x: .value("Category", point.label),
                    y: .value("Value", animateValues ? point.value : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [point.color, point.color.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
                .opacity(selectedBar == nil || selectedBar?.id == point.id ? 1.0 : 0.5)
                .accessibilityLabel(point.label)
                .accessibilityValue("\(Int(point.value))")
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonGreen.opacity(0.8))
                    
                    AxisGridLine()
                        .foregroundStyle(CyberpunkTheme.neonGreen.opacity(0.2))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonCyan.opacity(0.8))
                }
            }
            .onAppear {
                if !reduceMotion {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                        animateValues = true
                    }
                } else {
                    animateValues = true
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .onTapGesture { location in
            // Handle tap to announce specific data point
            announceDataPoint(at: location)
            CyberpunkTheme.lightImpact()
        }
    }
    
    private var chartSummary: String {
        let total = data.reduce(0) { $0 + $1.value }
        let average = total / Double(data.count)
        return "Total: \(Int(total)), Average: \(Int(average))"
    }
    
    private var dataDescription: String {
        data.map { "\($0.label): \(Int($0.value))" }.joined(separator: ", ")
    }
    
    private func announceDataPoint(at location: CGPoint) {
        // This would calculate which bar was tapped and announce it
        if let point = selectedBar {
            UIAccessibility.post(
                notification: .announcement,
                argument: "\(point.label): \(Int(point.value))"
            )
        }
    }
}

/// Accessible line chart component with cyberpunk styling
public struct AccessibleLineChart: View {
    let data: [TimeSeriesPoint]
    let title: String
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var animatePath = false
    @State private var selectedPoint: TimeSeriesPoint?
    
    public struct TimeSeriesPoint: Identifiable {
        public let id = UUID()
        public let date: Date
        public let value: Double
        
        public init(date: Date, value: Double) {
            self.date = date
            self.value = value
        }
    }
    
    public init(title: String, data: [TimeSeriesPoint]) {
        self.title = title
        self.data = data
    }
    
    public var body: some View {
        AccessibleChart(
            title: title,
            summary: trendSummary,
            dataDescription: dataDescription
        ) {
            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", animatePath ? point.value : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [CyberpunkTheme.neonCyan, CyberpunkTheme.neonMagenta],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                
                if !reduceMotion {
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", animatePath ? point.value : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                CyberpunkTheme.neonCyan.opacity(0.3),
                                CyberpunkTheme.neonMagenta.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                
                // Add glow points at data points
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", animatePath ? point.value : 0)
                )
                .foregroundStyle(CyberpunkTheme.neonCyan)
                .symbolSize(selectedPoint?.id == point.id ? 100 : 50)
                .opacity(animatePath ? 1.0 : 0)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonGreen.opacity(0.8))
                    
                    AxisGridLine()
                        .foregroundStyle(CyberpunkTheme.neonGreen.opacity(0.2))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonCyan.opacity(0.8))
                    
                    AxisGridLine()
                        .foregroundStyle(CyberpunkTheme.neonCyan.opacity(0.1))
                }
            }
            .onAppear {
                if !reduceMotion {
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3)) {
                        animatePath = true
                    }
                } else {
                    animatePath = true
                }
            }
        }
    }
    
    private var trendSummary: String {
        guard let first = data.first?.value,
              let last = data.last?.value else { return "No data" }
        
        let change = last - first
        let percentChange = (change / first) * 100
        
        if change > 0 {
            return "Trending up by \(Int(percentChange))%"
        } else if change < 0 {
            return "Trending down by \(Int(abs(percentChange)))%"
        } else {
            return "No change"
        }
    }
    
    private var dataDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        return data.prefix(5).map { point in
            "\(formatter.string(from: point.date)): \(Int(point.value))"
        }.joined(separator: ", ")
    }
}

/// Accessible pie chart component with cyberpunk styling
public struct AccessiblePieChart: View {
    let segments: [PieSegment]
    let title: String
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var animateSegments = false
    @State private var selectedSegment: PieSegment?
    @State private var rotationAngle: Double = 0
    
    public struct PieSegment: Identifiable {
        public let id = UUID()
        public let label: String
        public let value: Double
        public let color: Color
        
        public init(label: String, value: Double, color: Color? = nil) {
            self.label = label
            self.value = value
            // Use cyberpunk colors with automatic assignment
            let cyberpunkColors = [
                CyberpunkTheme.neonCyan,
                CyberpunkTheme.neonMagenta,
                CyberpunkTheme.neonBlue,
                CyberpunkTheme.neonGreen,
                CyberpunkTheme.neonPurple,
                CyberpunkTheme.neonOrange
            ]
            self.color = color ?? cyberpunkColors[segments.count % cyberpunkColors.count]
        }
    }
    
    public init(title: String, segments: [PieSegment]) {
        self.title = title
        self.segments = segments
    }
    
    public var body: some View {
        AccessibleChart(
            title: title,
            summary: distributionSummary,
            dataDescription: segmentDescription
        ) {
            ZStack {
                // Background glow ring
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                CyberpunkTheme.neonCyan.opacity(0.3),
                                CyberpunkTheme.neonMagenta.opacity(0.3),
                                CyberpunkTheme.neonBlue.opacity(0.3),
                                CyberpunkTheme.neonCyan.opacity(0.3)
                            ]),
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 3)
                    .rotationEffect(.degrees(rotationAngle))
                
                Chart(segments) { segment in
                    SectorMark(
                        angle: .value("Value", animateSegments ? segment.value : 0),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [segment.color, segment.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(selectedSegment == nil || selectedSegment?.id == segment.id ? 1.0 : 0.5)
                    .accessibilityLabel(segment.label)
                    .accessibilityValue("\(Int(segment.value))%")
                }
                .frame(height: 200)
                
                // Center glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                CyberpunkTheme.neonMagenta.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 5)
            }
            .onAppear {
                if !reduceMotion {
                    withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.2)) {
                        animateSegments = true
                    }
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                } else {
                    animateSegments = true
                }
            }
            .onTapGesture { location in
                CyberpunkTheme.lightImpact()
                // Could implement segment selection here
            }
        }
    }
    
    private var distributionSummary: String {
        let total = segments.reduce(0) { $0 + $1.value }
        let largest = segments.max(by: { $0.value < $1.value })
        
        if let largest = largest {
            let percentage = (largest.value / total) * 100
            return "\(largest.label) is the largest at \(Int(percentage))%"
        }
        return "Distribution of \(segments.count) segments"
    }
    
    private var segmentDescription: String {
        segments.map { segment in
            let percentage = (segment.value / segments.reduce(0) { $0 + $1.value }) * 100
            return "\(segment.label): \(Int(percentage))%"
        }.joined(separator: ", ")
    }
}

// MARK: - Chart Accessibility Helpers
public extension View {
    /// Adds comprehensive accessibility support to any chart
    func accessibleChartModifier(
        title: String,
        summary: String,
        dataPoints: [String]
    ) -> some View {
        self
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
            .accessibilityHint(summary)
            .accessibilityValue(dataPoints.joined(separator: ", "))
            .accessibilityAddTraits(.isImage)
    }
}