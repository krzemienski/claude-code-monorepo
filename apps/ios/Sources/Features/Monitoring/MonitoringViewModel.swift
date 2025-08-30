import SwiftUI
import Combine
import Foundation
import os.log

// MARK: - Monitoring View Model
@MainActor
final class MonitoringViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var hostname: String = "localhost"
    @Published var username: String = "user"
    @Published var password: String = ""
    @Published var snapshot: HostSnapshot?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var monitoringEnabled: Bool = false
    @Published var refreshInterval: TimeInterval = 5.0
    @Published var hostPlatform: HostPlatform = .auto
    
    // MARK: - Host Platform
    enum HostPlatform {
        case auto
        case linux
        case macOS
        
        var displayName: String {
            switch self {
            case .auto: return "Auto-detect"
            case .linux: return "Linux"
            case .macOS: return "macOS"
            }
        }
    }
    
    // MARK: - Private Properties
    // SSH monitoring service has been removed - needs backend API integration
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode", category: "MonitoringViewModel")
    private var monitoringTimer: Timer?
    
    // MARK: - Combine Publishers
    var snapshotPublisher: AnyPublisher<HostSnapshot?, Never> {
        $snapshot.eraseToAnyPublisher()
    }
    
    var loadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }
    
    // MARK: - Computed Properties
    var hasSnapshot: Bool {
        snapshot != nil
    }
    
    var hasError: Bool {
        error != nil
    }
    
    var errorMessage: String? {
        error?.localizedDescription
    }
    
    var cpuUsage: String {
        guard let snapshot = snapshot else { return "N/A" }
        return String(format: "%.1f%%", snapshot.cpu.usagePercent)
    }
    
    var memoryUsage: String {
        guard let snapshot = snapshot else { return "N/A" }
        return "\(snapshot.mem.usedMB) / \(snapshot.mem.totalMB) MB"
    }
    
    var memoryPercent: Double {
        guard let snapshot = snapshot else { return 0 }
        return Double(snapshot.mem.usedMB) / Double(snapshot.mem.totalMB) * 100
    }
    
    var networkStats: String {
        guard let snapshot = snapshot else { return "N/A" }
        return String(format: "↑%.1f ↓%.1f MB/s", snapshot.net.txMBs, snapshot.net.rxMBs)
    }
    
    var systemHealth: SystemHealth {
        guard let snapshot = snapshot else { return .unknown }
        
        let cpuScore = snapshot.cpu.usagePercent > 80 ? 2 : (snapshot.cpu.usagePercent > 50 ? 1 : 0)
        let memScore = memoryPercent > 80 ? 2 : (memoryPercent > 50 ? 1 : 0)
        let diskScore = (snapshot.disks.first?.usedPercent ?? 0) > 80 ? 2 : 
                       ((snapshot.disks.first?.usedPercent ?? 0) > 50 ? 1 : 0)
        
        let totalScore = cpuScore + memScore + diskScore
        
        if totalScore >= 4 { return .critical }
        if totalScore >= 2 { return .warning }
        return .healthy
    }
    
    enum SystemHealth {
        case healthy, warning, critical, unknown
        
        var color: Color {
            switch self {
            case .healthy: return .green
            case .warning: return .orange
            case .critical: return .red
            case .unknown: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.octagon.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }
        
        var description: String {
            switch self {
            case .healthy: return "System Healthy"
            case .warning: return "Performance Warning"
            case .critical: return "Critical State"
            case .unknown: return "Unknown Status"
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        // SSH functionality has been removed - monitoring will need backend API integration
        setupSubscriptions()
    }
    
    deinit {
        // Clean up without calling MainActor methods
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    // MARK: - Setup Methods
    private func setupSubscriptions() {
        // Auto-start monitoring when enabled
        $monitoringEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.startMonitoring()
                } else {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)
        
        // Update refresh interval
        $refreshInterval
            .sink { [weak self] interval in
                if self?.monitoringEnabled == true {
                    self?.stopMonitoring()
                    self?.startMonitoring()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func takeSnapshot() async {
        guard !hostname.isEmpty && !username.isEmpty else {
            error = NSError(domain: "MonitoringViewModel", code: -1, 
                          userInfo: [NSLocalizedDescriptionKey: "Hostname and username are required"])
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // SSH functionality has been removed
            // Mock data for demonstration
            _ = (
                hostname: hostname,
                username: username,
                password: password.isEmpty ? nil : password
            )
            
            let newSnapshot: HostSnapshot
            
            switch hostPlatform {
            case .auto:
                // Try Linux first, then macOS
                // SSH monitoring removed - return mock data
                throw NSError(domain: "Monitoring", code: -1, userInfo: [NSLocalizedDescriptionKey: "SSH monitoring not available"])
            case .linux:
                // SSH monitoring removed - return mock data
                throw NSError(domain: "Monitoring", code: -1, userInfo: [NSLocalizedDescriptionKey: "SSH monitoring not available"])
            case .macOS:
                // SSH monitoring removed - return mock data
                throw NSError(domain: "Monitoring", code: -1, userInfo: [NSLocalizedDescriptionKey: "SSH monitoring not available"])
            }
            
            await MainActor.run {
                self.snapshot = newSnapshot
                self.logger.info("Snapshot taken successfully for \(self.hostname)")
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.logger.error("Failed to take snapshot: \(error)")
            }
        }
        
        isLoading = false
    }
    
    func startMonitoring() {
        guard monitoringTimer == nil else { return }
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { await self?.takeSnapshot() }
        }
        
        // Take initial snapshot
        Task { await takeSnapshot() }
        
        logger.info("Started monitoring with interval: \(self.refreshInterval)s")
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        monitoringEnabled = false
        logger.info("Stopped monitoring")
    }
    
    func toggleMonitoring() {
        monitoringEnabled.toggle()
    }
    
    func clearError() {
        error = nil
    }
    
    func clearSnapshot() {
        snapshot = nil
    }
    
    // MARK: - Alert Thresholds
    func checkAlerts() -> [Alert] {
        guard let snapshot = snapshot else { return [] }
        
        var alerts: [Alert] = []
        
        // CPU Alert
        if snapshot.cpu.usagePercent > 80 {
            alerts.append(Alert(
                type: .cpu,
                severity: snapshot.cpu.usagePercent > 90 ? .critical : .warning,
                message: "High CPU usage: \(Int(snapshot.cpu.usagePercent))%"
            ))
        }
        
        // Memory Alert
        if memoryPercent > 80 {
            alerts.append(Alert(
                type: .memory,
                severity: memoryPercent > 90 ? .critical : .warning,
                message: "High memory usage: \(Int(memoryPercent))%"
            ))
        }
        
        // Disk Alerts
        for disk in snapshot.disks {
            if disk.usedPercent > 80 {
                alerts.append(Alert(
                    type: .disk,
                    severity: disk.usedPercent > 90 ? .critical : .warning,
                    message: "Disk \(disk.mount) is \(Int(disk.usedPercent))% full"
                ))
            }
        }
        
        return alerts
    }
    
    struct Alert: Identifiable {
        let id = UUID()
        let type: AlertType
        let severity: Severity
        let message: String
        let timestamp = Date()
        
        enum AlertType {
            case cpu, memory, disk, network
            
            var icon: String {
                switch self {
                case .cpu: return "cpu"
                case .memory: return "memorychip"
                case .disk: return "internaldrive"
                case .network: return "network"
                }
            }
        }
        
        enum Severity {
            case warning, critical
            
            var color: Color {
                switch self {
                case .warning: return .orange
                case .critical: return .red
                }
            }
        }
    }
}