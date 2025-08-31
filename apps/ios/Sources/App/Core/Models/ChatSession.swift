import Foundation

/// Session type for chat sessions
public enum SessionType: String, Codable, CaseIterable {
    case coding = "Coding"
    case documentation = "Documentation"
    case debugging = "Debugging"
    case review = "Review"
    case general = "General"
}

/// Chat session model
public struct ChatSession: Identifiable, Codable, Hashable {
    public let id: String
    public let projectId: String?
    public let title: String
    public let type: SessionType
    public let messages: [Message]
    public let createdAt: Date
    public let updatedAt: Date
    public let model: String
    public let totalTokens: Int
    public let estimatedCost: Double
    
    public init(
        id: String = UUID().uuidString,
        projectId: String? = nil,
        title: String,
        type: SessionType = .general,
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        model: String = "claude-3-5-haiku-20241022",
        totalTokens: Int = 0,
        estimatedCost: Double = 0.0
    ) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.type = type
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.model = model
        self.totalTokens = totalTokens
        self.estimatedCost = estimatedCost
    }
    
    /// Number of messages in session
    public var messageCount: Int {
        messages.count
    }
    
    /// Last message timestamp
    public var lastMessageAt: Date? {
        messages.last?.timestamp
    }
}

/// Sample sessions for previews
public extension ChatSession {
    static let sampleSessions: [ChatSession] = [
        ChatSession(
            title: "Implement Authentication",
            type: .coding,
            messages: [
                Message(id: "1", content: "Help me implement JWT authentication", timestamp: Date()),
                Message(id: "2", content: "I'll help you implement JWT authentication. Let's start with...", timestamp: Date())
            ],
            totalTokens: 1234,
            estimatedCost: 0.02
        ),
        ChatSession(
            title: "API Documentation",
            type: .documentation,
            messages: [
                Message(id: "3", content: "Generate OpenAPI docs for the endpoints", timestamp: Date()),
                Message(id: "4", content: "I'll generate OpenAPI documentation for your endpoints...", timestamp: Date())
            ],
            totalTokens: 2345,
            estimatedCost: 0.04
        )
    ]
}