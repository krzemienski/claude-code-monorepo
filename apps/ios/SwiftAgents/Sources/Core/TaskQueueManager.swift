import Foundation
import AsyncAlgorithms

/// Actor-based task queue manager for agent coordination
public actor TaskQueueManager: TaskQueue {
    private var tasks: [AgentTask] = []
    private let maxQueueSize: Int
    private let persistencePath: URL?
    
    public init(maxQueueSize: Int = 1000, persistencePath: URL? = nil) {
        self.maxQueueSize = maxQueueSize
        self.persistencePath = persistencePath
        
        // Load persisted tasks if available
        if let path = persistencePath {
            Task {
                await loadPersistedTasks(from: path)
            }
        }
    }
    
    // MARK: - TaskQueue Protocol
    
    public func enqueue(_ task: AgentTask) async throws {
        guard tasks.count < maxQueueSize else {
            throw TaskQueueError.queueFull
        }
        
        tasks.append(task)
        tasks.sort { $0.priority > $1.priority || 
                    ($0.priority == $1.priority && $0.createdAt < $1.createdAt) }
        
        // Persist if needed
        if let path = persistencePath {
            try await persistTasks(to: path)
        }
    }
    
    public func dequeue() async throws -> AgentTask? {
        guard !tasks.isEmpty else { return nil }
        
        let task = tasks.removeFirst()
        
        // Persist if needed
        if let path = persistencePath {
            try await persistTasks(to: path)
        }
        
        return task
    }
    
    public func peek() async -> AgentTask? {
        return tasks.first
    }
    
    public func count() async -> Int {
        return tasks.count
    }
    
    public func clear() async throws {
        tasks.removeAll()
        
        // Clear persistence
        if let path = persistencePath {
            try FileManager.default.removeItem(at: path)
        }
    }
    
    public func prioritize(_ taskId: UUID, priority: TaskPriority) async throws {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            throw TaskQueueError.taskNotFound
        }
        
        tasks[index].priority = priority
        tasks.sort { $0.priority > $1.priority || 
                    ($0.priority == $1.priority && $0.createdAt < $1.createdAt) }
        
        // Persist if needed
        if let path = persistencePath {
            try await persistTasks(to: path)
        }
    }
    
    // MARK: - Additional Methods
    
    public func updateTaskStatus(_ taskId: UUID, status: TaskStatus) async throws {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            throw TaskQueueError.taskNotFound
        }
        
        tasks[index].status = status
        
        // Persist if needed
        if let path = persistencePath {
            try await persistTasks(to: path)
        }
    }
    
    public func assignTask(_ taskId: UUID, to agent: String) async throws {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            throw TaskQueueError.taskNotFound
        }
        
        tasks[index].assignedAgent = agent
        tasks[index].status = .assigned
        
        // Persist if needed
        if let path = persistencePath {
            try await persistTasks(to: path)
        }
    }
    
    public func getTasksByStatus(_ status: TaskStatus) async -> [AgentTask] {
        return tasks.filter { $0.status == status }
    }
    
    public func getTasksByAgent(_ agent: String) async -> [AgentTask] {
        return tasks.filter { $0.assignedAgent == agent }
    }
    
    // MARK: - Persistence
    
    private func persistTasks(to path: URL) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(tasks)
        try data.write(to: path)
    }
    
    private func loadPersistedTasks(from path: URL) async {
        guard FileManager.default.fileExists(atPath: path.path) else { return }
        
        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            tasks = try decoder.decode([AgentTask].self, from: data)
        } catch {
            print("Failed to load persisted tasks: \(error)")
        }
    }
}

// MARK: - Task Queue Errors

public enum TaskQueueError: LocalizedError {
    case queueFull
    case taskNotFound
    case invalidTaskState
    
    public var errorDescription: String? {
        switch self {
        case .queueFull:
            return "Task queue has reached maximum capacity"
        case .taskNotFound:
            return "Task not found in queue"
        case .invalidTaskState:
            return "Task is in an invalid state for this operation"
        }
    }
}

// MARK: - Task Distributor

/// Distributes tasks among available agents
public actor TaskDistributor {
    private let taskQueue: TaskQueueManager
    private var availableAgents: [String: AgentCapabilities] = [:]
    private var agentWorkload: [String: Int] = [:]
    
    public init(taskQueue: TaskQueueManager) {
        self.taskQueue = taskQueue
    }
    
    public func registerAgent(_ agentId: String, capabilities: AgentCapabilities) {
        availableAgents[agentId] = capabilities
        agentWorkload[agentId] = 0
    }
    
    public func unregisterAgent(_ agentId: String) {
        availableAgents.removeValue(forKey: agentId)
        agentWorkload.removeValue(forKey: agentId)
    }
    
    public func distributeTask() async throws -> (task: AgentTask, agent: String)? {
        guard let task = await taskQueue.dequeue() else { return nil }
        
        // Find suitable agent with lowest workload
        let suitableAgents = availableAgents.filter { agent in
            agent.value.canHandle(task.type)
        }
        
        guard !suitableAgents.isEmpty else {
            // Re-enqueue task if no suitable agent
            try await taskQueue.enqueue(task)
            return nil
        }
        
        // Select agent with lowest workload
        let selectedAgent = suitableAgents.min { first, second in
            (agentWorkload[first.key] ?? 0) < (agentWorkload[second.key] ?? 0)
        }?.key ?? suitableAgents.first!.key
        
        // Update workload
        agentWorkload[selectedAgent, default: 0] += 1
        
        // Assign task
        try await taskQueue.assignTask(task.id, to: selectedAgent)
        
        return (task, selectedAgent)
    }
    
    public func completeTask(_ taskId: UUID, by agent: String) {
        agentWorkload[agent, default: 1] -= 1
    }
}

// MARK: - Agent Capabilities

public struct AgentCapabilities {
    public let supportedTaskTypes: Set<TaskType>
    public let maxConcurrentTasks: Int
    public let specializations: [String]
    
    public init(supportedTaskTypes: Set<TaskType>, maxConcurrentTasks: Int = 5, specializations: [String] = []) {
        self.supportedTaskTypes = supportedTaskTypes
        self.maxConcurrentTasks = maxConcurrentTasks
        self.specializations = specializations
    }
    
    public func canHandle(_ taskType: TaskType) -> Bool {
        return supportedTaskTypes.contains(taskType)
    }
}