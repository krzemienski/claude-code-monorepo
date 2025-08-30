# MCP (Model Context Protocol) Integration Documentation

## Overview

The iOS Claude Code app integrates with MCP servers to provide extended tool capabilities for AI sessions. MCP enables the app to connect to various server types (file system, shell, git, docker, etc.) and use their tools within AI chat sessions.

## Architecture

### Core Components

1. **MCPViewModel** (`/Sources/Features/MCP/MCPViewModel.swift`)
   - Central state management for MCP configuration
   - Manages servers, tools, and configurations
   - Handles persistence via `@AppStorage`
   - Coordinates with backend API

2. **MCPSettingsView** (`/Sources/Features/MCP/MCPSettingsView.swift`)
   - Main UI for global MCP configuration
   - Tabbed interface: Servers, Tools, Priority, Settings
   - Cyberpunk-themed UI with animations
   - Quick-add server suggestions

3. **SessionToolPickerView** (`/Sources/Features/MCP/SessionToolPickerView.swift`)
   - Per-session tool configuration
   - Overrides default MCP settings for specific sessions
   - Token-based tool selection UI
   - Drag-to-reorder priority management

## Data Models

### MCPServer
```swift
struct MCPServer {
    let id: String              // e.g., "fs-local", "bash", "git"
    let name: String           // Display name
    let description: String    // Server purpose
    let icon: String          // SF Symbol icon
    var isEnabled: Bool       // Active state
    let category: ServerCategory  // Categorization
}
```

### Server Categories
- **File System**: Local file access operations
- **Shell & Terminal**: Command execution
- **Version Control**: Git operations
- **Container Management**: Docker control
- **Network & Remote**: SSH and remote connections
- **MCP Protocol**: Core MCP servers

### MCPTool
```swift
struct MCPTool {
    let id: String              // e.g., "fs.read", "git.commit"
    let name: String           // Display name
    let description: String    // Tool purpose
    let serverId: String       // Parent server ID
    var isEnabled: Bool       // Active state
    let category: ToolCategory // Categorization
}
```

### Tool Categories
- **File Operations**: Read, write, delete, mkdir
- **Search & Filter**: Grep, find, search operations
- **Shell Commands**: Bash execution, interactive shell
- **Git Operations**: Status, commit, push, pull
- **Docker Operations**: Container management
- **Data Processing**: CPU-intensive operations

### MCPConfiguration
```swift
struct MCPConfiguration {
    var enabledServers: Set<String>      // Active server IDs
    var enabledTools: Set<String>        // Active tool IDs
    var toolPriority: [String]           // Execution order
    var auditLogging: Bool               // Log all operations
    var maxConcurrentTools: Int          // Parallel execution limit
    var toolTimeout: TimeInterval        // Operation timeout
    var cacheEnabled: Bool               // Result caching
    var securityLevel: SecurityLevel     // Access restrictions
}
```

### Security Levels
- **Low**: Allow all operations
- **Medium**: Prompt for dangerous operations
- **High**: Restrict dangerous operations (auto-disables fs.delete, bash.run, etc.)

## Default Servers and Tools

### Pre-configured Servers
1. **fs-local** (File System) - Enabled by default
2. **bash** (Shell) - Enabled by default
3. **git** (Version Control) - Enabled by default
4. **docker** (Containers) - Disabled by default
5. **ssh** (Remote) - Disabled by default
6. **mcp-server** (Protocol) - Disabled by default

### Pre-configured Tools

#### File System Tools (fs-local)
- `fs.read` - Read file contents ✅
- `fs.write` - Write to files ✅
- `fs.delete` - Delete files/directories ❌
- `fs.mkdir` - Create directories ✅

#### Search Tools (bash)
- `grep.search` - Pattern search ✅
- `find.files` - File discovery ✅

#### Shell Tools (bash)
- `bash.run` - Execute commands ✅
- `bash.interactive` - Interactive shell ❌

#### Git Tools (git)
- `git.status` - Repository status ✅
- `git.commit` - Commit changes ✅
- `git.push` - Push to remote ❌
- `git.pull` - Pull from remote ❌

#### Docker Tools (docker)
- `docker.ps` - List containers ❌
- `docker.logs` - View logs ❌

(✅ = Enabled by default, ❌ = Disabled by default)

## Configuration Storage

### Global Configuration
- **Storage Key**: `mcpConfigurationJSON`
- **Location**: UserDefaults via `@AppStorage`
- **Format**: JSON-encoded `MCPConfiguration`
- **Auto-save**: 1-second debounce on changes

### Session-Specific Configuration
- **Storage Key**: `mcpSession.<sessionId>`
- **Location**: UserDefaults via `@AppStorage`
- **Format**: JSON-encoded `MCPConfigLocal`
- **Fallback**: Uses global config if session config not found

### MCPConfigLocal Structure
```swift
struct MCPConfigLocal: Codable {
    var enabledServers: [String]
    var enabledTools: [String]
    var priority: [String]
    var auditLog: Bool
}
```

## API Integration

### Backend Endpoints

#### Update Session Tools
```swift
POST /v1/sessions/{sessionId}/tools
Body: {
    "tools": ["fs.read", "bash.run", ...],
    "priority": 5  // maxConcurrentTools
}
Response: {
    "sessionId": "...",
    "enabledTools": [...],
    "message": "Tools updated successfully"
}
```

### APIClient Integration
The `MCPViewModel` uses `APIClient.updateSessionTools()` to sync tool configurations with the backend when session-specific tools are modified.

## User Interface Features

### MCPSettingsView Features
1. **Status Cards**: Real-time display of enabled servers/tools count
2. **Tab Navigation**: Organized sections for different aspects
3. **Quick Add**: Suggested servers with one-tap addition
4. **Visual Feedback**: Animated status indicators
5. **Security Controls**: Security level selection with automatic restrictions
6. **Import/Export**: Configuration backup and restore

### SessionToolPickerView Features
1. **Token Editor**: Add/remove tools with visual chips
2. **Drag-to-Reorder**: Priority management via drag gestures
3. **Audit Toggle**: Per-session logging control
4. **Inheritance**: Falls back to global config when needed

## Lifecycle Management

### Initialization Flow
1. `MCPViewModel` loads stored configuration from UserDefaults
2. Default servers and tools are populated
3. Stored configuration is applied to update enabled states
4. Subscriptions are set up for auto-save

### Configuration Updates
1. User toggles server/tool in UI
2. ViewModel updates internal state
3. Configuration object is modified
4. Auto-save triggers after 1-second debounce
5. If session-specific, API call updates backend

### Server Toggle Behavior
- Enabling a server keeps its tools in their current state
- Disabling a server automatically disables all its tools
- Tool enabling automatically enables its parent server

## Security Considerations

### High Security Mode
When security level is set to "High":
- Dangerous tools are automatically disabled
- Tools affected: `fs.delete`, `bash.run`, `bash.interactive`, `git.push`
- Audit logging is enforced
- User cannot re-enable dangerous tools while in this mode

### Audit Logging
When enabled:
- All tool executions are logged
- Logs include timestamp, tool ID, session ID
- Backend maintains audit trail for compliance

## Best Practices

### Tool Selection
1. Enable only necessary tools for the task
2. Use high security mode for production environments
3. Disable shell access when not needed
4. Limit concurrent tools to prevent resource exhaustion

### Session Configuration
1. Create session-specific configs for specialized tasks
2. Use global config for common operations
3. Set appropriate tool priorities based on usage patterns
4. Enable audit logging for sensitive operations

### Performance Optimization
1. Set reasonable tool timeouts (default: 30s)
2. Enable caching for frequently accessed data
3. Limit concurrent tools based on device capabilities
4. Monitor tool execution metrics

## Error Handling

### Common Error Scenarios
1. **Server Connection Failure**: Falls back to cached data if available
2. **Tool Timeout**: Operation cancelled, user notified
3. **Permission Denied**: Security level prevents operation
4. **Invalid Configuration**: Reset to defaults option provided

### Error Recovery
- Configuration import validation before applying
- Automatic disable of problematic tools
- Fallback to default configuration on corruption
- Backend sync retry with exponential backoff

## Future Enhancements

### Planned Features
1. Custom server registration
2. Tool execution history viewer
3. Performance metrics dashboard
4. Advanced permission system
5. Tool chaining and workflows
6. Cloud configuration sync
7. Team-shared configurations

### API Expansions
1. Real-time server status monitoring
2. Tool execution streaming
3. Collaborative tool sessions
4. Tool marketplace integration

## Summary

The MCP integration provides a flexible, secure system for extending Claude Code's capabilities through external tools. The architecture separates global and session-specific configurations, provides comprehensive UI controls, and maintains security through multiple levels of access control. The system is designed to be extensible, allowing for future server types and tool categories while maintaining backward compatibility.