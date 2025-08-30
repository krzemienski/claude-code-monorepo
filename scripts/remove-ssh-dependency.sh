#!/bin/bash

# SSH Dependency Removal Script for Claude Code iOS
# Fixes critical blocker: Shout library (0.6.5) incompatible with iOS platform
# This script removes SSH functionality and provides alternative solutions

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

PROJECT_ROOT="$(dirname "$(dirname "$0")")"
IOS_DIR="$PROJECT_ROOT/apps/ios"
BACKUP_DIR="$PROJECT_ROOT/backups/ssh-removal-$(date +%Y%m%d-%H%M%S)"

echo -e "${BLUE}🔧 SSH Dependency Removal Script${NC}"
echo "======================================"
echo "Removing incompatible SSH dependency and providing alternatives"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo -e "${BLUE}📦 Creating backup at: $BACKUP_DIR${NC}"

# Function to backup file
backup_file() {
    local file=$1
    local relative_path=${file#$PROJECT_ROOT/}
    local backup_path="$BACKUP_DIR/$relative_path"
    mkdir -p "$(dirname "$backup_path")"
    cp "$file" "$backup_path"
    echo "  Backed up: $relative_path"
}

echo -e "\n${YELLOW}🔍 Phase 1: Analyzing SSH Dependencies...${NC}"

# Find all SSH-related files
SSH_FILES=()
if [ -d "$IOS_DIR/Sources/App/SSH" ]; then
    while IFS= read -r -d '' file; do
        SSH_FILES+=("$file")
    done < <(find "$IOS_DIR/Sources/App/SSH" -type f -print0)
fi

# Find Package.swift references
PACKAGE_FILES=()
for file in "$IOS_DIR/Package.swift" "$IOS_DIR/Package.resolved" "$IOS_DIR/.package.resolved"; do
    if [ -f "$file" ] && grep -q "Shout" "$file" 2>/dev/null; then
        PACKAGE_FILES+=("$file")
    fi
done

# Find Project configuration references
PROJECT_FILES=()
for file in "$IOS_DIR/Project.swift" "$IOS_DIR/Project.yml" "$IOS_DIR/Tuist.swift"; do
    if [ -f "$file" ] && grep -q "Shout" "$file" 2>/dev/null; then
        PROJECT_FILES+=("$file")
    fi
done

echo "Found ${#SSH_FILES[@]} SSH implementation files"
echo "Found ${#PACKAGE_FILES[@]} package files with SSH references"
echo "Found ${#PROJECT_FILES[@]} project config files with SSH references"

echo -e "\n${YELLOW}🔧 Phase 2: Removing SSH Dependencies...${NC}"

# Remove SSH source files
if [ ${#SSH_FILES[@]} -gt 0 ]; then
    echo "Removing SSH implementation files..."
    for file in "${SSH_FILES[@]}"; do
        backup_file "$file"
        rm "$file"
        echo -e "${GREEN}✅ Removed: ${file#$PROJECT_ROOT/}${NC}"
    done
    
    # Remove empty SSH directory if it exists
    if [ -d "$IOS_DIR/Sources/App/SSH" ]; then
        rmdir "$IOS_DIR/Sources/App/SSH" 2>/dev/null || true
    fi
fi

# Remove from Package.swift
if [ -f "$IOS_DIR/Package.swift" ]; then
    backup_file "$IOS_DIR/Package.swift"
    
    # Remove Shout dependency
    sed -i '' '/.*url.*Shout.*requirement.*/d' "$IOS_DIR/Package.swift"
    sed -i '' '/.package.*Shout/d' "$IOS_DIR/Package.swift"
    sed -i '' '/"Shout"/d' "$IOS_DIR/Package.swift"
    
    echo -e "${GREEN}✅ Cleaned Package.swift${NC}"
fi

# Remove from Project.swift (Tuist)
if [ -f "$IOS_DIR/Project.swift" ]; then
    backup_file "$IOS_DIR/Project.swift"
    
    # Remove Shout from packages and dependencies
    sed -i '' '/.*url.*Shout.*requirement.*/d' "$IOS_DIR/Project.swift"
    sed -i '' '/.remote.*Shout/d' "$IOS_DIR/Project.swift"
    sed -i '' '/.package.*Shout/d' "$IOS_DIR/Project.swift"
    
    echo -e "${GREEN}✅ Cleaned Project.swift${NC}"
fi

# Remove from Tuist.swift
if [ -f "$IOS_DIR/Tuist.swift" ]; then
    backup_file "$IOS_DIR/Tuist.swift"
    
    # Remove Shout references
    sed -i '' '/Shout/d' "$IOS_DIR/Tuist.swift"
    
    echo -e "${GREEN}✅ Cleaned Tuist.swift${NC}"
fi

# Clean Package.resolved
for resolved_file in "$IOS_DIR/Package.resolved" "$IOS_DIR/.package.resolved"; do
    if [ -f "$resolved_file" ]; then
        backup_file "$resolved_file"
        
        # Remove Shout package entry (multi-line removal)
        awk '
        /Shout/ { in_shout=1; next }
        in_shout && /}/ { in_shout=0; next }
        !in_shout
        ' "$resolved_file" > "$resolved_file.tmp"
        mv "$resolved_file.tmp" "$resolved_file"
        
        echo -e "${GREEN}✅ Cleaned $(basename "$resolved_file")${NC}"
    fi
done

echo -e "\n${YELLOW}🔧 Phase 3: Creating Alternative Implementation...${NC}"

# Create alternative SSH manager using URLSession for remote commands
cat > "$IOS_DIR/Sources/App/Core/RemoteCommand/RemoteCommandManager.swift" << 'EOF'
//
//  RemoteCommandManager.swift
//  ClaudeCode
//
//  Alternative to SSH for executing remote commands via API
//

import Foundation
import Combine

/// Manager for executing remote commands through API endpoints instead of SSH
@MainActor
final class RemoteCommandManager: ObservableObject {
    
    // MARK: - Types
    
    enum RemoteCommandError: LocalizedError {
        case invalidURL
        case connectionFailed
        case authenticationRequired
        case commandFailed(String)
        case unsupportedOperation
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid remote endpoint URL"
            case .connectionFailed:
                return "Failed to connect to remote server"
            case .authenticationRequired:
                return "Authentication required for remote command"
            case .commandFailed(let message):
                return "Command failed: \(message)"
            case .unsupportedOperation:
                return "This operation requires server-side API support"
            }
        }
    }
    
    struct RemoteCommand {
        let command: String
        let arguments: [String]
        let workingDirectory: String?
        let environment: [String: String]?
        let timeout: TimeInterval
        
        init(
            command: String,
            arguments: [String] = [],
            workingDirectory: String? = nil,
            environment: [String: String]? = nil,
            timeout: TimeInterval = 30
        ) {
            self.command = command
            self.arguments = arguments
            self.workingDirectory = workingDirectory
            self.environment = environment
            self.timeout = timeout
        }
    }
    
    struct CommandResult {
        let output: String
        let error: String?
        let exitCode: Int
        let executionTime: TimeInterval
    }
    
    // MARK: - Properties
    
    @Published private(set) var isExecuting = false
    @Published private(set) var lastResult: CommandResult?
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    private let apiClient: APIClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// Execute a command on the remote server via API
    func executeCommand(_ command: RemoteCommand) async throws -> CommandResult {
        guard !isExecuting else {
            throw RemoteCommandError.unsupportedOperation
        }
        
        isExecuting = true
        defer { isExecuting = false }
        
        // Create API request for remote command execution
        let request = RemoteCommandRequest(
            command: command.command,
            arguments: command.arguments,
            workingDirectory: command.workingDirectory,
            environment: command.environment,
            timeout: command.timeout
        )
        
        // Send to backend API endpoint
        let startTime = Date()
        
        do {
            // This would call the backend API endpoint for remote execution
            // The backend would handle the actual command execution
            let response = try await apiClient.post(
                "/api/remote/execute",
                body: request
            )
            
            let executionTime = Date().timeIntervalSince(startTime)
            
            let result = CommandResult(
                output: response.output ?? "",
                error: response.error,
                exitCode: response.exitCode ?? 0,
                executionTime: executionTime
            )
            
            lastResult = result
            return result
            
        } catch {
            connectionStatus = .error(error.localizedDescription)
            throw RemoteCommandError.commandFailed(error.localizedDescription)
        }
    }
    
    /// Test connection to remote server
    func testConnection() async -> Bool {
        connectionStatus = .connecting
        
        do {
            // Ping the backend API
            _ = try await apiClient.get("/api/health")
            connectionStatus = .connected
            return true
        } catch {
            connectionStatus = .error(error.localizedDescription)
            return false
        }
    }
    
    /// Alternative: Use Process for local commands (iOS simulator only)
    #if targetEnvironment(simulator)
    func executeLocalCommand(_ command: String) async throws -> String {
        // Only available in simulator for development
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    #endif
}

// MARK: - API Models

private struct RemoteCommandRequest: Codable {
    let command: String
    let arguments: [String]
    let workingDirectory: String?
    let environment: [String: String]?
    let timeout: TimeInterval
}

private struct RemoteCommandResponse: Codable {
    let output: String?
    let error: String?
    let exitCode: Int?
}

// MARK: - SwiftUI View for Remote Commands

import SwiftUI

struct RemoteCommandView: View {
    @StateObject private var manager = RemoteCommandManager()
    @State private var commandText = ""
    @State private var outputText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "terminal")
                    .font(.title2)
                Text("Remote Commands")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                
                // Connection status
                HStack(spacing: 4) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 8, height: 8)
                    Text(connectionText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            // Command input
            VStack(alignment: .leading, spacing: 8) {
                Text("Command")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("Enter command...", text: $commandText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: executeCommand) {
                        Label("Run", systemImage: "play.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manager.isExecuting || commandText.isEmpty)
                }
            }
            .padding(.horizontal)
            
            // Output
            VStack(alignment: .leading, spacing: 8) {
                Text("Output")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    Text(outputText.isEmpty ? "No output yet..." : outputText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await checkConnection()
        }
    }
    
    private var connectionColor: Color {
        switch manager.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
    
    private var connectionText: String {
        switch manager.connectionStatus {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .error: return "Error"
        }
    }
    
    private func checkConnection() async {
        _ = await manager.testConnection()
    }
    
    private func executeCommand() {
        Task {
            do {
                let command = RemoteCommandManager.RemoteCommand(
                    command: commandText,
                    timeout: 30
                )
                
                let result = try await manager.executeCommand(command)
                outputText = result.output
                
                if let error = result.error, !error.isEmpty {
                    outputText += "\n\nError: \(error)"
                }
                
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct RemoteCommandView_Previews: PreviewProvider {
    static var previews: some View {
        RemoteCommandView()
    }
}
EOF

echo -e "${GREEN}✅ Created RemoteCommandManager.swift${NC}"

# Update any SSH client references to use RemoteCommandManager
echo -e "\n${YELLOW}🔧 Phase 4: Updating References...${NC}"

# Find files that import or reference SSH functionality
REFERENCING_FILES=$(grep -r "SSHClient\|import Shout" "$IOS_DIR/Sources" 2>/dev/null | cut -d: -f1 | sort -u || true)

if [ -n "$REFERENCING_FILES" ]; then
    echo "Found references in:"
    while IFS= read -r file; do
        echo "  - ${file#$PROJECT_ROOT/}"
        backup_file "$file"
        
        # Replace SSHClient with RemoteCommandManager
        sed -i '' 's/SSHClient/RemoteCommandManager/g' "$file"
        sed -i '' 's/import Shout/\/\/ SSH removed - using RemoteCommandManager/g' "$file"
        
        echo -e "${GREEN}✅ Updated: $(basename "$file")${NC}"
    done <<< "$REFERENCING_FILES"
fi

echo -e "\n${YELLOW}🔧 Phase 5: Cleaning Build Artifacts...${NC}"

cd "$IOS_DIR"

# Clean derived data
if [ -d "Derived" ]; then
    rm -rf Derived
    echo "  Cleaned Derived folder"
fi

# Clean .build directory
if [ -d ".build" ]; then
    rm -rf .build
    echo "  Cleaned .build folder"
fi

# Reset package cache
if command -v swift &> /dev/null; then
    swift package reset 2>/dev/null || true
    echo "  Reset Swift package cache"
fi

echo -e "\n${YELLOW}🔧 Phase 6: Regenerating Project...${NC}"

# Regenerate with Tuist if available
if command -v tuist &> /dev/null; then
    echo "  Regenerating project with Tuist..."
    tuist clean
    tuist fetch
    tuist generate
    echo -e "${GREEN}✅ Project regenerated with Tuist${NC}"
elif [ -f "Project.yml" ] && command -v xcodegen &> /dev/null; then
    echo "  Regenerating project with XcodeGen..."
    xcodegen generate
    echo -e "${GREEN}✅ Project regenerated with XcodeGen${NC}"
else
    echo -e "${YELLOW}⚠️  Manual project regeneration required${NC}"
fi

echo -e "\n${YELLOW}📋 Phase 7: Verification...${NC}"

VERIFICATION_PASSED=true

# Check for any remaining Shout references
echo -n "Checking for SSH/Shout references... "
if grep -r "Shout\|SSHClient" "$IOS_DIR" --exclude-dir=".build" --exclude-dir="Derived" --exclude="*.backup" 2>/dev/null | grep -v "RemoteCommandManager"; then
    echo -e "${RED}❌ Found remaining references${NC}"
    VERIFICATION_PASSED=false
else
    echo -e "${GREEN}✅ No SSH references found${NC}"
fi

# Verify new implementation exists
echo -n "Checking alternative implementation... "
if [ -f "$IOS_DIR/Sources/App/Core/RemoteCommand/RemoteCommandManager.swift" ]; then
    echo -e "${GREEN}✅ RemoteCommandManager created${NC}"
else
    echo -e "${RED}❌ Alternative implementation missing${NC}"
    VERIFICATION_PASSED=false
fi

echo -e "\n${BLUE}📊 Summary:${NC}"
echo "- Removed ${#SSH_FILES[@]} SSH implementation files"
echo "- Cleaned ${#PACKAGE_FILES[@]} package configuration files"
echo "- Updated ${#PROJECT_FILES[@]} project configuration files"
echo "- Created alternative RemoteCommandManager implementation"
echo "- Backup created at: $BACKUP_DIR"

if [ "$VERIFICATION_PASSED" = true ]; then
    echo -e "\n${GREEN}✅ SSH dependency removal complete!${NC}"
    echo ""
    echo "${MAGENTA}Alternative Solution Implemented:${NC}"
    echo "- RemoteCommandManager: API-based remote command execution"
    echo "- Uses backend API endpoints instead of direct SSH"
    echo "- Compatible with iOS security restrictions"
    echo "- Maintains similar functionality through REST API"
    echo ""
    echo "Next steps:"
    echo "1. Implement corresponding backend API endpoints"
    echo "2. Update authentication for remote commands"
    echo "3. Test remote command functionality"
    echo "4. Clean build folder in Xcode (Cmd+Shift+K)"
    echo "5. Build and run the project"
    exit 0
else
    echo -e "\n${RED}⚠️  SSH dependency removal incomplete${NC}"
    echo "Please review remaining issues and fix manually"
    exit 1
fi