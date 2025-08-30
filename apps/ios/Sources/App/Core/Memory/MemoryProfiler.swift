import Foundation
import OSLog
import os

// MARK: - Memory Profiler for Development

/// Memory profiling system for tracking allocations and detecting leaks
@available(iOS 15.0, *)
final class MemoryProfiler {
    
    static let shared = MemoryProfiler()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "MemoryProfiler")
    private let signposter = OSSignposter(subsystem: "com.claudecode.ios", category: "Memory")
    
    private var baselineMemory: Int64 = 0
    private var peakMemory: Int64 = 0
    private var allocationHistory: [AllocationEvent] = []
    private let historyLimit = 100
    
    #if DEBUG
    private var isEnabled = true
    #else
    private var isEnabled = false
    #endif
    
    // MARK: - Memory Tracking
    
    struct AllocationEvent {
        let timestamp: Date
        let size: Int64
        let context: String
        let stackTrace: [String]?
    }
    
    struct MemorySnapshot {
        let used: Int64
        let free: Int64
        let total: Int64
        let pressure: MemoryPressure
        
        var usedMB: Double {
            Double(used) / 1024 / 1024
        }
        
        var freeMB: Double {
            Double(free) / 1024 / 1024
        }
        
        var totalMB: Double {
            Double(total) / 1024 / 1024
        }
    }
    
    enum MemoryPressure {
        case normal
        case warning
        case urgent
        case critical
        
        var color: String {
            switch self {
            case .normal: return "🟢"
            case .warning: return "🟡"
            case .urgent: return "🟠"
            case .critical: return "🔴"
            }
        }
    }
    
    // MARK: - Public API
    
    /// Take a memory snapshot
    func snapshot() -> MemorySnapshot {
        let info = ProcessInfo.processInfo
        let physicalMemory = info.physicalMemory
        
        var vmInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &vmInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            logger.error("Failed to get memory info")
            return MemorySnapshot(used: 0, free: 0, total: Int64(physicalMemory), pressure: .normal)
        }
        
        let used = Int64(vmInfo.resident_size)
        let total = Int64(physicalMemory)
        let free = total - used
        
        // Update peak memory
        if used > peakMemory {
            peakMemory = used
        }
        
        // Calculate pressure
        let usagePercentage = Double(used) / Double(total) * 100
        let pressure: MemoryPressure
        switch usagePercentage {
        case 0..<50:
            pressure = .normal
        case 50..<70:
            pressure = .warning
        case 70..<85:
            pressure = .urgent
        default:
            pressure = .critical
        }
        
        return MemorySnapshot(used: used, free: free, total: total, pressure: pressure)
    }
    
    /// Start profiling a specific operation
    @discardableResult
    func profile<T>(
        operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ block: () throws -> T
    ) rethrows -> T {
        guard isEnabled else {
            return try block()
        }
        
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("Memory", id: signpostID, "\(operation)")
        
        let beforeSnapshot = snapshot()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            let afterSnapshot = snapshot()
            let memoryDelta = afterSnapshot.used - beforeSnapshot.used
            let duration = endTime - startTime
            
            signposter.endInterval("Memory", state)
            
            // Log if significant memory increase
            if memoryDelta > 1024 * 1024 { // More than 1MB
                let deltaMB = Double(memoryDelta) / 1024 / 1024
                logger.warning("⚠️ Memory increased by \(String(format: "%.2f", deltaMB))MB during \(operation) (took \(String(format: "%.3f", duration))s)")
                
                // Record allocation event
                recordAllocation(
                    size: memoryDelta,
                    context: "\(operation) at \(file):\(line)",
                    captureStackTrace: true
                )
            }
            
            // Log detailed metrics in debug
            #if DEBUG
            logger.debug("""
                📊 Memory Profile: \(operation)
                   Before: \(String(format: "%.2f", beforeSnapshot.usedMB))MB
                   After:  \(String(format: "%.2f", afterSnapshot.usedMB))MB
                   Delta:  \(String(format: "%.2f", Double(memoryDelta) / 1024 / 1024))MB
                   Time:   \(String(format: "%.3f", duration))s
                   Pressure: \(afterSnapshot.pressure.color)
                """)
            #endif
        }
        
        return try block()
    }
    
    /// Profile async operations
    @discardableResult
    func profileAsync<T>(
        operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ block: () async throws -> T
    ) async rethrows -> T {
        guard isEnabled else {
            return try await block()
        }
        
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("Memory", id: signpostID, "\(operation)")
        
        let beforeSnapshot = snapshot()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = try await block()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let afterSnapshot = snapshot()
        let memoryDelta = afterSnapshot.used - beforeSnapshot.used
        let duration = endTime - startTime
        
        signposter.endInterval("Memory", state)
        
        // Log if significant memory increase
        if memoryDelta > 1024 * 1024 { // More than 1MB
            let deltaMB = Double(memoryDelta) / 1024 / 1024
            logger.warning("⚠️ Memory increased by \(String(format: "%.2f", deltaMB))MB during \(operation) (took \(String(format: "%.3f", duration))s)")
            
            recordAllocation(
                size: memoryDelta,
                context: "\(operation) at \(file):\(line)",
                captureStackTrace: true
            )
        }
        
        #if DEBUG
        logger.debug("""
            📊 Memory Profile: \(operation)
               Before: \(String(format: "%.2f", beforeSnapshot.usedMB))MB
               After:  \(String(format: "%.2f", afterSnapshot.usedMB))MB
               Delta:  \(String(format: "%.2f", Double(memoryDelta) / 1024 / 1024))MB
               Time:   \(String(format: "%.3f", duration))s
               Pressure: \(afterSnapshot.pressure.color)
            """)
        #endif
        
        return result
    }
    
    // MARK: - Leak Detection
    
    /// Check for potential memory leaks
    func checkForLeaks() {
        guard isEnabled else { return }
        
        let currentSnapshot = snapshot()
        let memoryGrowth = currentSnapshot.used - baselineMemory
        
        if memoryGrowth > 50 * 1024 * 1024 { // More than 50MB growth
            let growthMB = Double(memoryGrowth) / 1024 / 1024
            logger.error("🚨 Potential memory leak detected! Memory grew by \(String(format: "%.2f", growthMB))MB since baseline")
            
            // Analyze allocation history
            analyzeAllocationHistory()
        }
    }
    
    /// Set baseline memory for leak detection
    func setBaseline() {
        baselineMemory = snapshot().used
        logger.info("📍 Memory baseline set: \(String(format: "%.2f", Double(self.baselineMemory) / 1024 / 1024))MB")
    }
    
    // MARK: - Weak Reference Tracking
    
    /// Track weak references to detect retain cycles
    func trackWeakReference<T: AnyObject>(
        _ object: T,
        context: String
    ) {
        guard isEnabled else { return }
        
        weak var weakRef = object
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if weakRef != nil {
                self?.logger.warning("⚠️ Object still alive after 5 seconds: \(context)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func recordAllocation(
        size: Int64,
        context: String,
        captureStackTrace: Bool
    ) {
        let event = AllocationEvent(
            timestamp: Date(),
            size: size,
            context: context,
            stackTrace: captureStackTrace ? Thread.callStackSymbols : nil
        )
        
        allocationHistory.append(event)
        
        // Limit history size
        if allocationHistory.count > historyLimit {
            allocationHistory.removeFirst()
        }
    }
    
    private func analyzeAllocationHistory() {
        let recentAllocations = allocationHistory.suffix(20)
        
        logger.info("📊 Recent allocation analysis:")
        for event in recentAllocations {
            let sizeMB = Double(event.size) / 1024 / 1024
            logger.info("  - \(event.context): \(String(format: "%.2f", sizeMB))MB at \(event.timestamp)")
        }
        
        // Find largest allocations
        let largestAllocations = allocationHistory.sorted { $0.size > $1.size }.prefix(5)
        logger.info("🔝 Top 5 largest allocations:")
        for event in largestAllocations {
            let sizeMB = Double(event.size) / 1024 / 1024
            logger.info("  - \(event.context): \(String(format: "%.2f", sizeMB))MB")
        }
    }
    
    // MARK: - Report Generation
    
    func generateReport() -> String {
        let snapshot = snapshot()
        let growthSinceBaseline = snapshot.used - baselineMemory
        
        return """
        📊 Memory Report
        ================
        Current Memory: \(String(format: "%.2f", snapshot.usedMB))MB
        Peak Memory: \(String(format: "%.2f", Double(peakMemory) / 1024 / 1024))MB
        Free Memory: \(String(format: "%.2f", snapshot.freeMB))MB
        Total Memory: \(String(format: "%.2f", snapshot.totalMB))MB
        Memory Pressure: \(snapshot.pressure.color) \(snapshot.pressure)
        Growth Since Baseline: \(String(format: "%.2f", Double(growthSinceBaseline) / 1024 / 1024))MB
        
        Recent Allocations: \(allocationHistory.count)
        """
    }
}

// MARK: - SwiftUI Integration

#if DEBUG
import SwiftUI

struct MemoryProfilerView: View {
    @State private var snapshot = MemoryProfiler.shared.snapshot()
    @State private var report = MemoryProfiler.shared.generateReport()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Memory Usage")
                .font(.headline)
            
            HStack {
                Text("Used:")
                Text("\(String(format: "%.2f", snapshot.usedMB))MB")
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(snapshot.pressure.color)
                Text("\(snapshot.pressure)")
            }
            
            ProgressView(value: snapshot.usedMB, total: snapshot.totalMB)
                .progressViewStyle(.linear)
            
            Button("Check for Leaks") {
                MemoryProfiler.shared.checkForLeaks()
            }
            
            Button("Set Baseline") {
                MemoryProfiler.shared.setBaseline()
            }
            
            ScrollView {
                Text(report)
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .padding()
        .onReceive(timer) { _ in
            snapshot = MemoryProfiler.shared.snapshot()
            report = MemoryProfiler.shared.generateReport()
        }
    }
}
#endif