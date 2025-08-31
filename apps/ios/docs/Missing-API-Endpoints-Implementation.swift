// Missing API Endpoints Implementation Guide
// These endpoints need to be added to APIClient.swift

import Foundation
import Combine

// MARK: - 1. WebSocket Streaming Support

extension APIClient {
    
    // WebSocket connection for real-time chat streaming
    func connectWebSocket(sessionId: String) -> AsyncThrowingStream<StreamMessage, Error> {
        AsyncThrowingStream { continuation in
            let wsURL = baseURL
                .appendingPathComponent("v1/chat/stream")
                .absoluteString
                .replacingOccurrences(of: "http", with: "ws")
            
            // Implementation needed:
            // 1. Create URLSessionWebSocketTask
            // 2. Connect with authentication
            // 3. Stream messages via continuation
            // 4. Handle reconnection logic
            
            continuation.onTermination = { _ in
                // Cleanup WebSocket connection
            }
        }
    }
    
    struct StreamMessage: Decodable {
        let id: String
        let sessionId: String
        let type: MessageType
        let content: String
        let timestamp: String
        
        enum MessageType: String, Decodable {
            case assistant
            case user
            case system
            case tool
        }
    }
}

// MARK: - 2. Session Fork Endpoint

extension APIClient {
    
    struct ForkSessionRequest: Encodable {
        let parent_id: String
        let title: String?
        let copy_messages: Bool
    }
    
    struct ForkSessionResponse: Decodable {
        let id: String
        let parent_id: String
        let project_id: String
        let title: String?
        let created_at: String
        let message_count: Int
    }
    
    func forkSession(sessionId: String, title: String? = nil, copyMessages: Bool = true) async throws -> ForkSessionResponse {
        let body = ForkSessionRequest(
            parent_id: sessionId,
            title: title,
            copy_messages: copyMessages
        )
        return try await postJSON("/v1/sessions/\(sessionId)/fork", body: body, as: ForkSessionResponse.self)
    }
}

// MARK: - 3. Detailed Analytics Endpoint

extension APIClient {
    
    struct DetailedAnalyticsRequest {
        let from: Date
        let to: Date
        let metrics: [AnalyticsMetric]
        let groupBy: GroupingPeriod?
        
        enum AnalyticsMetric: String {
            case tokens
            case messages
            case sessions
            case costs
            case errors
            case latency
        }
        
        enum GroupingPeriod: String {
            case hour
            case day
            case week
            case month
        }
        
        var queryString: String {
            var params: [String] = []
            params.append("from=\(ISO8601DateFormatter().string(from: from))")
            params.append("to=\(ISO8601DateFormatter().string(from: to))")
            params.append("metrics=\(metrics.map { $0.rawValue }.joined(separator: ","))")
            if let groupBy = groupBy {
                params.append("group_by=\(groupBy.rawValue)")
            }
            return params.joined(separator: "&")
        }
    }
    
    struct DetailedAnalyticsResponse: Decodable {
        let period: Period
        let metrics: Metrics
        let timeline: [TimelinePoint]?
        
        struct Period: Decodable {
            let from: String
            let to: String
        }
        
        struct Metrics: Decodable {
            let total_tokens: Int
            let total_messages: Int
            let total_sessions: Int
            let total_cost: Double
            let error_rate: Double?
            let avg_latency_ms: Double?
        }
        
        struct TimelinePoint: Decodable {
            let timestamp: String
            let tokens: Int
            let messages: Int
            let sessions: Int
            let cost: Double
        }
    }
    
    func getDetailedAnalytics(request: DetailedAnalyticsRequest) async throws -> DetailedAnalyticsResponse {
        let path = "/v1/analytics/detailed?\(request.queryString)"
        return try await getJSON(path, as: DetailedAnalyticsResponse.self)
    }
}

// MARK: - 4. Export Endpoint

extension APIClient {
    
    struct ExportRequest: Encodable {
        let format: ExportFormat
        let session_ids: [String]?
        let project_ids: [String]?
        let include_metadata: Bool
        let include_analytics: Bool
        
        enum ExportFormat: String, Encodable {
            case json
            case csv
            case markdown
            case pdf
            case zip
        }
    }
    
    struct ExportResponse: Decodable {
        let export_id: String
        let export_url: String
        let expires_at: String
        let size_bytes: Int
        let format: String
        let status: ExportStatus
        
        enum ExportStatus: String, Decodable {
            case pending
            case processing
            case completed
            case failed
        }
    }
    
    func exportData(format: ExportRequest.ExportFormat, 
                    sessionIds: [String]? = nil,
                    projectIds: [String]? = nil,
                    includeMetadata: Bool = true,
                    includeAnalytics: Bool = false) async throws -> ExportResponse {
        let body = ExportRequest(
            format: format,
            session_ids: sessionIds,
            project_ids: projectIds,
            include_metadata: includeMetadata,
            include_analytics: includeAnalytics
        )
        return try await postJSON("/v1/export", body: body, as: ExportResponse.self)
    }
    
    // Check export status
    func getExportStatus(exportId: String) async throws -> ExportResponse {
        return try await getJSON("/v1/export/\(exportId)", as: ExportResponse.self)
    }
}

// MARK: - Usage Examples

/*
// 1. WebSocket Streaming
Task {
    for try await message in apiClient.connectWebSocket(sessionId: "session-123") {
        print("Received: \(message.content)")
    }
}

// 2. Fork Session
let forkedSession = try await apiClient.forkSession(
    sessionId: "original-session",
    title: "Experiment Branch",
    copyMessages: true
)

// 3. Detailed Analytics
let analyticsRequest = APIClient.DetailedAnalyticsRequest(
    from: Date().addingTimeInterval(-7*24*60*60), // 7 days ago
    to: Date(),
    metrics: [.tokens, .messages, .costs],
    groupBy: .day
)
let analytics = try await apiClient.getDetailedAnalytics(request: analyticsRequest)

// 4. Export Data
let exportResult = try await apiClient.exportData(
    format: .json,
    sessionIds: ["session-1", "session-2"],
    includeMetadata: true
)
print("Download from: \(exportResult.export_url)")
*/