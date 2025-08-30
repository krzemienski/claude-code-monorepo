import Foundation
@testable import ClaudeCode

// MARK: - URL Session Mock
final class URLSessionMock: NetworkServiceProtocol {
    // Response configuration
    var mockResponse: Any?
    var mockError: Error?
    var statusCode: Int = 200
    var headers: [String: String] = [:]
    var delay: TimeInterval = 0
    
    // Multiple responses for testing retries
    var responses: [Result<Any, Error>] = []
    private var responseIndex = 0
    
    // Request tracking
    private(set) var requestCount = 0
    private(set) var lastRequest: URLRequest?
    private(set) var capturedRequests: [URLRequest] = []
    
    // Control flags
    var shouldFail = false
    
    // MARK: - NetworkServiceProtocol Implementation
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Track request
        requestCount += 1
        lastRequest = request
        capturedRequests.append(request)
        
        // Simulate delay
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        // Check for multiple responses (for retry testing)
        if !responses.isEmpty && responseIndex < responses.count {
            let response = responses[responseIndex]
            responseIndex += 1
            
            switch response {
            case .success(let data):
                return try createResponse(for: request, with: data)
            case .failure(let error):
                throw error
            }
        }
        
        // Check for explicit failure
        if shouldFail {
            if let error = mockError {
                throw error
            }
            throw URLError(.badServerResponse)
        }
        
        // Return mock response
        if let mockResponse = mockResponse {
            return try createResponse(for: request, with: mockResponse)
        }
        
        // Default empty response
        return try createResponse(for: request, with: [:])
    }
    
    func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse) {
        let (data, response) = try await data(for: request)
        return (data, response as URLResponse)
    }
    
    func upload(for request: URLRequest, from data: Data) async throws -> (Data, URLResponse) {
        // Track upload data
        var modifiedRequest = request
        modifiedRequest.httpBody = data
        return try await self.data(for: modifiedRequest, delegate: nil)
    }
    
    // MARK: - Helper Methods
    private func createResponse(for request: URLRequest, with responseData: Any) throws -> (Data, HTTPURLResponse) {
        let data: Data
        
        if let responseData = responseData as? Data {
            data = responseData
        } else {
            data = try JSONSerialization.data(withJSONObject: responseData, options: [])
        }
        
        guard let url = request.url else {
            throw URLError(.badURL)
        }
        
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        
        return (data, response)
    }
    
    // MARK: - Test Helpers
    func reset() {
        mockResponse = nil
        mockError = nil
        statusCode = 200
        headers = [:]
        delay = 0
        responses = []
        responseIndex = 0
        requestCount = 0
        lastRequest = nil
        capturedRequests = []
        shouldFail = false
    }
    
    func verifyRequest(
        method: String? = nil,
        path: String? = nil,
        headers: [String: String]? = nil,
        body: Data? = nil
    ) -> Bool {
        guard let request = lastRequest else { return false }
        
        if let method = method, request.httpMethod != method {
            return false
        }
        
        if let path = path, request.url?.path != path {
            return false
        }
        
        if let headers = headers {
            for (key, value) in headers {
                if request.value(forHTTPHeaderField: key) != value {
                    return false
                }
            }
        }
        
        if let body = body, request.httpBody != body {
            return false
        }
        
        return true
    }
}

// MARK: - Preset Responses
extension URLSessionMock {
    func configureForSuccess<T: Encodable>(with response: T) {
        mockResponse = response
        statusCode = 200
        shouldFail = false
    }
    
    func configureForError(statusCode: Int, message: String? = nil) {
        self.statusCode = statusCode
        shouldFail = true
        
        if let message = message {
            mockResponse = ["error": message]
        }
    }
    
    func configureForNetworkError(_ error: URLError.Code) {
        shouldFail = true
        mockError = URLError(error)
    }
    
    func configureForRateLimit(retryAfter: Int = 60) {
        statusCode = 429
        headers = ["Retry-After": String(retryAfter)]
        shouldFail = true
        mockResponse = ["error": "Rate limited"]
    }
    
    func configureForTimeout() {
        shouldFail = true
        mockError = URLError(.timedOut)
        delay = 5.0
    }
}