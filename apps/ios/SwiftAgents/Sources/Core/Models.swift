import Foundation
import SwiftSyntax
import Markdown

// MARK: - Core Models

/// Represents a documentation file with its content and metadata
public struct DocumentationFile {
    public let path: URL
    public let content: String
    public let lastModified: Date
    public let codeBlocks: [SwiftCodeBlock]
    
    public init(path: URL, content: String, lastModified: Date, codeBlocks: [SwiftCodeBlock]) {
        self.path = path
        self.content = content
        self.lastModified = lastModified
        self.codeBlocks = codeBlocks
    }
}

/// Represents a Swift code block extracted from documentation
public struct SwiftCodeBlock {
    public let id: UUID
    public let code: String
    public let language: String
    public let lineNumber: Int
    public let fileName: String
    public let metadata: CodeBlockMetadata
    
    public init(id: UUID = UUID(), code: String, language: String, lineNumber: Int, fileName: String, metadata: CodeBlockMetadata = CodeBlockMetadata()) {
        self.id = id
        self.code = code
        self.language = language
        self.lineNumber = lineNumber
        self.fileName = fileName
        self.metadata = metadata
    }
}

/// Metadata associated with a code block
public struct CodeBlockMetadata {
    public let title: String?
    public let description: String?
    public let expectedOutput: String?
    public let iOSVersion: String?
    public let swiftVersion: String?
    public let tags: [String]
    
    public init(title: String? = nil, description: String? = nil, expectedOutput: String? = nil, iOSVersion: String? = nil, swiftVersion: String? = nil, tags: [String] = []) {
        self.title = title
        self.description = description
        self.expectedOutput = expectedOutput
        self.iOSVersion = iOSVersion
        self.swiftVersion = swiftVersion
        self.tags = tags
    }
}

// MARK: - Validation Models

/// Result of code validation
public struct ValidationResult {
    public let codeBlock: SwiftCodeBlock
    public let status: ValidationStatus
    public let errors: [ValidationError]
    public let warnings: [ValidationWarning]
    public let suggestions: [String]
    public let performance: PerformanceMetrics?
    
    public init(codeBlock: SwiftCodeBlock, status: ValidationStatus, errors: [ValidationError], warnings: [ValidationWarning], suggestions: [String], performance: PerformanceMetrics? = nil) {
        self.codeBlock = codeBlock
        self.status = status
        self.errors = errors
        self.warnings = warnings
        self.suggestions = suggestions
        self.performance = performance
    }
}

public enum ValidationStatus {
    case success
    case warning
    case error
    case skipped
}

public struct ValidationError {
    public let message: String
    public let line: Int?
    public let column: Int?
    public let severity: ErrorSeverity
    
    public init(message: String, line: Int? = nil, column: Int? = nil, severity: ErrorSeverity) {
        self.message = message
        self.line = line
        self.column = column
        self.severity = severity
    }
}

public enum ErrorSeverity {
    case critical
    case major
    case minor
}

public struct ValidationWarning {
    public let message: String
    public let type: WarningType
    
    public init(message: String, type: WarningType) {
        self.message = message
        self.type = type
    }
}

public enum WarningType {
    case deprecated
    case performance
    case bestPractice
    case accessibility
    case memory
}

// MARK: - Execution Models

public struct ExecutionResult {
    public let success: Bool
    public let output: String?
    public let error: String?
    public let executionTime: TimeInterval
    public let memoryUsage: MemoryProfile?
    
    public init(success: Bool, output: String? = nil, error: String? = nil, executionTime: TimeInterval, memoryUsage: MemoryProfile? = nil) {
        self.success = success
        self.output = output
        self.error = error
        self.executionTime = executionTime
        self.memoryUsage = memoryUsage
    }
}

public struct SimulatorResult {
    public let device: String
    public let iOSVersion: String
    public let screenshots: [URL]
    public let logs: [String]
    public let success: Bool
    
    public init(device: String, iOSVersion: String, screenshots: [URL], logs: [String], success: Bool) {
        self.device = device
        self.iOSVersion = iOSVersion
        self.screenshots = screenshots
        self.logs = logs
        self.success = success
    }
}

// MARK: - Performance Models

public struct PerformanceMetrics {
    public let cpuUsage: Double
    public let memoryUsage: MemoryProfile
    public let executionTime: TimeInterval
    public let diskIO: DiskIOMetrics?
    
    public init(cpuUsage: Double, memoryUsage: MemoryProfile, executionTime: TimeInterval, diskIO: DiskIOMetrics? = nil) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.executionTime = executionTime
        self.diskIO = diskIO
    }
}

public struct MemoryProfile {
    public let peak: Int64
    public let average: Int64
    public let leaks: [MemoryLeak]
    
    public init(peak: Int64, average: Int64, leaks: [MemoryLeak] = []) {
        self.peak = peak
        self.average = average
        self.leaks = leaks
    }
}

public struct MemoryLeak {
    public let size: Int64
    public let location: String
    public let type: String
    
    public init(size: Int64, location: String, type: String) {
        self.size = size
        self.location = location
        self.type = type
    }
}

public struct DiskIOMetrics {
    public let reads: Int64
    public let writes: Int64
    public let readTime: TimeInterval
    public let writeTime: TimeInterval
    
    public init(reads: Int64, writes: Int64, readTime: TimeInterval, writeTime: TimeInterval) {
        self.reads = reads
        self.writes = writes
        self.readTime = readTime
        self.writeTime = writeTime
    }
}

// MARK: - Report Models

public struct ValidationReport {
    public let timestamp: Date
    public let results: [ValidationResult]
    public let summary: ReportSummary
    public let recommendations: [String]
    
    public init(timestamp: Date = Date(), results: [ValidationResult], summary: ReportSummary, recommendations: [String]) {
        self.timestamp = timestamp
        self.results = results
        self.summary = summary
        self.recommendations = recommendations
    }
}

public struct ReportSummary {
    public let totalFiles: Int
    public let totalCodeBlocks: Int
    public let successCount: Int
    public let warningCount: Int
    public let errorCount: Int
    public let coveragePercentage: Double
    
    public init(totalFiles: Int, totalCodeBlocks: Int, successCount: Int, warningCount: Int, errorCount: Int, coveragePercentage: Double) {
        self.totalFiles = totalFiles
        self.totalCodeBlocks = totalCodeBlocks
        self.successCount = successCount
        self.warningCount = warningCount
        self.errorCount = errorCount
        self.coveragePercentage = coveragePercentage
    }
}

// MARK: - Agent Communication Models

public struct AgentMessage {
    public let id: UUID
    public let sender: String
    public let receiver: String
    public let type: MessageType
    public let payload: Data
    public let timestamp: Date
    
    public init(id: UUID = UUID(), sender: String, receiver: String, type: MessageType, payload: Data, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.receiver = receiver
        self.type = type
        self.payload = payload
        self.timestamp = timestamp
    }
}

public enum MessageType {
    case taskAssignment
    case statusUpdate
    case resultDelivery
    case errorReport
    case coordinationRequest
}

public struct AgentUpdate {
    public let agent: String
    public let status: AgentStatus
    public let progress: Double
    public let message: String?
    
    public init(agent: String, status: AgentStatus, progress: Double, message: String? = nil) {
        self.agent = agent
        self.status = status
        self.progress = progress
        self.message = message
    }
}

public enum AgentStatus {
    case idle
    case running
    case completed
    case failed
    case paused
}

// MARK: - Task Queue Models

public struct AgentTask: Codable {
    public let id: UUID
    public let type: TaskType
    public let priority: TaskPriority
    public let input: TaskInput
    public let createdAt: Date
    public var status: TaskStatus
    public var assignedAgent: String?
    public var result: TaskResult?
    
    public init(id: UUID = UUID(), type: TaskType, priority: TaskPriority, input: TaskInput, createdAt: Date = Date(), status: TaskStatus = .pending, assignedAgent: String? = nil, result: TaskResult? = nil) {
        self.id = id
        self.type = type
        self.priority = priority
        self.input = input
        self.createdAt = createdAt
        self.status = status
        self.assignedAgent = assignedAgent
        self.result = result
    }
}

public enum TaskType: String, Codable {
    case documentationRefactor
    case codeVerification
    case testGeneration
    case performanceAnalysis
    case accessibilityCheck
}

public enum TaskPriority: Int, Codable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public enum TaskStatus: String, Codable {
    case pending
    case assigned
    case inProgress
    case completed
    case failed
    case cancelled
}

public struct TaskInput: Codable {
    public let files: [String]
    public let configuration: [String: String]
    
    public init(files: [String], configuration: [String: String] = [:]) {
        self.files = files
        self.configuration = configuration
    }
}

public struct TaskResult: Codable {
    public let success: Bool
    public let outputPath: String?
    public let errors: [String]
    public let metrics: [String: Double]
    
    public init(success: Bool, outputPath: String? = nil, errors: [String] = [], metrics: [String: Double] = [:]) {
        self.success = success
        self.outputPath = outputPath
        self.errors = errors
        self.metrics = metrics
    }
}