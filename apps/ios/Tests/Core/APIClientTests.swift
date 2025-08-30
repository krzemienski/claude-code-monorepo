import XCTest
@testable import ClaudeCode

@MainActor
final class APIClientTests: XCTestCase {
    
    var sut: APIClient!
    var mockSettings: AppSettings!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSettings = AppSettings.shared
        mockSettings.baseURL = "http://localhost:8000"
        mockSettings.apiKey = nil
        sut = APIClient(settings: mockSettings)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockSettings = nil
        try await super.tearDown()
    }
    
    // MARK: - GET Tests
    
    func testGetJSONSuccess() async throws {
        struct TestResponse: Codable, Equatable {
            let message: String
            let value: Int
        }
        
        let expectedResponse = TestResponse(message: "Success", value: 42)
        let responseData = try JSONEncoder().encode(expectedResponse)
        
        mockURLSession.mockData = responseData
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let result: TestResponse = try await sut.getJSON("/test")
        
        XCTAssertEqual(result, expectedResponse)
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "GET")
        XCTAssertTrue(mockURLSession.lastRequest?.url?.absoluteString.contains("/test") ?? false)
    }
    
    func testGetJSONWithHeaders() async throws {
        struct EmptyResponse: Codable {}
        
        mockURLSession.mockData = Data("{}")
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let customHeaders = ["X-Custom": "Value"]
        _ = try await sut.getJSON("/test", headers: customHeaders) as EmptyResponse
        
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "X-Custom"), "Value")
    }
    
    func testGetJSONAuthHeader() async throws {
        struct EmptyResponse: Codable {}
        
        // Set API key
        AppSettings.shared.apiKey = "test-api-key"
        
        mockURLSession.mockData = Data("{}")
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        _ = try await sut.getJSON("/test") as EmptyResponse
        
        XCTAssertEqual(
            mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-api-key"
        )
        
        // Clean up
        AppSettings.shared.apiKey = nil
    }
    
    // MARK: - POST Tests
    
    func testPostJSONSuccess() async throws {
        struct TestRequest: Codable, Equatable {
            let name: String
            let age: Int
        }
        
        struct TestResponse: Codable, Equatable {
            let id: String
            let created: Bool
        }
        
        let request = TestRequest(name: "Test", age: 30)
        let expectedResponse = TestResponse(id: "123", created: true)
        let responseData = try JSONEncoder().encode(expectedResponse)
        
        mockURLSession.mockData = responseData
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/create")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        
        let result: TestResponse = try await sut.postJSON("/create", body: request)
        
        XCTAssertEqual(result, expectedResponse)
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "POST")
        
        // Verify request body
        if let bodyData = mockURLSession.lastRequest?.httpBody {
            let decodedRequest = try JSONDecoder().decode(TestRequest.self, from: bodyData)
            XCTAssertEqual(decodedRequest, request)
        } else {
            XCTFail("Request body not found")
        }
    }
    
    // MARK: - DELETE Tests
    
    func testDeleteJSONSuccess() async throws {
        mockURLSession.mockData = Data()
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/delete/123")!,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        )
        
        try await sut.deleteJSON("/delete/123")
        
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "DELETE")
        XCTAssertTrue(mockURLSession.lastRequest?.url?.absoluteString.contains("/delete/123") ?? false)
    }
    
    // MARK: - Error Handling Tests
    
    func testHTTPErrorResponse() async {
        mockURLSession.mockData = Data()
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/test")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await sut.getJSON("/test") as EmptyResponse
            XCTFail("Should have thrown error")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    func testNetworkError() async {
        mockURLSession.mockError = URLError(.notConnectedToInternet)
        
        do {
            _ = try await sut.getJSON("/test") as EmptyResponse
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
    
    func testInvalidJSONResponse() async {
        mockURLSession.mockData = Data("Invalid JSON")
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await sut.getJSON("/test") as TestResponse
            XCTFail("Should have thrown decoding error")
        } catch {
            // Expected decoding error
            XCTAssertNotNil(error)
        }
    }
}

// MARK: - Mock URLSession

class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var lastRequest: URLRequest?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        
        if let error = mockError {
            throw error
        }
        
        let data = mockData ?? Data()
        let response = mockResponse ?? URLResponse()
        
        return (data, response)
    }
}

// Empty response for tests
struct EmptyResponse: Codable {}

// Test response struct
struct TestResponse: Codable, Equatable {
    let message: String
}