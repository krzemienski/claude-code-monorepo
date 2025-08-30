import SwiftUI
import Combine
import Foundation
import os.log

// MARK: - Models
struct ChatMessage: Identifiable, Equatable {
    enum Role: String {
        case user, assistant, system
    }
    
    let id: String
    let role: Role
    var content: String
    let timestamp: Date
    var isStreaming: Bool = false
    
    init(id: String = UUID().uuidString, role: Role, content: String, timestamp: Date = Date(), isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
}

struct ToolExecution: Identifiable, Equatable {
    enum Status { case running, success, failure }
    
    let id: String
    var name: String
    var input: String
    var output: String = ""
    var state: Status
    var durationMs: Int?
    var exitCode: Int?
    let timestamp: Date = Date()
    
    init(id: String, name: String, input: String, output: String = "", state: Status, durationMs: Int? = nil, exitCode: Int? = nil) {
        self.id = id
        self.name = name
        self.input = input
        self.output = output
        self.state = state
        self.durationMs = durationMs
        self.exitCode = exitCode
    }
}

// MARK: - Chat View Model
@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var tools: [ToolExecution] = []  // Renamed from toolExecutions to match view
    @Published var inputText: String = ""
    @Published var isStreaming: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var error: Error?
    @Published var sessionInfo: SessionInfo?
    @Published var modelId: String = "claude-3-5-haiku-20241022"  // Renamed from modelSelection to match view
    @Published var streamingEnabled: Bool = true
    @Published var statusMessage: String = ""
    @Published var totalTokens: Int = 0  // Renamed from tokensUsed to match view
    @Published var totalCost: Double = 0.0  // Renamed from estimatedCost to match view
    
    // MARK: - Connection Status
    enum ConnectionStatus: String {
        case connected = "Connected"
        case connecting = "Connecting..."
        case disconnected = "Disconnected"
        case error = "Connection Error"
        
    }
    
    struct SessionInfo {
        let id: String
        let projectId: String
        let model: String
        var messageCount: Int
        var totalTokens: Int
        var totalCost: Double
    }
    
    // MARK: - Private Properties
    @Injected(APIClientProtocol.self) private var apiClient: APIClientProtocol
    @Injected(AppSettings.self) private var settings: AppSettings
    private var sseClient: SSEClient?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode", category: "ChatViewModel")
    private var currentStreamingMessage: ChatMessage?
    private let projectId: String
    var sessionId: String?  // Made public to match view access
    
    // MARK: - Combine Publishers
    private let messageSubject = PassthroughSubject<ChatMessage, Never>()
    private let toolExecutionSubject = PassthroughSubject<ToolExecution, Never>()
    private let connectionSubject = PassthroughSubject<ConnectionStatus, Never>()
    
    var messagePublisher: AnyPublisher<ChatMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    var toolExecutionPublisher: AnyPublisher<ToolExecution, Never> {
        toolExecutionSubject.eraseToAnyPublisher()
    }
    
    var connectionPublisher: AnyPublisher<ConnectionStatus, Never> {
        connectionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(sessionId: String? = nil, projectId: String, modelId: String = "claude-3-5-haiku-20241022") {
        // Dependencies are automatically injected via property wrappers
        self.sessionId = sessionId
        self.projectId = projectId
        self.modelId = modelId
        
        setupSubscriptions()
        
        if sessionId == nil {
            Task { await createNewSession() }
        } else {
            Task { await loadSessionInfo() }
        }
    }
    
    // MARK: - Setup Methods
    private func setupSSEHandlers() {
        guard let sseClient = sseClient else { return }
        
        sseClient.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handleSSEEvent(event.raw)
            }
        }
        
        sseClient.onDone = { [weak self] in
            Task { @MainActor in
                self?.handleStreamComplete()
            }
        }
        
        sseClient.onError = { [weak self] error in
            Task { @MainActor in
                self?.handleStreamError(error)
            }
        }
    }
    
    private func setupSubscriptions() {
        // Monitor connection status changes
        connectionSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.connectionStatus = status
            }
            .store(in: &cancellables)
        
        // Auto-scroll on new messages
        messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.logger.debug("New message: \(message.role.rawValue)")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func sendMessage(_ content: String) async {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        messageSubject.send(userMessage)
        
        // Clear any previous error
        error = nil
        
        // Send to backend
        if streamingEnabled {
            await sendStreamingMessage(text)
        } else {
            await sendNonStreamingMessage(text)
        }
    }
    
    func stopStreaming() async {
        guard isStreaming else { return }
        
        sseClient?.stop()
        isStreaming = false
        connectionStatus = .connected
        
        // Finalize any partial message
        if let message = currentStreamingMessage {
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = message
                messages[index].isStreaming = false
            }
            currentStreamingMessage = nil
        }
        
        logger.info("Stopped streaming")
    }
    
    func clearError() async {
        error = nil
    }
    
    func monitorConnection() async {
        while !Task.isCancelled {
            await checkConnectionStatus()
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }
    }
    
    func retryLastMessage() async {
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else { return }
        
        // Remove any incomplete assistant messages
        messages.removeAll { $0.role == .assistant && $0.isStreaming }
        
        // Resend the last user message
        if streamingEnabled {
            await sendStreamingMessage(lastUserMessage.content)
        } else {
            await sendNonStreamingMessage(lastUserMessage.content)
        }
    }
    
    // MARK: - Private Methods - Messaging
    private func sendStreamingMessage(_ text: String) async {
        isStreaming = true
        connectionStatus = .connecting
        
        // Create placeholder assistant message
        let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        currentStreamingMessage = assistantMessage
        
        let body: [String: Any] = [
            "model": modelId,
            "project_id": projectId,
            "session_id": sessionId as Any,
            "messages": [["role": "user", "content": text]],
            "stream": true
        ].compactMapValues { $0 }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: body)
            let baseURL = settings.baseURL
            guard let url = URL(string: "\(baseURL)/api/v1/chat/completions") else {
                throw URLError(.badURL)
            }
            
            var headers: [String: String] = ["Content-Type": "application/json"]
            if !settings.apiKeyPlaintext.isEmpty {
                headers["Authorization"] = "Bearer \(settings.apiKeyPlaintext)"
            }
            
            // Create SSE client
            sseClient = SSEClient(url: url.absoluteString, headers: headers, body: data)
            setupSSEHandlers()
            sseClient?.connect()
            connectionStatus = .connected
            
        } catch {
            handleError(error)
            isStreaming = false
        }
    }
    
    private func sendNonStreamingMessage(_ text: String) async {
        isStreaming = true
        connectionStatus = .connecting
        
        do {
            let body: [String: Any] = [
                "model": modelId,
                "project_id": projectId,
                "session_id": sessionId as Any,
                "messages": [["role": "user", "content": text]],
                "stream": false
            ].compactMapValues { $0 }
            
            let data = try JSONSerialization.data(withJSONObject: body)
            let baseURL = settings.baseURL
            guard let completionsURL = URL(string: "\(baseURL)/api/v1/chat/completions") else {
                throw URLError(.badURL)
            }
            var request = URLRequest(url: completionsURL)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if !settings.apiKeyPlaintext.isEmpty {
                request.setValue("Bearer \(settings.apiKeyPlaintext)", forHTTPHeaderField: "Authorization")
            }
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw APIClient.APIError(status: (response as? HTTPURLResponse)?.statusCode ?? -1, body: String(data: responseData, encoding: .utf8))
            }
            
            if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                if let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                
                let assistantMessage = ChatMessage(role: .assistant, content: content)
                messages.append(assistantMessage)
                messageSubject.send(assistantMessage)
                
                // Update session ID if provided
                if sessionId == nil, let newSessionId = json["session_id"] as? String {
                    sessionId = newSessionId
                    await loadSessionInfo()
                }
                
                }
                
                // Update token usage  
                if let usage = json["usage"] as? [String: Any] {
                    totalTokens = (usage["total_tokens"] as? Int) ?? 0
                    totalCost = (usage["total_cost"] as? Double) ?? 0.0
                }
            }
            
            connectionStatus = .connected
            await updateSessionStatus()
            
        } catch {
            handleError(error)
        }
        
        isStreaming = false
    }
    
    // MARK: - SSE Event Handling
    private func handleSSEEvent(_ jsonLine: String) {
        guard let data = jsonLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        let eventType = (json["object"] as? String) ?? (json["type"] as? String) ?? ""
        
        switch eventType {
        case "chat.completion.chunk":
            handleChatChunk(json)
            
        case "tool_use":
            handleToolUse(json)
            
        case "tool_result":
            handleToolResult(json)
            
        case "usage":
            handleUsageUpdate(json)
            
        default:
            logger.debug("Unhandled SSE event type: \(eventType)")
        }
    }
    
    private func handleChatChunk(_ json: [String: Any]) {
        guard let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String,
              !content.isEmpty else { return }
        
        if var message = currentStreamingMessage {
            message.content += content
            currentStreamingMessage = message
            
            // Update message in array
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = message
                messageSubject.send(messages[index])
            }
        }
        
        // Update session ID if provided
        if sessionId == nil, let newSessionId = json["session_id"] as? String {
            sessionId = newSessionId
            Task { await loadSessionInfo() }
        }
    }
    
    private func handleToolUse(_ json: [String: Any]) {
        let toolId = (json["id"] as? String) ?? UUID().uuidString
        let name = (json["name"] as? String) ?? "Unknown Tool"
        let input = (json["input"] as? [String: Any]).flatMap { dict in
            (try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]))
                .flatMap { String(data: $0, encoding: .utf8) }
        } ?? "{}"
        
        let execution = ToolExecution(
            id: toolId,
            name: name,
            input: input,
            state: .running
        )
        
        tools.insert(execution, at: 0)
        toolExecutionSubject.send(execution)
    }
    
    private func handleToolResult(_ json: [String: Any]) {
        let toolId = (json["tool_id"] as? String) ?? ""
        let name = (json["name"] as? String) ?? "Unknown Tool"
        let isError = (json["is_error"] as? Bool) ?? false
        let output = (json["content"] as? String) ?? ""
        let durationMs = json["duration_ms"] as? Int
        let exitCode = json["exit_code"] as? Int
        
        if let index = tools.firstIndex(where: { $0.id == toolId }) {
            tools[index].state = isError ? .failure : .success
            tools[index].name = name
            tools[index].output = output
            tools[index].durationMs = durationMs
            tools[index].exitCode = exitCode
            toolExecutionSubject.send(tools[index])
        } else {
            let execution = ToolExecution(
                id: toolId,
                name: name,
                input: "{}",
                output: output,
                state: isError ? .failure : .success,
                durationMs: durationMs,
                exitCode: exitCode
            )
            tools.insert(execution, at: 0)
            toolExecutionSubject.send(execution)
        }
    }
    
    private func handleUsageUpdate(_ json: [String: Any]) {
        let inputTokens = (json["input_tokens"] as? Int) ?? 0
        let outputTokens = (json["output_tokens"] as? Int) ?? 0
        let cost = (json["total_cost"] as? Double) ?? 0.0
        
        totalTokens = inputTokens + outputTokens
        totalCost = cost
        statusMessage = "Tokens: \(totalTokens) • Cost: $\(String(format: "%.4f", cost))"
    }
    
    private func handleStreamComplete() {
        isStreaming = false
        connectionStatus = .connected
        
        // Mark streaming as complete
        if let message = currentStreamingMessage {
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].isStreaming = false
            }
        }
        currentStreamingMessage = nil
        
        Task { await updateSessionStatus() }
    }
    
    private func handleStreamError(_ error: Error) {
        handleError(error)
        isStreaming = false
        currentStreamingMessage = nil
    }
    
    // MARK: - Session Management
    private func createNewSession() async {
        connectionStatus = .connecting
        
        // For now, just generate a session ID
        // Later this will call the actual API
        self.sessionId = UUID().uuidString
        connectionStatus = .connected
        logger.info("Created new session: \(self.sessionId ?? "")")
    }
    
    private func checkConnectionStatus() async {
        guard sessionId != nil else {
            connectionStatus = .disconnected
            return
        }
        
        // For now, just set to connected
        // Later this will actually check the API
        if connectionStatus != .connected && !isStreaming {
            connectionStatus = .connected
        }
    }
    
    private func loadSessionInfo() async {
        guard let sessionId = sessionId else { return }
        
        // For now, just create a basic session info
        // Later this will call the actual API
        sessionInfo = SessionInfo(
            id: sessionId,
            projectId: projectId,
            model: modelId,
            messageCount: messages.count,
            totalTokens: totalTokens,
            totalCost: totalCost
        )
        logger.info("Loaded session info for: \(sessionId)")
    }
    
    private func updateSessionStatus() async {
        guard sessionId != nil else { return }
        
        // Update session info with current stats
        if var info = sessionInfo {
            info.totalTokens = totalTokens
            info.totalCost = totalCost
            info.messageCount = messages.count
            sessionInfo = info
        }
        
        statusMessage = "Tokens: \(totalTokens) • Cost: $\(String(format: "%.4f", totalCost))"
        logger.debug("Updated session status: \(self.statusMessage)")
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        self.error = error
        connectionStatus = .error
        logger.error("Chat error: \(error)")
        
        // Auto-dismiss error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.error?.localizedDescription == error.localizedDescription {
                self?.error = nil
                self?.connectionStatus = .disconnected
            }
        }
    }
}