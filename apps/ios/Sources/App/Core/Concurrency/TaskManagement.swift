import Foundation
import Combine
import OSLog

// MARK: - Advanced Task Management with Cancellation Tokens

/// Cancellation token for managing task lifecycle
class CancellationToken {
    private let cancellationSubject = PassthroughSubject<Void, Never>()
    private var isCancelledValue = false
    private let lock = NSLock()
    
    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledValue
    }
    
    var cancellationPublisher: AnyPublisher<Void, Never> {
        cancellationSubject.eraseToAnyPublisher()
    }
    
    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isCancelledValue else { return }
        isCancelledValue = true
        cancellationSubject.send()
        cancellationSubject.send(completion: .finished)
    }
    
    func register(onCancel: @escaping () -> Void) {
        var cancellable: AnyCancellable?
        cancellable = cancellationPublisher
            .sink { _ in
                onCancel()
                cancellable?.cancel()
            }
    }
}

/// Linked cancellation tokens for hierarchical cancellation
final class LinkedCancellationToken: CancellationToken {
    private var linkedTokens: [CancellationToken] = []
    private let linkLock = NSLock()
    
    func link(to token: CancellationToken) {
        linkLock.lock()
        defer { linkLock.unlock() }
        
        linkedTokens.append(token)
        
        // If this token is already cancelled, cancel the linked token
        if isCancelled {
            token.cancel()
        }
    }
    
    override func cancel() {
        super.cancel()
        
        linkLock.lock()
        let tokens = linkedTokens
        linkLock.unlock()
        
        // Cancel all linked tokens
        tokens.forEach { $0.cancel() }
    }
}

// MARK: - Task Manager with Priority and Grouping

actor TaskManager {
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "TaskManager")
    
    // Task storage
    private var tasks: [UUID: ManagedTask] = [:]
    private var taskGroups: [String: Set<UUID>] = [:]
    private var priorityQueues: [AppTaskPriority: [UUID]] = [:]
    
    // Concurrency control
    private let maxConcurrentTasks: Int
    private var runningTasks: Set<UUID> = []
    private var pendingTasks: [UUID] = []
    
    // Metrics
    private var metrics = TaskMetrics()
    
    init(maxConcurrentTasks: Int = 5) {
        self.maxConcurrentTasks = maxConcurrentTasks
        
        // Initialize priority queues
        for priority in AppTaskPriority.allCases {
            priorityQueues[priority] = []
        }
    }
    
    // MARK: - Task Submission
    
    @discardableResult
    func submit<T>(
        priority: AppTaskPriority = .medium,
        group: String? = nil,
        operation: @escaping () async throws -> T
    ) async throws -> TaskHandle<T> {
        let taskId = UUID()
        let cancellationToken = LinkedCancellationToken()
        
        // Create task handle
        let handle = TaskHandle<T>(
            id: taskId,
            cancellationToken: cancellationToken,
            manager: self
        )
        
        // Create properly typed task for the handle
        let typedTask = Task<T, Error>(priority: priority.toSwiftPriority()) { [weak self] in
            guard let self = self else {
                throw TaskError.managerDeallocated
            }
            
            // Check cancellation
            if cancellationToken.isCancelled {
                throw TaskError.cancelled
            }
            
            // Mark as running
            await self.taskStarted(taskId)
            
            do {
                // Execute operation
                let result = try await operation()
                
                // Mark as completed
                await self.taskCompleted(taskId)
                
                return result
            } catch {
                // Mark as failed
                await self.taskFailed(taskId, error: error)
                throw error
            }
        }
        
        // Create type-erased task for storage
        let erasedTask = Task<Any, Error>(priority: priority.toSwiftPriority()) { 
            try await typedTask.value as Any
        }
        
        // Store task
        let managedTask = ManagedTask(
            id: taskId,
            priority: priority,
            group: group,
            task: erasedTask,
            cancellationToken: cancellationToken,
            createdAt: Date()
        )
        
        tasks[taskId] = managedTask
        
        // Add to group if specified
        if let group = group {
            var groupTasks = taskGroups[group] ?? []
            groupTasks.insert(taskId)
            taskGroups[group] = groupTasks
        }
        
        // Add to priority queue
        priorityQueues[priority]?.append(taskId)
        
        // Try to schedule task
        await scheduleNextTask()
        
        // Set up result on handle with properly typed task
        handle.setTask(typedTask)
        
        logger.info("📋 Submitted task \(taskId) with priority \(priority.rawValue)")
        
        return handle
    }
    
    // MARK: - Task Lifecycle
    
    private func taskStarted(_ taskId: UUID) {
        runningTasks.insert(taskId)
        metrics.taskStarted()
        logger.debug("▶️ Task \(taskId) started")
    }
    
    private func taskCompleted(_ taskId: UUID) {
        runningTasks.remove(taskId)
        tasks[taskId] = nil
        removeFromQueues(taskId)
        metrics.taskCompleted()
        logger.debug("✅ Task \(taskId) completed")
        
        Task {
            await scheduleNextTask()
        }
    }
    
    private func taskFailed(_ taskId: UUID, error: Error) {
        runningTasks.remove(taskId)
        tasks[taskId] = nil
        removeFromQueues(taskId)
        metrics.taskFailed()
        logger.error("❌ Task \(taskId) failed: \(error)")
        
        Task {
            await scheduleNextTask()
        }
    }
    
    // MARK: - Scheduling
    
    private func scheduleNextTask() async {
        guard runningTasks.count < maxConcurrentTasks else { return }
        
        // Find next task by priority
        var nextTaskId: UUID?
        
        for priority in AppTaskPriority.allCases.reversed() {
            if let queue = priorityQueues[priority], !queue.isEmpty {
                nextTaskId = queue.first
                priorityQueues[priority]?.removeFirst()
                break
            }
        }
        
        guard let taskId = nextTaskId,
              let managedTask = tasks[taskId] else { return }
        
        // Start task if not cancelled
        if !managedTask.cancellationToken.isCancelled {
            logger.debug("🚀 Scheduling task \(taskId)")
        }
    }
    
    // MARK: - Cancellation
    
    func cancel(_ taskId: UUID) {
        guard let managedTask = tasks[taskId] else { return }
        
        managedTask.cancellationToken.cancel()
        managedTask.task.cancel()
        
        tasks[taskId] = nil
        runningTasks.remove(taskId)
        removeFromQueues(taskId)
        
        logger.info("🛑 Cancelled task \(taskId)")
    }
    
    func cancelGroup(_ group: String) {
        guard let groupTasks = taskGroups[group] else { return }
        
        for taskId in groupTasks {
            cancel(taskId)
        }
        
        taskGroups[group] = nil
        logger.info("🛑 Cancelled group '\(group)' with \(groupTasks.count) tasks")
    }
    
    func cancelAll() {
        let allTaskIds = Array(tasks.keys)
        
        for taskId in allTaskIds {
            cancel(taskId)
        }
        
        taskGroups.removeAll()
        logger.info("🛑 Cancelled all \(allTaskIds.count) tasks")
    }
    
    // MARK: - Query
    
    func getMetrics() -> TaskMetrics {
        metrics
    }
    
    func getTaskCount() -> (total: Int, running: Int, pending: Int) {
        let total = tasks.count
        let running = runningTasks.count
        let pending = total - running
        return (total, running, pending)
    }
    
    // MARK: - Private Helpers
    
    private func removeFromQueues(_ taskId: UUID) {
        // Remove from priority queues
        for priority in AppTaskPriority.allCases {
            priorityQueues[priority]?.removeAll { $0 == taskId }
        }
        
        // Remove from groups
        for (group, var taskIds) in taskGroups {
            if taskIds.remove(taskId) != nil {
                if taskIds.isEmpty {
                    taskGroups[group] = nil
                } else {
                    taskGroups[group] = taskIds
                }
            }
        }
    }
}

// MARK: - Task Handle

final class TaskHandle<T> {
    let id: UUID
    let cancellationToken: CancellationToken
    private weak var manager: TaskManager?
    private var task: Task<T, Error>?
    
    init(id: UUID, cancellationToken: CancellationToken, manager: TaskManager) {
        self.id = id
        self.cancellationToken = cancellationToken
        self.manager = manager
    }
    
    func setTask(_ task: Task<T, Error>) {
        self.task = task
    }
    
    var value: T {
        get async throws {
            guard let task = task else {
                throw TaskError.taskNotStarted
            }
            return try await task.value
        }
    }
    
    func cancel() {
        Task {
            await manager?.cancel(id)
        }
    }
    
    var isCancelled: Bool {
        cancellationToken.isCancelled
    }
}

// MARK: - Supporting Types

struct ManagedTask {
    let id: UUID
    let priority: AppTaskPriority
    let group: String?
    let task: Task<Any, Error>
    let cancellationToken: CancellationToken
    let createdAt: Date
}

enum AppTaskPriority: String, CaseIterable, Comparable, Hashable {
    case low = "1_low"
    case medium = "2_medium"
    case high = "3_high"
    case critical = "4_critical"
    
    static func < (lhs: AppTaskPriority, rhs: AppTaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    func toSwiftPriority() -> TaskPriority {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .critical: return .high // Swift doesn't have critical
        }
    }
}

enum TaskError: LocalizedError {
    case managerDeallocated
    case taskNotStarted
    case cancelled
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .managerDeallocated:
            return "Task manager was deallocated"
        case .taskNotStarted:
            return "Task has not been started"
        case .cancelled:
            return "Task was cancelled"
        case .timeout:
            return "Task timed out"
        }
    }
}

struct TaskMetrics {
    private(set) var totalTasks: Int = 0
    private(set) var completedTasks: Int = 0
    private(set) var failedTasks: Int = 0
    private(set) var cancelledTasks: Int = 0
    private(set) var averageExecutionTime: TimeInterval = 0
    
    private var executionTimes: [TimeInterval] = []
    
    mutating func taskStarted() {
        totalTasks += 1
    }
    
    mutating func taskCompleted(executionTime: TimeInterval = 0) {
        completedTasks += 1
        if executionTime > 0 {
            executionTimes.append(executionTime)
            averageExecutionTime = executionTimes.reduce(0, +) / Double(executionTimes.count)
        }
    }
    
    mutating func taskFailed() {
        failedTasks += 1
    }
    
    mutating func taskCancelled() {
        cancelledTasks += 1
    }
    
    var successRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
}

// MARK: - Async Sequences for Task Streaming

struct TaskStream<T>: AsyncSequence {
    typealias Element = Result<T, Error>
    
    private let tasks: [() async throws -> T]
    private let maxConcurrency: Int
    
    init(tasks: [() async throws -> T], maxConcurrency: Int = 3) {
        self.tasks = tasks
        self.maxConcurrency = maxConcurrency
    }
    
    func makeAsyncIterator() -> TaskStreamIterator<T> {
        TaskStreamIterator(tasks: tasks, maxConcurrency: maxConcurrency)
    }
}

struct TaskStreamIterator<T>: AsyncIteratorProtocol {
    typealias Element = Result<T, Error>
    
    private let tasks: [() async throws -> T]
    private let maxConcurrency: Int
    private var currentIndex = 0
    private var activeTasks: [Task<Element, Never>] = []
    
    init(tasks: [() async throws -> T], maxConcurrency: Int) {
        self.tasks = tasks
        self.maxConcurrency = maxConcurrency
    }
    
    mutating func next() async -> Element? {
        // Start new tasks up to concurrency limit
        while currentIndex < tasks.count && activeTasks.count < maxConcurrency {
            let index = currentIndex
            let tasksCopy = tasks  // Create a local copy to avoid capturing self
            let task = Task<Element, Never> {
                do {
                    let result = try await tasksCopy[index]()
                    return .success(result)
                } catch {
                    return .failure(error)
                }
            }
            activeTasks.append(task)
            currentIndex += 1
        }
        
        // Return nil if no tasks remain
        guard !activeTasks.isEmpty else { return nil }
        
        // Wait for any task to complete
        let result = await activeTasks.first!.value
        activeTasks.removeFirst()
        
        return result
    }
}

// MARK: - Structured Concurrency Helpers

extension Task where Success == Never, Failure == Never {
    /// Sleep with cancellation support
    static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

extension TaskGroup {
    /// Add task with automatic cancellation on group cancellation
    mutating func addTaskWithCancellation<T>(
        priority: AppTaskPriority = .medium,
        operation: @escaping () async throws -> T
    ) where ChildTaskResult == Result<T, Error> {
        addTask(priority: priority.toSwiftPriority()) {
            do {
                let result = try await operation()
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
    }
}