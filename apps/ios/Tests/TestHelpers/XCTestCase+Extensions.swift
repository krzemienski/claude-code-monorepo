import XCTest
import Combine

// MARK: - Test Helpers Extensions

extension XCTestCase {
    
    /// Waits for async publisher to complete and returns value
    func awaitPublisher<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T.Output {
        var result: Result<T.Output, Error>?
        let expectation = self.expectation(description: "Publisher completion")
        
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    result = .failure(error)
                    expectation.fulfill()
                }
            },
            receiveValue: { value in
                result = .success(value)
                expectation.fulfill()
            }
        )
        
        wait(for: [expectation], timeout: timeout)
        cancellable.cancel()
        
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            XCTFail("Publisher did not complete", file: file, line: line)
            throw TestError.timeout
        }
    }
    
    /// Waits for async function and returns result
    func awaitAsync<T>(
        timeout: TimeInterval = 10,
        _ operation: @escaping () async throws -> T
    ) throws -> T {
        let expectation = self.expectation(description: "Async operation")
        var result: Result<T, Error>?
        
        Task {
            do {
                let value = try await operation()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
        
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            throw TestError.timeout
        }
    }
    
    /// Assert that two values are eventually equal
    func assertEventually<T: Equatable>(
        _ expression: @autoclosure () throws -> T,
        equals expected: T,
        timeout: TimeInterval = 5,
        pollInterval: TimeInterval = 0.1,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            do {
                let value = try expression()
                if value == expected {
                    return
                }
            } catch {
                // Continue polling
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        
        XCTFail("Value did not equal expected within timeout", file: file, line: line)
    }
}

enum TestError: Error {
    case timeout
    case unexpectedNil
    case invalidState
}