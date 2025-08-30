import XCTest
@testable import ClaudeCode

@MainActor
final class APIClientTests: XCTestCase {
    
    var sut: APIClient!
    var mockSettings: AppSettings!
    var mockURLSession: URLSessionMock!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSettings = AppSettings.shared
        mockSettings.baseURL = "http://localhost:8000"
        mockSettings.apiKeyPlaintext = ""
        mockURLSession = URLSessionMock()
        sut = APIClient(settings: mockSettings, session: mockURLSession)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockSettings = nil
        mockURLSession = nil
        try await super.tearDown()
    }
    
    // MARK: - GET Tests
    
    func testGetJSONSuccess() async throws {
        struct TestResponse: Codable, Equatable {
            let message: String
            let value: Int
        }
        
        let expectedResponse = TestResponse(message: "Success", value: 42)
        
        mockURLSession.mockResponse = expectedResponse
        mockURLSession.statusCode = 200
        
        let result: TestResponse = try await sut.getJSON("/test", as: TestResponse.self)
        
        XCTAssertEqual(result, expectedResponse)
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "GET")
        XCTAssertTrue(mockURLSession.lastRequest?.url?.absoluteString.contains("/test") ?? false)
    }
    
    func testGetJSONWithHeaders() async throws {
        mockURLSession.mockResponse = APITestEmptyResponse()
        mockURLSession.statusCode = 200
        
        let customHeaders = ["X-Custom": "Value"]
        _ = try await sut.getJSON("/test", as: APITestEmptyResponse.self)
        
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "X-Custom"), "Value")
    }
    
    func testGetJSONAuthHeader() async throws {
        // Set API key
        AppSettings.shared.apiKeyPlaintext = "test-api-key"
        
        mockURLSession.mockResponse = APITestEmptyResponse()
        mockURLSession.statusCode = 200
        
        _ = try await sut.getJSON("/test", as: APITestEmptyResponse.self)
        
        XCTAssertEqual(
            mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-api-key"
        )
        
        // Clean up
        AppSettings.shared.apiKeyPlaintext = ""
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
        
        mockURLSession.mockResponse = expectedResponse
        mockURLSession.statusCode = 201
        
        let result: TestResponse = try await sut.postJSON("/create", body: request, as: TestResponse.self)
        
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
        mockURLSession.mockResponse = [:]
        mockURLSession.statusCode = 204
        
        try await sut.delete("/delete/123")
        
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "DELETE")
        XCTAssertTrue(mockURLSession.lastRequest?.url?.absoluteString.contains("/delete/123") ?? false)
    }
    
    // MARK: - Error Handling Tests
    
    func testHTTPErrorResponse() async {
        mockURLSession.statusCode = 404
        mockURLSession.shouldFail = true
        
        do {
            _ = try await sut.getJSON("/test", as: APITestEmptyResponse.self)
            XCTFail("Should have thrown error")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    func testNetworkError() async {
        mockURLSession.mockError = URLError(.notConnectedToInternet)
        
        do {
            _ = try await sut.getJSON("/test", as: APITestEmptyResponse.self)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
    
    func testInvalidJSONResponse() async {
        // Configure mock to return raw invalid JSON data
        mockURLSession.mockResponse = Data("Invalid JSON")
        mockURLSession.statusCode = 200
        
        do {
            _ = try await sut.getJSON("/test") as TestResponse
            XCTFail("Should have thrown decoding error")
        } catch {
            // Expected decoding error
            XCTAssertNotNil(error)
        }
    }
}

// Test response structs
struct APITestAPITestEmptyResponse: Codable {}

struct TestResponse: Codable, Equatable {
    let message: String
}