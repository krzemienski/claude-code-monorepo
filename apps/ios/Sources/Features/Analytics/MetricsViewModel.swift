import SwiftUI
import Combine
import Foundation

/// 📊 Metrics ViewModel for Real-time Analytics
@MainActor
public class MetricsViewModel: ObservableObject {
    // Performance Metrics
    @Published var currentFPS: Double = 60.0
    @Published var memoryUsageMB: Double = 45.2
    @Published var cpuUsage: Double = 12.5
    @Published var apiLatency: Double = 125.0
    
    // Token Usage
    @Published var tokenUsageData: [TokenDataPoint] = []
    
    // Cost Tracking
    @Published var todayCost: Double = 3.45
    @Published var weekCost: Double = 24.78
    @Published var monthCost: Double = 89.99
    
    // Session Statistics
    @Published var activeSessions: Int = 3
    @Published var totalSessions: Int = 147
    @Published var avgDuration: String = "12m"
    @Published var totalMessages: Int = 4829
    @Published var toolsExecuted: Int = 342
    @Published var successRate: Int = 97
    
    private var cancellables = Set<AnyCancellable>()
    private let performanceMonitor = PerformanceMonitor.shared
    
    init() {
        setupPerformanceObservers()
        generateMockTokenData()
    }
    
    private func setupPerformanceObservers() {
        // Subscribe to performance updates
        performanceMonitor.$fps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fps in
                self?.currentFPS = fps
            }
            .store(in: &cancellables)
        
        performanceMonitor.$memoryUsageMB
            .receive(on: DispatchQueue.main)
            .sink { [weak self] memory in
                self?.memoryUsageMB = memory
            }
            .store(in: &cancellables)
        
        performanceMonitor.$cpuUsagePercent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cpu in
                self?.cpuUsage = cpu
            }
            .store(in: &cancellables)
    }
    
    private func generateMockTokenData() {
        let now = Date()
        tokenUsageData = (0..<20).map { i in
            TokenDataPoint(
                timestamp: now.addingTimeInterval(Double(i) * -3600),
                tokens: Int.random(in: 1000...8000)
            )
        }.reversed()
    }
    
    public func loadMetrics() async {
        // Simulate loading metrics
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Update with real-time data
        await MainActor.run {
            self.currentFPS = performanceMonitor.fps
            self.memoryUsageMB = performanceMonitor.memoryUsageMB
            self.cpuUsage = performanceMonitor.cpuUsagePercent
        }
    }
}

public struct TokenDataPoint: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let tokens: Int
}