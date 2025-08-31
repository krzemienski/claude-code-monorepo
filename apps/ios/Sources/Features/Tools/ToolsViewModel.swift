import SwiftUI
import Combine
import os.log

// MARK: - MCP Tool Model
struct MCPTool: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let category: String
    let icon: String
    var isEnabled: Bool
    let inputSchema: [String: Any]?
    let server: String?
    var usageCount: Int
    var lastUsed: Date?
    var avgExecutionTime: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, icon
        case isEnabled = "is_enabled"
        case inputSchema = "input_schema"
        case server
        case usageCount = "usage_count"
        case lastUsed = "last_used"
        case avgExecutionTime = "avg_execution_time"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(String.self, forKey: .category)
        icon = try container.decode(String.self, forKey: .icon)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        inputSchema = nil // Handle JSON schema separately
        server = try container.decodeIfPresent(String.self, forKey: .server)
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        lastUsed = try container.decodeIfPresent(Date.self, forKey: .lastUsed)
        avgExecutionTime = try container.decodeIfPresent(Double.self, forKey: .avgExecutionTime)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(icon, forKey: .icon)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(server, forKey: .server)
        try container.encode(usageCount, forKey: .usageCount)
        try container.encodeIfPresent(lastUsed, forKey: .lastUsed)
        try container.encodeIfPresent(avgExecutionTime, forKey: .avgExecutionTime)
    }
}

// MARK: - Tool Statistics
struct ToolStatistics {
    let totalTools: Int
    let enabledTools: Int
    let totalExecutions: Int
    let avgExecutionTime: Double
    let mostUsedTool: String?
    let recentExecutions: [ToolExecution]
}

// MARK: - Tool Execution History
struct ToolExecution: Identifiable {
    let id: String
    let toolId: String
    let toolName: String
    let timestamp: Date
    let duration: Double
    let status: ExecutionStatus
    let error: String?
    
    enum ExecutionStatus: String {
        case success, failure, timeout
    }
}

// MARK: - Tools View Model
@MainActor
final class ToolsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var tools: [MCPTool] = []
    @Published var filteredTools: [MCPTool] = []
    @Published var categories: [String] = ["All"]
    @Published var selectedCategory: String = "All"
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var statistics: ToolStatistics?
    @Published var showingStatistics: Bool = false
    @Published var sortOption: SortOption = .name
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case category = "Category"
        case usage = "Most Used"
        case recent = "Recently Used"
    }
    
    // MARK: - Private Properties
    @Injected(APIClientProtocol.self) private var apiClient: APIClientProtocol
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode", category: "ToolsViewModel")
    private var sessionId: String?
    
    // MARK: - Initialization
    init(sessionId: String? = nil) {
        self.sessionId = sessionId
        setupBindings()
        Task { await loadTools() }
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Filter tools when search or category changes
        Publishers.CombineLatest3($searchText, $selectedCategory, $tools)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] searchText, category, tools in
                self?.filterTools(searchText: searchText, category: category, tools: tools)
            }
            .store(in: &cancellables)
        
        // Sort tools when option changes
        $sortOption
            .combineLatest($filteredTools)
            .sink { [weak self] sortOption, _ in
                self?.sortTools(by: sortOption)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func loadTools() async {
        isLoading = true
        error = nil
        
        do {
            // Fetch tools from API
            let fetchedTools = try await fetchToolsFromAPI()
            tools = fetchedTools
            
            // Extract unique categories
            let uniqueCategories = Set(fetchedTools.map { $0.category })
            categories = ["All"] + uniqueCategories.sorted()
            
            // Load statistics
            await loadStatistics()
            
            logger.info("Loaded \(fetchedTools.count) tools")
        } catch {
            // Fallback to mock data
            loadMockTools()
            logger.error("Failed to load tools: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    func toggleTool(_ tool: MCPTool) async {
        guard let index = tools.firstIndex(where: { $0.id == tool.id }) else { return }
        
        // Update local state
        tools[index].isEnabled.toggle()
        
        // Update on server
        do {
            try await updateToolState(tool.id, enabled: tools[index].isEnabled)
            logger.info("Tool \(tool.name) \(tools[index].isEnabled ? "enabled" : "disabled")")
        } catch {
            // Revert on error
            tools[index].isEnabled.toggle()
            logger.error("Failed to update tool state: \(error)")
            self.error = error
        }
    }
    
    func loadStatistics() async {
        do {
            let stats = try await fetchStatisticsFromAPI()
            statistics = stats
        } catch {
            logger.error("Failed to load statistics: \(error)")
        }
    }
    
    func refreshTools() async {
        await loadTools()
    }
    
    // MARK: - Private Methods
    private func fetchToolsFromAPI() async throws -> [MCPTool] {
        // Mock implementation - replace with actual API call
        // if let sessionId = sessionId {
        //     return try await apiClient.getJSON("/v1/sessions/\(sessionId)/tools", as: [MCPTool].self)
        // } else {
        //     return try await apiClient.getJSON("/v1/tools", as: [MCPTool].self)
        // }
        throw URLError(.notConnectedToInternet) // Temporary fallback
    }
    
    private func updateToolState(_ toolId: String, enabled: Bool) async throws {
        // Mock implementation - replace with actual API call
        // let body = ["enabled": enabled]
        // if let sessionId = sessionId {
        //     try await apiClient.postJSON("/v1/sessions/\(sessionId)/tools/\(toolId)", body: body, as: EmptyResponse.self)
        // } else {
        //     try await apiClient.postJSON("/v1/tools/\(toolId)", body: body, as: EmptyResponse.self)
        // }
    }
    
    private func fetchStatisticsFromAPI() async throws -> ToolStatistics {
        // Mock implementation - replace with actual API call
        return ToolStatistics(
            totalTools: tools.count,
            enabledTools: tools.filter { $0.isEnabled }.count,
            totalExecutions: tools.reduce(0) { $0 + $1.usageCount },
            avgExecutionTime: tools.compactMap { $0.avgExecutionTime }.reduce(0, +) / Double(tools.count),
            mostUsedTool: tools.max(by: { $0.usageCount < $1.usageCount })?.name,
            recentExecutions: []
        )
    }
    
    private func filterTools(searchText: String, category: String, tools: [MCPTool]) {
        var filtered = tools
        
        // Filter by category
        if category != "All" {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { tool in
                tool.name.localizedCaseInsensitiveContains(searchText) ||
                tool.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        filteredTools = filtered
        sortTools(by: sortOption)
    }
    
    private func sortTools(by option: SortOption) {
        switch option {
        case .name:
            filteredTools.sort { $0.name < $1.name }
        case .category:
            filteredTools.sort { 
                if $0.category == $1.category {
                    return $0.name < $1.name
                }
                return $0.category < $1.category
            }
        case .usage:
            filteredTools.sort { $0.usageCount > $1.usageCount }
        case .recent:
            filteredTools.sort { 
                let date1 = $0.lastUsed ?? Date.distantPast
                let date2 = $1.lastUsed ?? Date.distantPast
                return date1 > date2
            }
        }
    }
    
    private func loadMockTools() {
        tools = [
            MCPTool(
                id: "1",
                name: "Read File",
                description: "Read contents of a file",
                category: "File",
                icon: "doc.text",
                isEnabled: true,
                inputSchema: nil,
                server: "filesystem",
                usageCount: 150,
                lastUsed: Date().addingTimeInterval(-3600),
                avgExecutionTime: 0.5
            ),
            MCPTool(
                id: "2",
                name: "Write File",
                description: "Write or create a file",
                category: "File",
                icon: "square.and.pencil",
                isEnabled: true,
                inputSchema: nil,
                server: "filesystem",
                usageCount: 120,
                lastUsed: Date().addingTimeInterval(-7200),
                avgExecutionTime: 0.8
            ),
            MCPTool(
                id: "3",
                name: "Git Status",
                description: "Check git repository status",
                category: "Git",
                icon: "arrow.triangle.branch",
                isEnabled: true,
                inputSchema: nil,
                server: "git",
                usageCount: 80,
                lastUsed: Date().addingTimeInterval(-1800),
                avgExecutionTime: 1.2
            ),
            MCPTool(
                id: "4",
                name: "Bash Command",
                description: "Execute shell commands",
                category: "System",
                icon: "terminal",
                isEnabled: false,
                inputSchema: nil,
                server: "system",
                usageCount: 45,
                lastUsed: nil,
                avgExecutionTime: 2.5
            ),
            MCPTool(
                id: "5",
                name: "HTTP Request",
                description: "Make HTTP API calls",
                category: "Network",
                icon: "network",
                isEnabled: true,
                inputSchema: nil,
                server: "network",
                usageCount: 200,
                lastUsed: Date(),
                avgExecutionTime: 3.0
            )
        ]
        
        let uniqueCategories = Set(tools.map { $0.category })
        categories = ["All"] + uniqueCategories.sorted()
    }
    
    // Placeholder for empty response
    private struct EmptyResponse: Decodable {}
}