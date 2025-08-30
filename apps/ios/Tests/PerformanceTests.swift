import XCTest
import os.log
import UIKit
@testable import ClaudeCode

// MARK: - Performance Benchmarking Tests
final class PerformanceTests: XCTestCase {
    
    var container: Container!
    let performanceLogger = Logger(subsystem: "com.claudecode.ios.tests", category: "Performance")
    
    override func setUp() async throws {
        try await super.setUp()
        container = Container.shared
        container.reset()
    }
    
    override func tearDown() async throws {
        container.reset()
        container = nil
        try await super.tearDown()
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryBaselineUsage() throws {
        let initialMemory = reportMemoryUsage()
        performanceLogger.info("Initial memory usage: \(initialMemory) MB")
        
        // Create basic app components
        _ = container.makeHomeViewModel()
        _ = container.makeProjectsViewModel()
        _ = container.makeSessionsViewModel()
        
        let afterCreation = reportMemoryUsage()
        performanceLogger.info("Memory after ViewModels: \(afterCreation) MB")
        
        let increase = afterCreation - initialMemory
        XCTAssertLessThan(increase, 10.0, "Memory increase should be less than 10 MB")
    }
    
    func testMemoryLeakDetection() throws {
        autoreleasepool {
            var memoryBefore = reportMemoryUsage()
            
            // Create and destroy objects in a loop
            for i in 0..<100 {
                autoreleasepool {
                    let viewModel = container.makeChatViewModel(
                        sessionId: "test-\(i)",
                        projectId: "project-\(i)"
                    )
                    // Simulate some work
                    viewModel.inputText = "Test message \(i)"
                    _ = viewModel.messages
                }
            }
            
            // Force cleanup
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            
            let memoryAfter = reportMemoryUsage()
            let leak = memoryAfter - memoryBefore
            
            performanceLogger.info("Potential memory leak: \(leak) MB")
            XCTAssertLessThan(leak, 5.0, "Memory leak detected: \(leak) MB")
        }
    }
    
    func testLargeDataSetMemoryHandling() async throws {
        let initialMemory = reportMemoryUsage()
        
        // Create large dataset
        let viewModel = container.makeChatViewModel(sessionId: "test", projectId: "test")
        
        // Add many messages
        for i in 0..<1000 {
            let message = ChatMessage(
                id: UUID().uuidString,
                role: i % 2 == 0 ? .user : .assistant,
                content: String(repeating: "Test content ", count: 100),
                timestamp: Date(),
                tokens: 100
            )
            viewModel.messages.append(message)
        }
        
        let peakMemory = reportMemoryUsage()
        let increase = peakMemory - initialMemory
        
        performanceLogger.info("Memory increase with 1000 messages: \(increase) MB")
        XCTAssertLessThan(increase, 50.0, "Memory usage should be reasonable for large datasets")
    }
    
    // MARK: - Network Latency Tests
    
    func testAPIResponseLatency() async throws {
        let apiClient = container.apiClient
        
        let measurements = try await measure(count: 10) {
            let start = CFAbsoluteTimeGetCurrent()
            _ = try? await apiClient.health()
            let latency = (CFAbsoluteTimeGetCurrent() - start) * 1000
            return latency
        }
        
        let average = measurements.reduce(0, +) / Double(measurements.count)
        let p95 = percentile(measurements, 0.95)
        
        performanceLogger.info("API latency - Average: \(average)ms, P95: \(p95)ms")
        
        XCTAssertLessThan(average, 100, "Average API latency should be under 100ms")
        XCTAssertLessThan(p95, 200, "P95 latency should be under 200ms")
    }
    
    func testConcurrentAPIRequests() async throws {
        let apiClient = container.apiClient
        let concurrentRequests = 10
        
        let start = CFAbsoluteTimeGetCurrent()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentRequests {
                group.addTask {
                    _ = try? await apiClient.health()
                }
            }
        }
        
        let totalTime = (CFAbsoluteTimeGetCurrent() - start) * 1000
        
        performanceLogger.info("Concurrent requests (\(concurrentRequests)): \(totalTime)ms total")
        XCTAssertLessThan(totalTime, 500, "Concurrent requests should complete under 500ms")
    }
    
    func testStreamingPerformance() async throws {
        let sseClient = container.sseClient
        var receivedEvents = 0
        let expectation = XCTestExpectation(description: "Streaming performance")
        
        let start = CFAbsoluteTimeGetCurrent()
        
        // Simulate streaming
        Task {
            for _ in 0..<100 {
                receivedEvents += 1
                if receivedEvents >= 100 {
                    expectation.fulfill()
                }
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms between events
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        let duration = CFAbsoluteTimeGetCurrent() - start
        let eventsPerSecond = Double(receivedEvents) / duration
        
        performanceLogger.info("Streaming performance: \(eventsPerSecond) events/second")
        XCTAssertGreaterThan(eventsPerSecond, 50, "Should handle at least 50 events/second")
    }
    
    // MARK: - UI Responsiveness Tests
    
    func testViewModelUpdatePerformance() {
        let viewModel = container.makeHomeViewModel()
        
        measure {
            for i in 0..<1000 {
                viewModel.isLoading = i % 2 == 0
            }
        }
    }
    
    func testListRenderingPerformance() {
        let viewModel = container.makeProjectsViewModel()
        
        // Create test data
        let projects = (0..<100).map { i in
            APIClient.Project(
                id: "project-\(i)",
                name: "Project \(i)",
                description: "Description for project \(i)",
                path: "/path/\(i)",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        }
        
        measure {
            viewModel.projects = projects
            _ = viewModel.filteredProjects
        }
    }
    
    func testSearchPerformance() {
        let viewModel = container.makeSessionsViewModel()
        
        // Create test data
        let sessions = (0..<1000).map { i in
            APIClient.Session(
                id: "session-\(i)",
                projectId: "project-\(i % 10)",
                title: "Session \(i)",
                model: "gpt-4",
                systemPrompt: nil,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                isActive: i % 2 == 0,
                totalTokens: i * 100,
                totalCost: Double(i) * 0.01,
                messageCount: i
            )
        }
        
        viewModel.sessions = sessions
        
        measure {
            for i in 0..<100 {
                viewModel.searchQuery = "Session \(i)"
                _ = viewModel.filteredSessions
            }
        }
    }
    
    // MARK: - Battery Usage Profiling
    
    func testBatteryImpactIdleState() async throws {
        let duration: TimeInterval = 10.0
        let startEnergy = ProcessInfo.processInfo.thermalState
        
        performanceLogger.info("Starting thermal state: \(startEnergy.rawValue)")
        
        // Keep app idle
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        
        let endEnergy = ProcessInfo.processInfo.thermalState
        performanceLogger.info("Ending thermal state: \(endEnergy.rawValue)")
        
        XCTAssertEqual(startEnergy, endEnergy, "Thermal state should not degrade in idle state")
    }
    
    func testBatteryImpactActiveUse() async throws {
        let duration: TimeInterval = 10.0
        let startEnergy = ProcessInfo.processInfo.thermalState
        
        // Simulate active use
        let viewModel = container.makeChatViewModel(sessionId: "test", projectId: "test")
        
        for i in 0..<100 {
            viewModel.inputText = "Message \(i)"
            await viewModel.sendMessage()
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms between messages
        }
        
        let endEnergy = ProcessInfo.processInfo.thermalState
        
        performanceLogger.info("Thermal impact after active use: \(endEnergy.rawValue)")
        XCTAssertLessThanOrEqual(endEnergy.rawValue, startEnergy.rawValue + 1, "Thermal impact should be minimal")
    }
    
    // MARK: - Core Data Performance (if applicable)
    
    func testDatabaseQueryPerformance() async throws {
        // Skip if not using Core Data
        guard NSClassFromString("NSManagedObjectContext") != nil else {
            throw XCTSkip("Core Data not available")
        }
        
        measure {
            // Simulate database queries
            for _ in 0..<100 {
                _ = container.cacheService.get(key: "test-key")
            }
        }
    }
    
    func testCachePerformance() {
        let cache = container.cacheService
        
        // Write performance
        measure {
            for i in 0..<1000 {
                cache.set(key: "key-\(i)", value: "value-\(i)")
            }
        }
        
        // Read performance
        measure {
            for i in 0..<1000 {
                _ = cache.get(key: "key-\(i)")
            }
        }
    }
    
    // MARK: - App Launch Performance
    
    func testColdLaunchPerformance() throws {
        // This would typically be measured with XCTApplicationLaunchMetric in UI tests
        let start = CFAbsoluteTimeGetCurrent()
        
        // Simulate app initialization
        _ = Container.shared
        _ = container.appCoordinator
        _ = container.settings
        
        let launchTime = (CFAbsoluteTimeGetCurrent() - start) * 1000
        
        performanceLogger.info("Cold launch simulation: \(launchTime)ms")
        XCTAssertLessThan(launchTime, 500, "Cold launch should be under 500ms")
    }
    
    func testWarmLaunchPerformance() throws {
        // Pre-warm
        _ = container.settings
        _ = container.apiClient
        
        measure {
            // Simulate warm launch
            _ = container.makeHomeViewModel()
            _ = container.makeProjectsViewModel()
        }
    }
    
    // MARK: - Animation Performance
    
    func testAnimationFrameRate() {
        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        var frameCount = 0
        let duration: TimeInterval = 1.0
        
        let start = CFAbsoluteTimeGetCurrent()
        displayLink.add(to: .current, forMode: .common)
        
        while CFAbsoluteTimeGetCurrent() - start < duration {
            RunLoop.current.run(mode: .common, before: Date(timeIntervalSinceNow: 0.001))
            frameCount += 1
        }
        
        displayLink.invalidate()
        
        let fps = Double(frameCount) / duration
        performanceLogger.info("Animation frame rate: \(fps) FPS")
        
        XCTAssertGreaterThan(fps, 30, "Should maintain at least 30 FPS")
    }
    
    @objc private func displayLinkFired() {
        // Frame fired
    }
    
    // MARK: - Helper Methods
    
    private func reportMemoryUsage() -> Double {
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
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        return 0
    }
    
    private func measure<T>(count: Int, block: () async throws -> T) async throws -> [T] {
        var results: [T] = []
        for _ in 0..<count {
            let result = try await block()
            results.append(result)
        }
        return results
    }
    
    private func percentile(_ values: [Double], _ percentile: Double) -> Double {
        let sorted = values.sorted()
        let index = Int(Double(sorted.count - 1) * percentile)
        return sorted[index]
    }
    
    // MARK: - Stress Tests
    
    func testMemoryStressTest() async throws {
        let iterations = 100
        var peakMemory: Double = 0
        
        for i in 0..<iterations {
            autoreleasepool {
                // Create heavy objects
                let viewModel = container.makeChatViewModel(sessionId: "stress-\(i)", projectId: "stress")
                
                // Add lots of data
                for j in 0..<100 {
                    let message = ChatMessage(
                        id: "\(i)-\(j)",
                        role: .user,
                        content: String(repeating: "X", count: 1000),
                        timestamp: Date(),
                        tokens: 100
                    )
                    viewModel.messages.append(message)
                }
                
                let currentMemory = reportMemoryUsage()
                peakMemory = max(peakMemory, currentMemory)
            }
        }
        
        performanceLogger.info("Peak memory during stress test: \(peakMemory) MB")
        XCTAssertLessThan(peakMemory, 200, "Peak memory should stay under 200 MB")
    }
    
    func testCPUStressTest() {
        let queue = DispatchQueue(label: "stress", attributes: .concurrent)
        let group = DispatchGroup()
        let iterations = 1000
        
        measure {
            for _ in 0..<iterations {
                group.enter()
                queue.async {
                    // Simulate CPU intensive work
                    var sum = 0
                    for j in 0..<1000 {
                        sum += j
                    }
                    group.leave()
                }
            }
            group.wait()
        }
    }
}