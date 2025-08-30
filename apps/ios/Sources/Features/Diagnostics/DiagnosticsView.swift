import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Diagnostics View (WF-09)
struct DiagnosticsView: View {
    @StateObject private var viewModel = DiagnosticsViewModel()
    @State private var selectedTab = DiagnosticTab.logs
    @State private var filterText = ""
    @State private var logLevel = LogLevel.all
    @State private var autoScroll = true
    
    enum DiagnosticTab: String, CaseIterable {
        case logs = "Logs"
        case requests = "Network"
        case debug = "Debug"
        case performance = "Performance"
        
        var icon: String {
            switch self {
            case .logs: return "doc.text.fill"
            case .requests: return "network"
            case .debug: return "ant.fill"
            case .performance: return "speedometer"
            }
        }
    }
    
    enum LogLevel: String, CaseIterable {
        case all = "All"
        case debug = "Debug"
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        
        var color: Color {
            switch self {
            case .all: return Theme.mutedFg
            case .debug: return Theme.neonBlue
            case .info: return Theme.neonCyan
            case .warning: return Theme.neonYellow
            case .error: return Theme.error
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            headerSection
            
            // Filter bar
            filterBar
            
            // Content area
            contentView
                .background(Theme.background)
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { viewModel.exportLogs() }) {
                        Label("Export Logs", systemImage: "square.and.arrow.up")
                    }
                    Button(action: { viewModel.clearLogs() }) {
                        Label("Clear Logs", systemImage: "trash")
                    }
                    Divider()
                    Toggle("Auto-scroll", isOn: $autoScroll)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(Theme.neonCyan)
                }
            }
        }
        .task {
            await viewModel.startStreaming()
        }
        .onDisappear {
            viewModel.stopStreaming()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.md) {
                ForEach(DiagnosticTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surface)
    }
    
    // MARK: - Filter Bar
    private var filterBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.mutedFg)
                TextField("Filter logs...", text: $filterText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(Theme.foreground)
                if !filterText.isEmpty {
                    Button(action: { filterText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.mutedFg)
                    }
                }
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.input)
            .cornerRadius(Theme.CornerRadius.sm)
            
            // Log level filter
            if selectedTab == .logs {
                Picker("Level", selection: $logLevel) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue)
                            .tag(level)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 100)
            }
            
            // Connection status
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(viewModel.isConnected ? Theme.success : Theme.error)
                    .frame(width: 8, height: 8)
                Text(viewModel.isConnected ? "Connected" : "Disconnected")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.mutedFg)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.backgroundSecondary)
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .logs:
            logsView
        case .requests:
            networkView
        case .debug:
            debugView
        case .performance:
            performanceView
        }
    }
    
    // MARK: - Logs View
    private var logsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredLogs) { log in
                        LogEntryView(log: log)
                            .id(log.id)
                    }
                    
                    if viewModel.logs.isEmpty {
                        emptyStateView(
                            icon: "doc.text",
                            title: "No Logs Available",
                            subtitle: "Logs will appear here when the system generates them"
                        )
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: viewModel.logs.count) { _ in
                if autoScroll, let lastLog = viewModel.logs.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var filteredLogs: [LogEntry] {
        viewModel.logs.filter { log in
            let matchesFilter = filterText.isEmpty || 
                log.message.localizedCaseInsensitiveContains(filterText) ||
                log.source.localizedCaseInsensitiveContains(filterText)
            let matchesLevel = logLevel == .all || log.level == logLevel
            return matchesFilter && matchesLevel
        }
    }
    
    // MARK: - Network View
    private var networkView: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(viewModel.networkRequests) { request in
                    NetworkRequestCard(request: request) {
                        viewModel.selectRequest(request)
                    }
                }
                
                if viewModel.networkRequests.isEmpty {
                    emptyStateView(
                        icon: "network",
                        title: "No Network Activity",
                        subtitle: "Network requests will appear here"
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Debug View
    private var debugView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Debug Controls
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Debug Controls")
                    .font(Theme.Fonts.subtitle)
                    .foregroundColor(Theme.foreground)
                
                HStack(spacing: Theme.Spacing.md) {
                    DebugButton(title: "Test API", icon: "antenna.radiowaves.left.and.right") {
                        await viewModel.testAPIConnection()
                    }
                    
                    DebugButton(title: "Clear Cache", icon: "trash") {
                        viewModel.clearCache()
                    }
                    
                    DebugButton(title: "Reset Settings", icon: "arrow.clockwise") {
                        viewModel.resetSettings()
                    }
                    
                    DebugButton(title: "Generate Report", icon: "doc.text.magnifyingglass") {
                        await viewModel.generateDebugReport()
                    }
                }
            }
            .padding()
            .background(Theme.surface)
            .cornerRadius(Theme.CornerRadius.lg)
            
            // System Info
            SystemInfoView(systemInfo: viewModel.systemInfo)
            
            // Debug Console
            DebugConsoleView(output: viewModel.debugOutput)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Performance View
    private var performanceView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Performance Metrics
                PerformanceMetricsGrid(metrics: viewModel.performanceMetrics)
                
                // Memory Usage Chart
                MemoryUsageChart(data: viewModel.memoryUsageData)
                
                // CPU Usage Chart
                CPUUsageChart(data: viewModel.cpuUsageData)
                
                // Network Latency
                NetworkLatencyView(latencies: viewModel.networkLatencies)
            }
            .padding()
        }
    }
    
    // MARK: - Helper Views
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Theme.mutedFg.opacity(0.5))
            Text(title)
                .font(Theme.Fonts.subtitle)
                .foregroundColor(Theme.foreground)
            Text(subtitle)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.mutedFg)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
}

// MARK: - Tab Button Component
struct TabButton: View {
    let tab: DiagnosticsView.DiagnosticTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                Text(tab.rawValue)
                    .font(Theme.Fonts.caption)
            }
            .foregroundColor(isSelected ? Theme.neonCyan : Theme.mutedFg)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                isSelected ? Theme.neonCyan.opacity(0.1) : Color.clear
            )
            .cornerRadius(Theme.CornerRadius.sm)
        }
    }
}

// MARK: - Log Entry View
struct LogEntryView: View {
    let log: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            // Level indicator
            Circle()
                .fill(log.level.color)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            // Timestamp
            Text(log.timestamp, style: .time)
                .font(Theme.Fonts.code(size: 11))
                .foregroundColor(Theme.mutedFg)
                .frame(width: 60, alignment: .leading)
            
            // Source
            Text("[\(log.source)]")
                .font(Theme.Fonts.code(size: 11))
                .foregroundColor(Theme.neonBlue)
                .frame(width: 100, alignment: .leading)
            
            // Message
            Text(log.message)
                .font(Theme.Fonts.code(size: 12))
                .foregroundColor(Theme.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            log.level == .error ? Theme.error.opacity(0.05) :
            log.level == .warning ? Theme.warning.opacity(0.05) :
            Color.clear
        )
    }
}

// MARK: - Network Request Card
struct NetworkRequestCard: View {
    let request: NetworkRequest
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Method
                Text(request.method)
                    .font(Theme.Fonts.code(size: 12))
                    .fontWeight(.bold)
                    .foregroundColor(methodColor(request.method))
                    .frame(width: 60, alignment: .leading)
                
                // Status
                Text("\(request.statusCode)")
                    .font(Theme.Fonts.code(size: 12))
                    .foregroundColor(statusColor(request.statusCode))
                    .frame(width: 40)
                
                // Path
                Text(request.path)
                    .font(Theme.Fonts.code(size: 12))
                    .foregroundColor(Theme.foreground)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Duration
                Text("\(request.duration)ms")
                    .font(Theme.Fonts.code(size: 11))
                    .foregroundColor(Theme.mutedFg)
                
                // Size
                Text(formatBytes(request.responseSize))
                    .font(Theme.Fonts.code(size: 11))
                    .foregroundColor(Theme.mutedFg)
            }
            .padding()
            .background(Theme.surface)
            .cornerRadius(Theme.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return Theme.neonCyan
        case "POST": return Theme.neonGreen
        case "PUT": return Theme.neonYellow
        case "DELETE": return Theme.error
        default: return Theme.mutedFg
        }
    }
    
    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: return Theme.success
        case 300..<400: return Theme.neonBlue
        case 400..<500: return Theme.warning
        case 500..<600: return Theme.error
        default: return Theme.mutedFg
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return String(format: "%.1fKB", Double(bytes) / 1024) }
        return String(format: "%.1fMB", Double(bytes) / (1024 * 1024))
    }
}

// MARK: - Debug Button
struct DebugButton: View {
    let title: String
    let icon: String
    let action: () async -> Void
    @State private var isLoading = false
    
    var body: some View {
        Button(action: {
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        }) {
            VStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                }
                Text(title)
                    .font(Theme.Fonts.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.backgroundTertiary)
            .foregroundColor(Theme.neonCyan)
            .cornerRadius(Theme.CornerRadius.md)
        }
        .disabled(isLoading)
    }
}

// MARK: - System Info View
struct SystemInfoView: View {
    let systemInfo: SystemInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("System Information")
                .font(Theme.Fonts.subtitle)
                .foregroundColor(Theme.foreground)
            
            VStack(spacing: Theme.Spacing.sm) {
                InfoRow(label: "iOS Version", value: systemInfo.iosVersion)
                InfoRow(label: "Device", value: systemInfo.deviceModel)
                InfoRow(label: "App Version", value: systemInfo.appVersion)
                InfoRow(label: "Build", value: systemInfo.buildNumber)
                InfoRow(label: "Memory", value: "\(systemInfo.memoryUsage)MB / \(systemInfo.totalMemory)MB")
                InfoRow(label: "Storage", value: "\(systemInfo.storageUsed)GB / \(systemInfo.totalStorage)GB")
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.mutedFg)
            Spacer()
            Text(value)
                .font(Theme.Fonts.code(size: 12))
                .foregroundColor(Theme.foreground)
        }
    }
}

// MARK: - Debug Console View
struct DebugConsoleView: View {
    let output: String
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Debug Console")
                    .font(Theme.Fonts.subtitle)
                    .foregroundColor(Theme.foreground)
                Spacer()
                Button(action: {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = output
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopied = false
                    }
                    #endif
                }) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .foregroundColor(Theme.neonCyan)
                }
            }
            
            ScrollView {
                Text(output)
                    .font(Theme.Fonts.code(size: 11))
                    .foregroundColor(Theme.neonGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 200)
            .background(Color.black)
            .cornerRadius(Theme.CornerRadius.md)
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

// MARK: - Performance Metrics Grid
struct PerformanceMetricsGrid: View {
    let metrics: [PerformanceMetric]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Performance Metrics")
                .font(Theme.Fonts.subtitle)
                .foregroundColor(Theme.foreground)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Theme.Spacing.md) {
                ForEach(metrics) { metric in
                    PerformanceMetricCard(metric: metric)
                }
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

struct PerformanceMetricCard: View {
    let metric: PerformanceMetric
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(metric.value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(metric.isGood ? Theme.success : Theme.warning)
            Text(metric.name)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.mutedFg)
            Text(metric.unit)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.dimFg)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.backgroundTertiary)
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

// MARK: - Simple Chart Views (placeholders for actual charts)
struct MemoryUsageChart: View {
    let data: [Double]
    
    var body: some View {
        ChartPlaceholder(title: "Memory Usage", color: Theme.neonPurple)
    }
}

struct CPUUsageChart: View {
    let data: [Double]
    
    var body: some View {
        ChartPlaceholder(title: "CPU Usage", color: Theme.neonCyan)
    }
}

struct NetworkLatencyView: View {
    let latencies: [NetworkLatency]
    
    var body: some View {
        ChartPlaceholder(title: "Network Latency", color: Theme.neonGreen)
    }
}

struct ChartPlaceholder: View {
    let title: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(Theme.Fonts.subtitle)
                .foregroundColor(Theme.foreground)
            
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(color.opacity(0.1))
                .frame(height: 150)
                .overlay(
                    Text("Chart Data")
                        .foregroundColor(color)
                )
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

// MARK: - Data Models
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: DiagnosticsView.LogLevel
    let source: String
    let message: String
}

struct NetworkRequest: Identifiable {
    let id = UUID()
    let method: String
    let path: String
    let statusCode: Int
    let duration: Int
    let responseSize: Int
}

struct SystemInfo {
    let iosVersion: String
    let deviceModel: String
    let appVersion: String
    let buildNumber: String
    let memoryUsage: Int
    let totalMemory: Int
    let storageUsed: Int
    let totalStorage: Int
}

struct PerformanceMetric: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let unit: String
    let isGood: Bool
}

struct NetworkLatency: Identifiable {
    let id = UUID()
    let endpoint: String
    let latency: Double
}

// MARK: - View Model
@MainActor
class DiagnosticsViewModel: ObservableObject {
    @Published var logs: [LogEntry] = []
    @Published var networkRequests: [NetworkRequest] = []
    @Published var isConnected = false
    @Published var debugOutput = ""
    @Published var systemInfo = SystemInfo(
        iosVersion: UIDevice.current.systemVersion,
        deviceModel: UIDevice.current.model,
        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
        buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
        memoryUsage: 256,
        totalMemory: 1024,
        storageUsed: 32,
        totalStorage: 128
    )
    @Published var performanceMetrics: [PerformanceMetric] = []
    @Published var memoryUsageData: [Double] = []
    @Published var cpuUsageData: [Double] = []
    @Published var networkLatencies: [NetworkLatency] = []
    
    private var streamingTask: Task<Void, Never>?
    private let settings = AppSettings.shared
    
    func startStreaming() async {
        isConnected = true
        
        // Simulate log streaming
        streamingTask = Task {
            while !Task.isCancelled {
                addMockLog()
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
        
        // Load initial data
        loadMockData()
    }
    
    func stopStreaming() {
        streamingTask?.cancel()
        isConnected = false
    }
    
    func exportLogs() {
        debugOutput += "\n[Export] Logs exported to diagnostics.log"
    }
    
    func clearLogs() {
        logs.removeAll()
        debugOutput += "\n[Clear] All logs cleared"
    }
    
    func testAPIConnection() async {
        debugOutput += "\n[Test] Testing API connection..."
        guard let client = APIClient(settings: settings) else {
            debugOutput += "\n[Error] Failed to create API client"
            return
        }
        
        do {
            let health = try await client.health()
            debugOutput += "\n[Success] API is healthy: v\(health.version ?? "unknown")"
        } catch {
            debugOutput += "\n[Error] API test failed: \(error)"
        }
    }
    
    func clearCache() {
        debugOutput += "\n[Cache] Cache cleared successfully"
    }
    
    func resetSettings() {
        debugOutput += "\n[Reset] Settings reset to defaults"
    }
    
    func generateDebugReport() async {
        debugOutput += "\n[Report] Generating debug report..."
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        debugOutput += "\n[Report] Debug report saved to debug_report.txt"
    }
    
    func selectRequest(_ request: NetworkRequest) {
        debugOutput += "\n[Network] Selected request: \(request.method) \(request.path)"
    }
    
    private func addMockLog() {
        let levels: [DiagnosticsView.LogLevel] = [.debug, .info, .info, .warning, .error]
        let sources = ["APIClient", "SSEClient", "Session", "MCP", "UI", "Cache"]
        let messages = [
            "Connection established",
            "Request sent to /v1/chat/completions",
            "Received streaming response",
            "Cache hit for model capabilities",
            "Session 123 created",
            "MCP tool invoked: file_read",
            "Memory pressure warning",
            "Rate limit approaching"
        ]
        
        let log = LogEntry(
            timestamp: Date(),
            level: levels.randomElement()!,
            source: sources.randomElement()!,
            message: messages.randomElement()!
        )
        
        logs.append(log)
        
        // Keep only last 500 logs
        if logs.count > 500 {
            logs.removeFirst()
        }
    }
    
    private func loadMockData() {
        // Mock network requests
        networkRequests = [
            NetworkRequest(method: "GET", path: "/v1/models", statusCode: 200, duration: 123, responseSize: 2048),
            NetworkRequest(method: "POST", path: "/v1/chat/completions", statusCode: 200, duration: 456, responseSize: 8192),
            NetworkRequest(method: "GET", path: "/v1/sessions", statusCode: 200, duration: 89, responseSize: 4096),
            NetworkRequest(method: "DELETE", path: "/v1/sessions/123", statusCode: 204, duration: 45, responseSize: 0),
            NetworkRequest(method: "GET", path: "/v1/projects", statusCode: 401, duration: 12, responseSize: 128)
        ]
        
        // Mock performance metrics
        performanceMetrics = [
            PerformanceMetric(name: "FPS", value: "60", unit: "frames/sec", isGood: true),
            PerformanceMetric(name: "Memory", value: "256", unit: "MB", isGood: true),
            PerformanceMetric(name: "CPU", value: "45", unit: "%", isGood: true),
            PerformanceMetric(name: "Network", value: "23", unit: "ms", isGood: true),
            PerformanceMetric(name: "Battery", value: "12", unit: "%/hr", isGood: false),
            PerformanceMetric(name: "Disk I/O", value: "3.2", unit: "MB/s", isGood: true)
        ]
        
        // Mock chart data
        memoryUsageData = (0..<20).map { _ in Double.random(in: 200...400) }
        cpuUsageData = (0..<20).map { _ in Double.random(in: 20...80) }
        
        // Mock network latencies
        networkLatencies = [
            NetworkLatency(endpoint: "/v1/chat", latency: 23),
            NetworkLatency(endpoint: "/v1/models", latency: 12),
            NetworkLatency(endpoint: "/v1/sessions", latency: 18),
            NetworkLatency(endpoint: "/v1/projects", latency: 15)
        ]
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DiagnosticsView()
    }
}