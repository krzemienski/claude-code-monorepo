import XCTest
import Combine
@testable import ClaudeCode

// MARK: - Test Utilities

// TestError is defined in XCTestCase+Extensions.swift

// MARK: - Async Test Helpers

extension XCTestCase {
    /// Wait for an async condition to become true
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        description: String = "Condition met",
        condition: @escaping () async -> Bool
    ) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        XCTFail("Timeout waiting for: \(description)")
    }
    
    /// Execute async code and wait for completion
    func asyncTest(
        timeout: TimeInterval = 5.0,
        block: @escaping () async throws -> Void
    ) {
        let expectation = expectation(description: "Async test")
        
        Task {
            do {
                try await block()
                expectation.fulfill()
            } catch {
                XCTFail("Async test failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
    }
}

// MARK: - Combine Test Helpers

extension XCTestCase {
    /// Wait for a publisher to emit a value
    func waitForPublisher<P: Publisher>(
        _ publisher: P,
        timeout: TimeInterval = 2.0,
        description: String = "Publisher emitted"
    ) -> P.Output? where P.Failure == Never {
        let expectation = expectation(description: description)
        var result: P.Output?
        
        let cancellable = publisher
            .first()
            .sink { value in
                result = value
                expectation.fulfill()
            }
        
        wait(for: [expectation], timeout: timeout)
        _ = cancellable // Keep reference
        
        return result
    }
    
    /// Collect publisher values over time
    func collectPublisherValues<P: Publisher>(
        _ publisher: P,
        count: Int,
        timeout: TimeInterval = 2.0
    ) -> [P.Output] where P.Failure == Never {
        let expectation = expectation(description: "Collected \(count) values")
        var values: [P.Output] = []
        
        let cancellable = publisher
            .prefix(count)
            .sink(
                receiveCompletion: { _ in
                    expectation.fulfill()
                },
                receiveValue: { value in
                    values.append(value)
                }
            )
        
        wait(for: [expectation], timeout: timeout)
        _ = cancellable // Keep reference
        
        return values
    }
}

// MARK: - Mock Data Generators

struct TestDataGenerator {
    static func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    static func randomEmail() -> String {
        "\(randomString(length: 8))@test.com"
    }
    
    static func randomURL() -> URL {
        URL(string: "https://\(randomString(length: 8)).test.com")!
    }
    
    static func randomAPIKey() -> String {
        "sk-\(randomString(length: 32))"
    }
    
    static func makeProject(
        id: String = UUID().uuidString,
        name: String? = nil,
        description: String? = nil
    ) -> APIClient.Project {
        APIClient.Project(
            id: id,
            name: name ?? "Project \(randomString(length: 5))",
            description: description ?? "Description \(randomString(length: 10))",
            path: "/path/\(randomString(length: 8))",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    static func makeSession(
        id: String = UUID().uuidString,
        projectId: String = "test-project",
        model: String = "gpt-4"
    ) -> APIClient.Session {
        APIClient.Session(
            id: id,
            projectId: projectId,
            title: "Session \(randomString(length: 5))",
            model: model,
            systemPrompt: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            isActive: true,
            totalTokens: Int.random(in: 100...10000),
            totalCost: Double.random(in: 0.01...10.0),
            messageCount: Int.random(in: 1...100)
        )
    }
}

// MARK: - Performance Test Helpers

struct PerformanceTestHelper {
    static func measureTime(
        description: String = "Operation",
        block: () throws -> Void
    ) rethrows {
        let startTime = CFAbsoluteTimeGetCurrent()
        try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("⏱ \(description) took \(String(format: "%.3f", timeElapsed)) seconds")
    }
    
    static func measureAsyncTime(
        description: String = "Async Operation",
        block: () async throws -> Void
    ) async rethrows {
        let startTime = CFAbsoluteTimeGetCurrent()
        try await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("⏱ \(description) took \(String(format: "%.3f", timeElapsed)) seconds")
    }
}

// MARK: - Memory Test Helpers

struct MemoryTestHelper {
    static func checkForRetainCycle<T: AnyObject>(
        object: T,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        weak var weakRef = object
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakRef, "Object not deallocated - possible retain cycle", file: file, line: line)
        }
    }
    
    static func autoreleaseTest(block: () -> Void) {
        autoreleasepool {
            block()
        }
    }
}

// MARK: - Network Mock Helpers

class NetworkRequestRecorder {
    private(set) var requests: [URLRequest] = []
    private(set) var responses: [URLResponse] = []
    
    func record(request: URLRequest) {
        requests.append(request)
    }
    
    func record(response: URLResponse) {
        responses.append(response)
    }
    
    func reset() {
        requests.removeAll()
        responses.removeAll()
    }
    
    func requestCount(for path: String) -> Int {
        requests.filter { $0.url?.path == path }.count
    }
    
    func hasRequest(matching predicate: (URLRequest) -> Bool) -> Bool {
        requests.contains(where: predicate)
    }
}

// MARK: - Assertion Helpers

extension XCTestCase {
    func assertEventuallyTrue(
        timeout: TimeInterval = 2.0,
        message: String = "Condition not met",
        condition: @escaping () -> Bool
    ) {
        let expectation = expectation(description: message)
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }
    
    func assertNoThrow<T>(
        _ expression: @autoclosure () throws -> T,
        message: String = "Expression threw unexpectedly",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        do {
            _ = try expression()
        } catch {
            XCTFail("\(message): \(error)", file: file, line: line)
        }
    }
    
    func assertThrows<T>(
        _ expression: @autoclosure () throws -> T,
        message: String = "Expression did not throw",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        do {
            _ = try expression()
            XCTFail(message, file: file, line: line)
        } catch {
            // Expected
        }
    }
}

// MARK: - SwiftUI Preview Test Helpers

#if DEBUG
@MainActor
struct PreviewTestHelper {
    @MainActor
    static func makeTestContainer() -> Container {
        let container = Container.shared
        container.reset()
        
        // Inject mock services for previews
        container.injectMock(APIClientProtocol.self, mock: MockAPIClient())
        
        return container
    }
    
    @MainActor
    static func makeTestSettings() -> AppSettings {
        let settings = AppSettings()
        settings.apiKeyPlaintext = "test-api-key"
        settings.backendURL = "http://localhost:8000"
        return settings
    }
}
#endif

// MARK: - Test Fixture Loader

struct TestFixtures {
    static func loadJSON<T: Decodable>(
        _ type: T.Type,
        from filename: String,
        bundle: Bundle = Bundle(for: MemoryLeakTests.self)
    ) throws -> T {
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            throw TestError.invalidState
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
    
    static func loadData(
        from filename: String,
        withExtension ext: String,
        bundle: Bundle = Bundle(for: MemoryLeakTests.self)
    ) throws -> Data {
        guard let url = bundle.url(forResource: filename, withExtension: ext) else {
            throw TestError.invalidState
        }
        
        return try Data(contentsOf: url)
    }
}