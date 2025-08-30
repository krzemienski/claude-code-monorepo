import SwiftUI
import Combine
import Foundation
import os.log

// MARK: - MCP Models
struct MCPServer: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let icon: String
    var isEnabled: Bool
    let category: ServerCategory
    
    enum ServerCategory: String, CaseIterable, Codable {
        case fileSystem = "File System"
        case shell = "Shell & Terminal"
        case versionControl = "Version Control"
        case container = "Container Management"
        case network = "Network & Remote"
        case `protocol` = "MCP Protocol"
        
        var icon: String {
            switch self {
            case .fileSystem: return "folder.fill"
            case .shell: return "terminal"
            case .versionControl: return "arrow.triangle.branch"
            case .container: return "cube.box"
            case .network: return "network"
            case .protocol: return "server.rack"
            }
        }
        
        var color: Color {
            switch self {
            case .fileSystem: return Color(h: 220, s: 100, l: 50)
            case .shell: return Color(h: 45, s: 100, l: 50)
            case .versionControl: return Color(h: 280, s: 100, l: 50)
            case .container: return Color(h: 180, s: 100, l: 50)
            case .network: return Color(h: 140, s: 100, l: 50)
            case .protocol: return Color(h: 30, s: 100, l: 50)
            }
        }
    }
}

struct MCPTool: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let serverId: String
    var isEnabled: Bool
    let category: ToolCategory
    
    enum ToolCategory: String, CaseIterable, Codable {
        case fileOperations = "File Operations"
        case searchFilter = "Search & Filter"
        case shellCommands = "Shell Commands"
        case gitOperations = "Git Operations"
        case dockerOperations = "Docker Operations"
        case dataProcessing = "Data Processing"
        
        var icon: String {
            switch self {
            case .fileOperations: return "doc.fill"
            case .searchFilter: return "magnifyingglass"
            case .shellCommands: return "terminal"
            case .gitOperations: return "arrow.triangle.branch"
            case .dockerOperations: return "cube.box.fill"
            case .dataProcessing: return "cpu"
            }
        }
        
        var color: Color {
            switch self {
            case .fileOperations: return Color(h: 210, s: 100, l: 50)
            case .searchFilter: return Color(h: 45, s: 100, l: 50)
            case .shellCommands: return Color(h: 30, s: 100, l: 50)
            case .gitOperations: return Color(h: 280, s: 100, l: 50)
            case .dockerOperations: return Color(h: 180, s: 100, l: 50)
            case .dataProcessing: return Color(h: 140, s: 100, l: 50)
            }
        }
    }
}

struct MCPConfiguration: Codable {
    var enabledServers: Set<String>
    var enabledTools: Set<String>
    var toolPriority: [String]
    var auditLogging: Bool
    var maxConcurrentTools: Int
    var toolTimeout: TimeInterval
    var cacheEnabled: Bool
    var securityLevel: SecurityLevel
    
    enum SecurityLevel: String, CaseIterable, Codable {
        case low = "Low - Allow all operations"
        case medium = "Medium - Prompt for dangerous operations"
        case high = "High - Restrict dangerous operations"
        
        var color: Color {
            switch self {
            case .low: return .orange
            case .medium: return .yellow
            case .high: return .green
            }
        }
    }
}

// MARK: - MCP View Model
@MainActor
final class MCPViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var servers: [MCPServer] = []
    @Published var tools: [MCPTool] = []
    @Published var configuration: MCPConfiguration
    @Published var isLoading = false
    @Published var error: Error?
    @Published var saveStatus: SaveStatus = .idle
    @Published var searchText = ""
    @Published var selectedCategory: String = "All"
    @Published var sessionTools: [String: Set<String>] = [:]
    
    // MARK: - Save Status
    enum SaveStatus {
        case idle
        case saving
        case saved
        case error(String)
        
        var message: String {
            switch self {
            case .idle: return ""
            case .saving: return "Saving..."
            case .saved: return "Configuration saved"
            case .error(let msg): return "Error: \(msg)"
            }
        }
        
        var color: Color {
            switch self {
            case .idle: return .clear
            case .saving: return .orange
            case .saved: return .green
            case .error: return .red
            }
        }
    }
    
    // MARK: - Private Properties
    @AppStorage("mcpConfigurationJSON") private var storedConfigJSON: String = ""
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.yourorg.claudecode", category: "MCPViewModel")
    @OptionalInjected(APIClientProtocol.self) private var apiClient: APIClientProtocol?
    
    // MARK: - Computed Properties
    var filteredServers: [MCPServer] {
        servers.filter { server in
            let matchesSearch = searchText.isEmpty || 
                server.name.localizedCaseInsensitiveContains(searchText) ||
                server.description.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == "All" || 
                server.category.rawValue == selectedCategory
            
            return matchesSearch && matchesCategory
        }
    }
    
    var filteredTools: [MCPTool] {
        tools.filter { tool in
            let matchesSearch = searchText.isEmpty || 
                tool.name.localizedCaseInsensitiveContains(searchText) ||
                tool.description.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == "All" || 
                tool.category.rawValue == selectedCategory
            
            // Only show tools for enabled servers
            let serverEnabled = configuration.enabledServers.contains(tool.serverId)
            
            return matchesSearch && matchesCategory && serverEnabled
        }
    }
    
    var enabledServersCount: Int {
        servers.filter { configuration.enabledServers.contains($0.id) }.count
    }
    
    var enabledToolsCount: Int {
        tools.filter { configuration.enabledTools.contains($0.id) }.count
    }
    
    var serverCategories: [String] {
        ["All"] + MCPServer.ServerCategory.allCases.map { $0.rawValue }
    }
    
    var toolCategories: [String] {
        ["All"] + MCPTool.ToolCategory.allCases.map { $0.rawValue }
    }
    
    // MARK: - Initialization
    init() {
        // Dependencies are automatically injected via property wrappers
        
        // Initialize with default configuration
        self.configuration = MCPConfiguration(
            enabledServers: [],
            enabledTools: [],
            toolPriority: [],
            auditLogging: true,
            maxConcurrentTools: 5,
            toolTimeout: 30.0,
            cacheEnabled: true,
            securityLevel: .medium
        )
        
        loadConfiguration()
        loadDefaultServersAndTools()
        setupSubscriptions()
    }
    
    // MARK: - Setup Methods
    private func setupSubscriptions() {
        // Auto-save configuration changes
        $configuration
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveConfiguration()
            }
            .store(in: &cancellables)
        
        // Clear save status after delay
        $saveStatus
            .filter { if case .saved = $0 { return true } else { return false } }
            .delay(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveStatus = .idle
            }
            .store(in: &cancellables)
    }
    
    private func loadDefaultServersAndTools() {
        // Load default servers
        servers = [
            MCPServer(id: "fs-local", name: "Local File System", description: "Access local files and directories", icon: "folder.fill", isEnabled: true, category: .fileSystem),
            MCPServer(id: "bash", name: "Bash Shell", description: "Execute shell commands", icon: "terminal", isEnabled: true, category: .shell),
            MCPServer(id: "git", name: "Git", description: "Version control operations", icon: "arrow.triangle.branch", isEnabled: true, category: .versionControl),
            MCPServer(id: "docker", name: "Docker", description: "Container management", icon: "cube.box", isEnabled: false, category: .container),
            MCPServer(id: "ssh", name: "SSH", description: "Remote connections", icon: "network", isEnabled: false, category: .network),
            MCPServer(id: "mcp-server", name: "MCP Server", description: "MCP protocol server", icon: "server.rack", isEnabled: false, category: .protocol)
        ]
        
        // Load default tools
        tools = [
            // File System Tools
            MCPTool(id: "fs.read", name: "Read File", description: "Read file contents", serverId: "fs-local", isEnabled: true, category: .fileOperations),
            MCPTool(id: "fs.write", name: "Write File", description: "Write content to file", serverId: "fs-local", isEnabled: true, category: .fileOperations),
            MCPTool(id: "fs.delete", name: "Delete File", description: "Delete files or directories", serverId: "fs-local", isEnabled: false, category: .fileOperations),
            MCPTool(id: "fs.mkdir", name: "Create Directory", description: "Create new directories", serverId: "fs-local", isEnabled: true, category: .fileOperations),
            
            // Search Tools
            MCPTool(id: "grep.search", name: "Grep Search", description: "Search text patterns in files", serverId: "bash", isEnabled: true, category: .searchFilter),
            MCPTool(id: "find.files", name: "Find Files", description: "Find files by name or pattern", serverId: "bash", isEnabled: true, category: .searchFilter),
            
            // Shell Tools
            MCPTool(id: "bash.run", name: "Run Command", description: "Execute shell commands", serverId: "bash", isEnabled: true, category: .shellCommands),
            MCPTool(id: "bash.interactive", name: "Interactive Shell", description: "Interactive shell session", serverId: "bash", isEnabled: false, category: .shellCommands),
            
            // Git Tools
            MCPTool(id: "git.status", name: "Git Status", description: "Show repository status", serverId: "git", isEnabled: true, category: .gitOperations),
            MCPTool(id: "git.commit", name: "Git Commit", description: "Commit changes", serverId: "git", isEnabled: true, category: .gitOperations),
            MCPTool(id: "git.push", name: "Git Push", description: "Push to remote", serverId: "git", isEnabled: false, category: .gitOperations),
            MCPTool(id: "git.pull", name: "Git Pull", description: "Pull from remote", serverId: "git", isEnabled: false, category: .gitOperations),
            
            // Docker Tools
            MCPTool(id: "docker.ps", name: "List Containers", description: "List Docker containers", serverId: "docker", isEnabled: false, category: .dockerOperations),
            MCPTool(id: "docker.logs", name: "Container Logs", description: "View container logs", serverId: "docker", isEnabled: false, category: .dockerOperations)
        ]
        
        // Apply stored configuration
        applyStoredConfiguration()
    }
    
    // MARK: - Configuration Management
    private func loadConfiguration() {
        guard !storedConfigJSON.isEmpty,
              let data = storedConfigJSON.data(using: .utf8),
              let config = try? JSONDecoder().decode(MCPConfiguration.self, from: data) else {
            logger.info("No stored configuration found, using defaults")
            return
        }
        
        configuration = config
        logger.info("Loaded configuration with \(config.enabledServers.count) servers and \(config.enabledTools.count) tools")
    }
    
    private func applyStoredConfiguration() {
        // Update server states
        for index in servers.indices {
            servers[index].isEnabled = configuration.enabledServers.contains(servers[index].id)
        }
        
        // Update tool states
        for index in tools.indices {
            tools[index].isEnabled = configuration.enabledTools.contains(tools[index].id)
        }
    }
    
    func saveConfiguration() {
        saveStatus = .saving
        
        do {
            let data = try JSONEncoder().encode(configuration)
            storedConfigJSON = String(data: data, encoding: .utf8) ?? ""
            saveStatus = .saved
            logger.info("Configuration saved successfully")
        } catch {
            saveStatus = .error(error.localizedDescription)
            logger.error("Failed to save configuration: \(error)")
        }
    }
    
    // MARK: - Server Management
    func toggleServer(_ serverId: String) {
        guard let index = servers.firstIndex(where: { $0.id == serverId }) else { return }
        
        servers[index].isEnabled.toggle()
        
        if servers[index].isEnabled {
            configuration.enabledServers.insert(serverId)
        } else {
            configuration.enabledServers.remove(serverId)
            // Disable all tools for this server
            tools.indices.forEach { toolIndex in
                if tools[toolIndex].serverId == serverId {
                    tools[toolIndex].isEnabled = false
                    configuration.enabledTools.remove(tools[toolIndex].id)
                }
            }
        }
        
        logger.info("Toggled server \(serverId): \(self.servers[index].isEnabled)")
    }
    
    func enableAllServers() {
        servers.indices.forEach { index in
            servers[index].isEnabled = true
            configuration.enabledServers.insert(servers[index].id)
        }
    }
    
    func disableAllServers() {
        servers.indices.forEach { index in
            servers[index].isEnabled = false
        }
        configuration.enabledServers.removeAll()
        configuration.enabledTools.removeAll()
        
        // Disable all tools
        tools.indices.forEach { index in
            tools[index].isEnabled = false
        }
    }
    
    // MARK: - Tool Management
    func toggleTool(_ toolId: String) {
        guard let index = tools.firstIndex(where: { $0.id == toolId }) else { return }
        
        tools[index].isEnabled.toggle()
        
        if tools[index].isEnabled {
            configuration.enabledTools.insert(toolId)
            // Ensure server is enabled
            if !configuration.enabledServers.contains(tools[index].serverId) {
                toggleServer(tools[index].serverId)
            }
        } else {
            configuration.enabledTools.remove(toolId)
        }
        
        logger.info("Toggled tool \(toolId): \(self.tools[index].isEnabled)")
    }
    
    func setToolPriority(_ toolIds: [String]) {
        configuration.toolPriority = toolIds
        logger.info("Updated tool priority: \(toolIds)")
    }
    
    // MARK: - Session Tool Management
    func updateSessionTools(sessionId: String, tools: [String]) async throws {
        guard let apiClient = apiClient else {
            throw NSError(domain: "MCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "API client not available"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await apiClient.updateSessionTools(
                sessionId: sessionId,
                tools: tools,
                priority: configuration.maxConcurrentTools
            )
            
            sessionTools[sessionId] = Set(response.enabledTools)
            logger.info("Updated session tools for \(sessionId): \(response.enabledTools)")
            
        } catch {
            self.error = error
            logger.error("Failed to update session tools: \(error)")
            throw error
        }
    }
    
    func getSessionTools(sessionId: String) -> Set<String> {
        sessionTools[sessionId] ?? Set(configuration.enabledTools)
    }
    
    // MARK: - Security Management
    func setSecurityLevel(_ level: MCPConfiguration.SecurityLevel) {
        configuration.securityLevel = level
        
        // Apply security restrictions
        switch level {
        case .high:
            // Disable dangerous tools
            let dangerousTools = ["fs.delete", "bash.run", "bash.interactive", "git.push"]
            tools.indices.forEach { index in
                if dangerousTools.contains(tools[index].id) {
                    tools[index].isEnabled = false
                    configuration.enabledTools.remove(tools[index].id)
                }
            }
        case .medium:
            // Keep current settings but enable audit logging
            configuration.auditLogging = true
        case .low:
            // No restrictions
            break
        }
        
        logger.info("Security level set to: \(level.rawValue)")
    }
    
    // MARK: - Import/Export
    func exportConfiguration() -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)
            return String(data: data, encoding: .utf8)
        } catch {
            logger.error("Failed to export configuration: \(error)")
            return nil
        }
    }
    
    func importConfiguration(_ jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "MCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        
        let newConfig = try JSONDecoder().decode(MCPConfiguration.self, from: data)
        configuration = newConfig
        applyStoredConfiguration()
        saveConfiguration()
        
        logger.info("Imported configuration successfully")
    }
    
    // MARK: - Reset
    func resetToDefaults() {
        configuration = MCPConfiguration(
            enabledServers: ["fs-local", "bash", "git"],
            enabledTools: ["fs.read", "fs.write", "grep.search", "bash.run", "git.status"],
            toolPriority: ["fs.read", "bash.run", "fs.write", "git.status"],
            auditLogging: true,
            maxConcurrentTools: 5,
            toolTimeout: 30.0,
            cacheEnabled: true,
            securityLevel: .medium
        )
        
        applyStoredConfiguration()
        saveConfiguration()
        
        logger.info("Reset configuration to defaults")
    }
}