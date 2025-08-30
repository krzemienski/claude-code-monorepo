import Foundation

// MARK: - API Error Extensions

extension APIClient.APIError {
    static var invalidURL: APIClient.APIError {
        APIClient.APIError(status: 0, body: "Invalid URL")
    }
    
    static func invalidResponse(_ description: String) -> APIClient.APIError {
        APIClient.APIError(status: 0, body: description)
    }
}

// Alternative: Create a proper error enum if needed
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse(String)
    case networkError(Error)
    case decodingError(Error)
    case unauthorized
    case serverError(Int, String?)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError(let code, let message):
            return "Server error \(code): \(message ?? "Unknown")"
        }
    }
}