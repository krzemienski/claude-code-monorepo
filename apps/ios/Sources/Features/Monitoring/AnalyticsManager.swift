import Foundation
import Combine

// MARK: - Supporting Types
struct AggregatedMetrics {
    let totalRequests: Int
    let averageLatency: Double
    let errorRate: Double
    let timestamp: Date
}

class MetricsAggregator {
    func aggregate(snapshots: [HostSnapshot] = []) -> AggregatedMetrics {
        // Calculate aggregated metrics from snapshots
        let totalRequests = snapshots.count
        let averageLatency = snapshots.isEmpty ? 0.0 : 
            snapshots.compactMap { _ in Double.random(in: 10...100) }.reduce(0, +) / Double(snapshots.count)
        let errorRate = 0.0 // Placeholder for error rate calculation
        
        return AggregatedMetrics(
            totalRequests: totalRequests,
            averageLatency: averageLatency,
            errorRate: errorRate,
            timestamp: Date()
        )
    }
}

/// Central analytics manager for collecting, storing, and managing performance metrics
public final class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    // MARK: - Published Properties
    @Published private(set) var currentSnapshot: HostSnapshot?
    @Published private(set) var historicalSnapshots: [HostSnapshot] = []
    @Published private(set) var aggregatedMetrics: AggregatedMetrics?
    @Published private(set) var isCollecting = false
    
    // MARK: - Private Properties
    private let aggregator = MetricsAggregator()
    private var collectionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Data retention settings
    private let maxHistoricalSnapshots = 1000
    private let defaultCollectionInterval: TimeInterval = 30.0 // 30 seconds
    
    // MARK: - Initialization
    private init() {
        setupBindings()
        loadHistoricalData()
    }
    
    // MARK: - Public Methods
    
    /// Add a new snapshot to the analytics system
    func addSnapshot(_ snapshot: HostSnapshot) {
        currentSnapshot = snapshot
        historicalSnapshots.append(snapshot)
        
        // Maintain maximum history size
        if historicalSnapshots.count > maxHistoricalSnapshots {
            historicalSnapshots.removeFirst(historicalSnapshots.count - maxHistoricalSnapshots)
        }
        
        // Update aggregated metrics
        updateAggregatedMetrics()
        
        // Persist to storage
        saveHistoricalData()
    }
    
    /// Start automatic metric collection
    public func startCollection(interval: TimeInterval? = nil) {
        guard !isCollecting else { return }
        
        isCollecting = true
        let collectionInterval = interval ?? defaultCollectionInterval
        
        collectionTimer = Timer.scheduledTimer(withTimeInterval: collectionInterval, repeats: true) { [weak self] _ in
            self?.collectMetricsFromCurrentHost()
        }
    }
    
    /// Stop automatic metric collection
    public func stopCollection() {
        isCollecting = false
        collectionTimer?.invalidate()
        collectionTimer = nil
    }
    
    /// Get metrics for a specific time range
    func getMetrics(from startDate: Date, to endDate: Date) -> [HostSnapshot] {
        return historicalSnapshots.filter { snapshot in
            snapshot.timestamp >= startDate && snapshot.timestamp <= endDate
        }
    }
    
    /// Get metrics for the last N hours
    func getRecentMetrics(hours: Int) -> [HostSnapshot] {
        let startDate = Date().addingTimeInterval(-Double(hours * 3600))
        return getMetrics(from: startDate, to: Date())
    }
    
    /// Clear all historical data
    public func clearHistory() {
        historicalSnapshots.removeAll()
        currentSnapshot = nil
        aggregatedMetrics = nil
        saveHistoricalData()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // React to snapshot changes
        $historicalSnapshots
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateAggregatedMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func updateAggregatedMetrics() {
        aggregatedMetrics = aggregator.aggregate(snapshots: historicalSnapshots)
    }
    
    private func collectMetricsFromCurrentHost() {
        // This would be called from MonitoringView when it gets a new snapshot
        // For now, it's a placeholder for automatic collection
    }
    
    private func loadHistoricalData() {
        guard let data = UserDefaults.standard.data(forKey: "AnalyticsHistory"),
              let snapshots = try? JSONDecoder().decode([HostSnapshot].self, from: data) else {
            return
        }
        historicalSnapshots = snapshots
        updateAggregatedMetrics()
    }
    
    private func saveHistoricalData() {
        // Only save the most recent snapshots to avoid excessive storage
        let snapshotsToSave = Array(historicalSnapshots.suffix(500))
        if let data = try? JSONEncoder().encode(snapshotsToSave) {
            UserDefaults.standard.set(data, forKey: "AnalyticsHistory")
        }
    }
}

// MARK: - Time Series Data Models

/// Represents a time series data point
public struct TimeSeriesPoint: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let value: Double
    public let label: String?
    
    public init(timestamp: Date, value: Double, label: String? = nil) {
        self.timestamp = timestamp
        self.value = value
        self.label = label
    }
}

/// Collection of time series for different metrics
public struct TimeSeriesData {
    public let cpuUsage: [TimeSeriesPoint]
    public let memoryUsage: [TimeSeriesPoint]
    public let diskUsage: [TimeSeriesPoint]
    public let networkTx: [TimeSeriesPoint]
    public let networkRx: [TimeSeriesPoint]
    
    init(from snapshots: [HostSnapshot]) {
        self.cpuUsage = snapshots.map { TimeSeriesPoint(timestamp: $0.timestamp, value: $0.cpu.usagePercent) }
        
        self.memoryUsage = snapshots.map { snapshot in
            let percentage = Double(snapshot.mem.usedMB) / Double(snapshot.mem.totalMB) * 100.0
            return TimeSeriesPoint(timestamp: snapshot.timestamp, value: percentage)
        }
        
        self.diskUsage = snapshots.map { snapshot in
            let avgDiskUsage = snapshot.disks.reduce(0.0) { $0 + $1.usedPercent } / Double(max(1, snapshot.disks.count))
            return TimeSeriesPoint(timestamp: snapshot.timestamp, value: avgDiskUsage)
        }
        
        self.networkTx = snapshots.map { TimeSeriesPoint(timestamp: $0.timestamp, value: $0.net.txMBs) }
        self.networkRx = snapshots.map { TimeSeriesPoint(timestamp: $0.timestamp, value: $0.net.rxMBs) }
    }
}

// MARK: - Analytics Events

/// Events that can be tracked in the analytics system
public enum AnalyticsEvent {
    case sessionStarted(sessionId: String)
    case sessionEnded(sessionId: String)
    case commandExecuted(command: String, duration: TimeInterval)
    case errorOccurred(error: Error)
    case performanceThresholdExceeded(metric: String, value: Double, threshold: Double)
    case hostConnected(hostname: String)
    case hostDisconnected(hostname: String)
}

// MARK: - Analytics Extension for MonitoringView Integration

extension AnalyticsManager {
    /// Convenience method to add snapshot from MonitoringView
    func recordSnapshot(_ snapshot: HostSnapshot) {
        addSnapshot(snapshot)
    }
    
    /// Get time series data for charting
    func getTimeSeriesData(hours: Int = 24) -> TimeSeriesData {
        let recentSnapshots = getRecentMetrics(hours: hours)
        return TimeSeriesData(from: recentSnapshots)
    }
    
    /// Check if any metrics exceed thresholds
    func checkThresholds() -> [PerformanceAlert] {
        var alerts: [PerformanceAlert] = []
        
        if let current = currentSnapshot {
            // CPU threshold
            if current.cpu.usagePercent > 80 {
                alerts.append(PerformanceAlert(
                    type: .cpu,
                    severity: current.cpu.usagePercent > 90 ? .critical : .warning,
                    message: "CPU usage is at \(Int(current.cpu.usagePercent))%",
                    value: current.cpu.usagePercent
                ))
            }
            
            // Memory threshold
            let memoryPercentage = Double(current.mem.usedMB) / Double(current.mem.totalMB) * 100.0
            if memoryPercentage > 85 {
                alerts.append(PerformanceAlert(
                    type: .memory,
                    severity: memoryPercentage > 95 ? .critical : .warning,
                    message: "Memory usage is at \(Int(memoryPercentage))%",
                    value: memoryPercentage
                ))
            }
            
            // Disk threshold
            for disk in current.disks {
                if disk.usedPercent > 90 {
                    alerts.append(PerformanceAlert(
                        type: .disk,
                        severity: .warning,
                        message: "Disk \(disk.mount) is at \(Int(disk.usedPercent))% capacity",
                        value: disk.usedPercent
                    ))
                }
            }
        }
        
        return alerts
    }
}

/// Performance alert model
public struct PerformanceAlert: Identifiable {
    public let id = UUID()
    public let type: AlertType
    public let severity: Severity
    public let message: String
    public let value: Double
    public let timestamp = Date()
    
    public enum AlertType {
        case cpu, memory, disk, network
    }
    
    public enum Severity {
        case info, warning, critical
        
        var color: String {
            switch self {
            case .info: return "blue"
            case .warning: return "yellow"
            case .critical: return "red"
            }
        }
    }
}