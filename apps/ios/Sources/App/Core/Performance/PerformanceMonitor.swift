import SwiftUI
import QuartzCore
import Combine
import os.log

/// ⚡ Performance Monitor - Tracks FPS, Memory, CPU, and Render Times
@MainActor
public final class PerformanceMonitor: ObservableObject {
    public static let shared = PerformanceMonitor()
    
    // MARK: - Published Metrics
    @Published public private(set) var fps: Double = 60.0
    @Published public private(set) var memoryUsageMB: Double = 0.0
    @Published public private(set) var cpuUsagePercent: Double = 0.0
    @Published public private(set) var renderTimeMs: Double = 0.0
    @Published public private(set) var isPerformanceDegraded = false
    
    // MARK: - Thresholds
    private let fpsThreshold: Double = 55.0
    private let memoryThresholdMB: Double = 200.0
    private let cpuThresholdPercent: Double = 80.0
    private let renderTimeThresholdMs: Double = 16.67 // 60 FPS target
    
    // MARK: - Internal State
    private var displayLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount = 0
    private var fpsTimer: Timer?
    private var metricsTimer: Timer?
    private let logger = Logger(subsystem: "com.claudecode.performance", category: "Monitor")
    
    // MARK: - Performance Alerts
    @Published public var alerts: [PerformanceAlert] = []
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public API
    public func startMonitoring() {
        setupDisplayLink()
        setupMetricsTimer()
        logger.info("⚡ Performance monitoring started")
    }
    
    public func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        fpsTimer?.invalidate()
        fpsTimer = nil
        metricsTimer?.invalidate()
        metricsTimer = nil
        logger.info("⚡ Performance monitoring stopped")
    }
    
    public func logMetrics() {
        logger.info("""
        📊 Performance Metrics:
        FPS: \(String(format: "%.1f", self.fps))
        Memory: \(String(format: "%.1f", self.memoryUsageMB)) MB
        CPU: \(String(format: "%.1f", self.cpuUsagePercent))%
        Render: \(String(format: "%.2f", self.renderTimeMs)) ms
        """)
    }
    
    // MARK: - Private Methods
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .current, forMode: .common)
        
        // Reset FPS calculation every second
        fpsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.calculateFPS()
        }
    }
    
    private func setupMetricsTimer() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    @objc private func updateFPS(_ displayLink: CADisplayLink) {
        if lastFrameTime == 0 {
            lastFrameTime = displayLink.timestamp
            return
        }
        
        frameCount += 1
        let currentTime = displayLink.timestamp
        let deltaTime = currentTime - lastFrameTime
        
        // Calculate render time
        renderTimeMs = deltaTime * 1000
        
        lastFrameTime = currentTime
    }
    
    private func calculateFPS() {
        fps = Double(frameCount)
        frameCount = 0
        
        // Check FPS threshold
        if fps < fpsThreshold {
            addAlert(.lowFPS(fps))
        }
    }
    
    private func updateMetrics() {
        updateMemoryUsage()
        updateCPUUsage()
        checkPerformanceStatus()
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            memoryUsageMB = Double(info.resident_size) / 1024 / 1024
            
            // Check memory threshold
            if memoryUsageMB > memoryThresholdMB {
                addAlert(.highMemory(memoryUsageMB))
            }
        }
    }
    
    private func updateCPUUsage() {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                        PROCESSOR_CPU_LOAD_INFO,
                                        &numCpus,
                                        &cpuInfo,
                                        &numCpuInfo)
        
        if result == KERN_SUCCESS {
            var totalUsage: Double = 0
            
            for i in 0..<Int32(numCpus) {
                let offset = Int(CPU_STATE_MAX * i)
                let user = Double(cpuInfo[offset + Int(CPU_STATE_USER)])
                let system = Double(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
                let idle = Double(cpuInfo[offset + Int(CPU_STATE_IDLE)])
                let nice = Double(cpuInfo[offset + Int(CPU_STATE_NICE)])
                
                let total = user + system + idle + nice
                if total > 0 {
                    totalUsage += (user + system) / total * 100
                }
            }
            
            cpuUsagePercent = totalUsage / Double(numCpus)
            
            // Check CPU threshold
            if cpuUsagePercent > cpuThresholdPercent {
                addAlert(.highCPU(cpuUsagePercent))
            }
            
            // Deallocate memory
            let size = vm_size_t(numCpuInfo)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }
    }
    
    private func checkPerformanceStatus() {
        let wasPerformanceDegraded = isPerformanceDegraded
        
        isPerformanceDegraded = fps < fpsThreshold ||
                                memoryUsageMB > memoryThresholdMB ||
                                cpuUsagePercent > cpuThresholdPercent ||
                                renderTimeMs > renderTimeThresholdMs
        
        if isPerformanceDegraded && !wasPerformanceDegraded {
            logger.warning("⚠️ Performance degradation detected")
            addAlert(.performanceDegraded)
        } else if !isPerformanceDegraded && wasPerformanceDegraded {
            logger.info("✅ Performance recovered")
            addAlert(.performanceRecovered)
        }
    }
    
    private func addAlert(_ alert: PerformanceAlert) {
        alerts.append(alert)
        
        // Keep only last 10 alerts
        if alerts.count > 10 {
            alerts.removeFirst(alerts.count - 10)
        }
        
        // Log alert
        logger.warning("📊 Performance Alert: \(alert.message)")
    }
}

// MARK: - Performance Alert
public struct PerformanceAlert: Identifiable {
    public let id = UUID()
    public let timestamp = Date()
    public let type: AlertType
    public let message: String
    
    public enum AlertType {
        case lowFPS(Double)
        case highMemory(Double)
        case highCPU(Double)
        case highRenderTime(Double)
        case performanceDegraded
        case performanceRecovered
        
        var message: String {
            switch self {
            case .lowFPS(let fps):
                return "FPS dropped to \(String(format: "%.1f", fps))"
            case .highMemory(let mb):
                return "Memory usage: \(String(format: "%.1f", mb)) MB"
            case .highCPU(let percent):
                return "CPU usage: \(String(format: "%.1f", percent))%"
            case .highRenderTime(let ms):
                return "Render time: \(String(format: "%.2f", ms)) ms"
            case .performanceDegraded:
                return "Performance degradation detected"
            case .performanceRecovered:
                return "Performance recovered"
            }
        }
    }
    
    init(_ type: AlertType) {
        self.type = type
        self.message = type.message
    }
}

// MARK: - Performance View Modifier
public struct PerformanceOverlayModifier: ViewModifier {
    @StateObject private var monitor = PerformanceMonitor.shared
    @State private var showOverlay = false
    
    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if showOverlay {
                    performanceOverlay
                }
            }
            .onAppear {
                #if DEBUG
                showOverlay = ProcessInfo.processInfo.environment["SHOW_PERFORMANCE"] != nil
                #endif
            }
    }
    
    private var performanceOverlay: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Text("FPS")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.7))
                Text(String(format: "%.0f", monitor.fps))
                    .font(.caption2.bold())
                    .foregroundStyle(monitor.fps < 55 ? CyberpunkTheme.Colors.neonPink : CyberpunkTheme.Colors.neonGreen)
            }
            
            HStack(spacing: 4) {
                Text("MEM")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.7))
                Text(String(format: "%.0f MB", monitor.memoryUsageMB))
                    .font(.caption2.bold())
                    .foregroundStyle(monitor.memoryUsageMB > 200 ? CyberpunkTheme.Colors.neonPink : CyberpunkTheme.Colors.neonCyan)
            }
            
            HStack(spacing: 4) {
                Text("CPU")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.7))
                Text(String(format: "%.0f%%", monitor.cpuUsagePercent))
                    .font(.caption2.bold())
                    .foregroundStyle(monitor.cpuUsagePercent > 80 ? CyberpunkTheme.Colors.neonPink : CyberpunkTheme.Colors.electricYellow)
            }
            
            if monitor.isPerformanceDegraded {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(CyberpunkTheme.Colors.neonPink)
                    .glitchEffect()
            }
        }
        .padding(8)
        .background(CyberpunkTheme.Colors.darkBg.opacity(0.9))
        .cyberpunkBorder(monitor.isPerformanceDegraded ? CyberpunkTheme.Colors.neonPink : CyberpunkTheme.Colors.neonCyan)
        .padding()
    }
}

// MARK: - View Extension
extension View {
    public func performanceOverlay() -> some View {
        modifier(PerformanceOverlayModifier())
    }
}