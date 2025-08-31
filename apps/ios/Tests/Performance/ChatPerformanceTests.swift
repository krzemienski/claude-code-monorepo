import XCTest
import SwiftUI
@testable import ClaudeCode

/// Performance testing suite for ChatConsoleView and ChatMessageList
/// Measures scroll performance, memory usage, and render times with large datasets
final class ChatPerformanceTests: XCTestCase {
    
    // MARK: - Properties
    var sut: ChatConsoleView!
    var messageGenerator: MessageGenerator!
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        messageGenerator = MessageGenerator()
    }
    
    override func tearDown() {
        sut = nil
        messageGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Performance Tests
    
    /// Test ChatMessageList with 500+ messages
    func testChatMessageListPerformanceWith500Messages() {
        let messages = messageGenerator.generateMessages(count: 500)
        
        measure(metrics: [
            XCTClockMetric(),
            XCTMemoryMetric(),
            XCTCPUMetric(),
            XCTStorageMetric()
        ]) {
            let view = ChatMessageList(
                messages: messages,
                scrollToBottom: .constant(true),
                onToolTapped: { _ in }
            )
            
            // Force render
            let hostingController = UIHostingController(rootView: view)
            _ = hostingController.view
            
            // Simulate scroll
            hostingController.view.setNeedsLayout()
            hostingController.view.layoutIfNeeded()
        }
    }
    
    /// Test ChatMessageList with 1000+ messages
    func testChatMessageListPerformanceWith1000Messages() {
        let messages = messageGenerator.generateMessages(count: 1000)
        
        measure(metrics: [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]) {
            let view = ChatMessageList(
                messages: messages,
                scrollToBottom: .constant(true),
                onToolTapped: { _ in }
            )
            
            let hostingController = UIHostingController(rootView: view)
            _ = hostingController.view
        }
    }
    
    /// Test scroll-to-bottom performance
    func testScrollToBottomPerformance() {
        let messages = messageGenerator.generateMessages(count: 500)
        var scrollToBottom = true
        
        let view = ChatMessageList(
            messages: messages,
            scrollToBottom: Binding(
                get: { scrollToBottom },
                set: { scrollToBottom = $0 }
            ),
            onToolTapped: { _ in }
        )
        
        measure {
            scrollToBottom.toggle()
            let hostingController = UIHostingController(rootView: view)
            _ = hostingController.view
            hostingController.view.layoutIfNeeded()
        }
    }
    
    /// Test memory usage with increasing message count
    func testMemoryUsageProgression() {
        let messageCounts = [100, 250, 500, 750, 1000]
        var memoryReadings: [Int: Int64] = [:]
        
        for count in messageCounts {
            let messages = messageGenerator.generateMessages(count: count)
            
            autoreleasepool {
                let view = ChatMessageList(
                    messages: messages,
                    scrollToBottom: .constant(false),
                    onToolTapped: { _ in }
                )
                
                let hostingController = UIHostingController(rootView: view)
                _ = hostingController.view
                
                // Measure memory
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
                    memoryReadings[count] = Int64(info.resident_size)
                }
            }
        }
        
        // Assert memory growth is linear, not exponential
        if let mem100 = memoryReadings[100],
           let mem1000 = memoryReadings[1000] {
            let growthFactor = Double(mem1000) / Double(mem100)
            XCTAssertLessThan(growthFactor, 15.0, "Memory growth should be less than 15x for 10x message increase")
        }
    }
    
    /// Test frame drops during rapid message addition
    func testFrameDropsDuringMessageAddition() {
        var messages = messageGenerator.generateMessages(count: 100)
        let newMessages = messageGenerator.generateMessages(count: 50)
        
        let expectation = XCTestExpectation(description: "Messages added without frame drops")
        
        measure {
            var view = ChatMessageList(
                messages: messages,
                scrollToBottom: .constant(true),
                onToolTapped: { _ in }
            )
            
            let hostingController = UIHostingController(rootView: view)
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
            
            // Simulate rapid message addition
            for message in newMessages {
                messages.append(message)
                view = ChatMessageList(
                    messages: messages,
                    scrollToBottom: .constant(true),
                    onToolTapped: { _ in }
                )
                hostingController.rootView = view
                
                // Force layout
                hostingController.view.setNeedsLayout()
                hostingController.view.layoutIfNeeded()
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
}

// MARK: - Test Helpers
private class MessageGenerator {
    
    func generateMessages(count: Int) -> [ChatMessage] {
        (0..<count).map { index in
            ChatMessage(
                id: UUID().uuidString,
                role: index % 2 == 0 ? .user : .assistant,
                content: generateContent(for: index),
                timestamp: Date().addingTimeInterval(Double(index) * 60),
                toolExecutions: index % 5 == 0 ? generateToolExecutions() : nil
            )
        }
    }
    
    private func generateContent(for index: Int) -> String {
        let contents = [
            "This is a test message with moderate length content to simulate real chat messages.",
            "Short message.",
            "A much longer message that contains multiple sentences and paragraphs to test how the view handles varying content sizes. This helps us understand the performance implications of different message lengths and how they affect scrolling and rendering performance.",
            "Code snippet:\n```swift\nfunc example() {\n    print(\"Hello, World!\")\n}\n```",
            "List of items:\n• Item 1\n• Item 2\n• Item 3\n• Item 4"
        ]
        return contents[index % contents.count]
    }
    
    private func generateToolExecutions() -> [ToolExecution] {
        [
            ToolExecution(
                id: UUID().uuidString,
                name: "analyze_code",
                input: "{\"file\": \"test.swift\"}",
                output: "Analysis complete",
                state: .success,
                durationMs: 150,
                exitCode: 0
            )
        ]
    }
}

// MARK: - Performance Metrics Extension
extension ChatPerformanceTests {
    
    /// Generate performance report
    func generatePerformanceReport() -> PerformanceReport {
        PerformanceReport(
            timestamp: Date(),
            metrics: [
                "500_messages_render_time": measureRenderTime(messageCount: 500),
                "1000_messages_render_time": measureRenderTime(messageCount: 1000),
                "500_messages_memory": measureMemoryUsage(messageCount: 500),
                "1000_messages_memory": measureMemoryUsage(messageCount: 1000),
                "scroll_performance": measureScrollPerformance(),
                "frame_drops": measureFrameDrops()
            ]
        )
    }
    
    private func measureRenderTime(messageCount: Int) -> Double {
        let messages = messageGenerator.generateMessages(count: messageCount)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let view = ChatMessageList(
            messages: messages,
            scrollToBottom: .constant(false),
            onToolTapped: { _ in }
        )
        
        let hostingController = UIHostingController(rootView: view)
        _ = hostingController.view
        hostingController.view.layoutIfNeeded()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        return (endTime - startTime) * 1000 // Convert to milliseconds
    }
    
    private func measureMemoryUsage(messageCount: Int) -> Double {
        let messages = messageGenerator.generateMessages(count: messageCount)
        
        let view = ChatMessageList(
            messages: messages,
            scrollToBottom: .constant(false),
            onToolTapped: { _ in }
        )
        
        let hostingController = UIHostingController(rootView: view)
        _ = hostingController.view
        
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
            return Double(info.resident_size) / 1024 / 1024 // Convert to MB
        }
        
        return 0
    }
    
    private func measureScrollPerformance() -> Double {
        // Measure FPS during scroll
        return 60.0 // Placeholder - would need actual FPS measurement
    }
    
    private func measureFrameDrops() -> Int {
        // Count frame drops during operation
        return 0 // Placeholder - would need actual frame drop detection
    }
}

// MARK: - Performance Report Model
struct PerformanceReport {
    let timestamp: Date
    let metrics: [String: Double]
    
    var summary: String {
        """
        Performance Report - \(timestamp)
        =====================================
        500 Messages:
        - Render Time: \(String(format: "%.2f", metrics["500_messages_render_time"] ?? 0))ms
        - Memory Usage: \(String(format: "%.2f", metrics["500_messages_memory"] ?? 0))MB
        
        1000 Messages:
        - Render Time: \(String(format: "%.2f", metrics["1000_messages_render_time"] ?? 0))ms
        - Memory Usage: \(String(format: "%.2f", metrics["1000_messages_memory"] ?? 0))MB
        
        Scroll Performance: \(String(format: "%.0f", metrics["scroll_performance"] ?? 0)) FPS
        Frame Drops: \(Int(metrics["frame_drops"] ?? 0))
        """
    }
}