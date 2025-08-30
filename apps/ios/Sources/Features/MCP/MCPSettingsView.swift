import SwiftUI

struct MCPConfigLocal: Codable {
    var enabledServers: [String]
    var enabledTools: [String]
    var priority: [String]
    var auditLog: Bool
}

struct MCPSettingsView: View {
    @StateObject private var viewModel: MCPViewModel
    @State private var selectedTab = 0
    @State private var pulseAnimation = false
    @State private var newServer = ""
    @State private var newTool = ""
    
    init() {
        self._viewModel = StateObject(wrappedValue: MCPViewModel())
    }
    
    // Server suggestions
    private let serverSuggestions = [
        ("fs-local", "file", "Local file system access"),
        ("bash", "terminal", "Command line execution"),
        ("git", "arrow.triangle.branch", "Version control"),
        ("docker", "cube.box", "Container management"),
        ("ssh", "network", "Remote connections"),
        ("mcp-server", "server.rack", "MCP protocol server")
    ]
    
    // Tool categories
    private let toolCategories = [
        ("File Operations", ["fs.read", "fs.write", "fs.delete", "fs.mkdir"]),
        ("Search & Filter", ["grep.search", "find.files", "ag.search"]),
        ("Shell Commands", ["bash.run", "bash.interactive", "ps.list"]),
        ("Git Operations", ["git.status", "git.commit", "git.push", "git.pull"]),
        ("Docker", ["docker.ps", "docker.logs", "docker.exec"])
    ]
    
    var body: some View {
        ZStack {
            // Cyberpunk background
            backgroundView
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header with status
                    headerSection
                    
                    // Tab selector
                    tabSelector
                    
                    // Content based on selected tab
                    switch selectedTab {
                    case 0:
                        serversSection
                    case 1:
                        toolsSection
                    case 2:
                        prioritySection
                    case 3:
                        settingsSection
                    default:
                        EmptyView()
                    }
                    
                    // Save button
                    saveButton
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Image(systemName: "server.rack")
                        .font(.title3)
                        .foregroundStyle(Color(h: 180, s: 100, l: 50))
                        // .symbolEffect(.pulse, value: pulseAnimation) // iOS 17+ only
                    Text("MCP Configuration")
                        .font(.headline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.primary, Color(h: 180, s: 100, l: 50)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
        }
        .onAppear {
            startAnimations()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                // Error will be cleared when dismissed
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
        }
    }
    
    // MARK: - UI Components
    
    private var backgroundView: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            // Circuit pattern overlay
            GeometryReader { geo in
                ForEach(0..<15) { i in
                    Path { path in
                        let y = CGFloat(i) * geo.size.height / 15
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Theme.primary.opacity(0.05), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 0.5
                    )
                }
            }
            .ignoresSafeArea()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Status cards
            HStack(spacing: 12) {
                statusCard(
                    icon: "server.rack",
                    title: "Servers",
                    value: "\(viewModel.servers.filter { $0.isEnabled }.count)",
                    color: Color(h: 220, s: 100, l: 50)
                )
                
                statusCard(
                    icon: "wrench.and.screwdriver.fill",
                    title: "Tools",
                    value: "\(viewModel.tools.count)",
                    color: Color(h: 180, s: 100, l: 50)
                )
                
                statusCard(
                    icon: "checkmark.shield.fill",
                    title: "Status",
                    value: viewModel.servers.contains(where: { $0.isEnabled }) ? "ACTIVE" : "IDLE",
                    color: viewModel.servers.contains(where: { $0.isEnabled }) ? Color(h: 140, s: 100, l: 50) : Theme.mutedFg
                )
            }
            .adaptivePadding(.horizontal)
        }
    }
    
    private func statusCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Theme.card
                LinearGradient(
                    colors: [color.opacity(0.1), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(["Servers", "Tools", "Priority", "Settings"].enumerated()), id: \.0) { index, title in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                            .foregroundStyle(selectedTab == index ? Theme.primary : Theme.mutedFg)
                        
                        Rectangle()
                            .fill(
                                selectedTab == index ?
                                LinearGradient(
                                    colors: [Color(h: 280, s: 100, l: 50), Color(h: 180, s: 100, l: 50)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var serversSection: some View {
        VStack(spacing: 16) {
            addServerInput
            serverSuggestionsList
            enabledServersList
        }
    }
    
    @ViewBuilder
    private var addServerInput: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color(h: 220, s: 100, l: 50))
            
            TextField("Add server ID", text: $newServer)
                .textFieldStyle(.roundedBorder)
            
            Button(action: addNewServer) {
                Text("Add")
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color(h: 220, s: 100, l: 50), Color(h: 180, s: 100, l: 50)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal)
    }
    
    private func addNewServer() {
        if !newServer.isEmpty {
            Task {
                // Start server functionality not yet implemented
                // Would need to create a proper server object
                print("Adding server: \(newServer)")
                newServer = ""
            }
        }
    }
    
    @ViewBuilder
    private var serverSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Add")
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableServerSuggestions, id: \.0) { server, icon, desc in
                        serverSuggestionButton(server: server, icon: icon)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var availableServerSuggestions: [(String, String, String)] {
        serverSuggestions.filter { server in
            !viewModel.servers.contains { $0.name == server.0 && $0.isEnabled }
        }
    }
    
    private func serverSuggestionButton(server: String, icon: String) -> some View {
        Button {
            // Add server to configuration if not present
            if let existingServer = viewModel.servers.first(where: { $0.name == server }) {
                viewModel.toggleServer(existingServer.id)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(server)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    @ViewBuilder
    private var enabledServersList: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.servers.filter { $0.isEnabled }, id: \.name) { server in
                serverRow(server)
                    .transition(.asymmetric(
                        insertion: .slide.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal)
    }
    
    private func serverRow(_ server: MCPServer) -> some View {
        let serverInfo = serverSuggestions.first { $0.0 == server.name }
        
        return HStack(spacing: 12) {
            Image(systemName: serverInfo?.1 ?? "server.rack")
                .font(.title3)
                .foregroundStyle(Color(h: 220, s: 100, l: 50))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(server.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.foreground)
                    
                    Circle()
                        .fill(server.isEnabled ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                }
                
                if let info = serverInfo {
                    Text(info.2)
                        .font(.caption)
                        .foregroundStyle(Theme.mutedFg)
                }
            }
            
            Spacer()
            
            Button {
                Task {
                    // Stop server functionality not yet implemented
                    viewModel.toggleServer(server.id)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.destructive)
            }
        }
        .padding(12)
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var toolsSection: some View {
        VStack(spacing: 16) {
            // Add tool input
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color(h: 180, s: 100, l: 50))
                
                TextField("Add tool name", text: $newTool)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    if !newTool.isEmpty {
                        // In a real implementation, you'd add tool management
                        // For now, tools are loaded from servers
                        newTool = ""
                    }
                } label: {
                    Text("Add")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(h: 180, s: 100, l: 50), Color(h: 140, s: 100, l: 50)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal)
            
            // Tool categories
            ForEach(toolCategories, id: \.0) { category, tools in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(Theme.mutedFg)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tools.filter { toolName in
                                !viewModel.tools.contains { $0.name == toolName }
                            }, id: \.self) { tool in
                                Button {
                                    // Tool management would go here
                                } label: {
                                    Text(tool)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Theme.card)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Theme.border, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Enabled tools grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(viewModel.tools, id: \.name) { tool in
                    toolChip(tool)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func toolChip(_ tool: MCPTool) -> some View {
        HStack {
            Image(systemName: iconForTool(tool.name))
                .font(.caption)
                .foregroundStyle(Color(h: 180, s: 100, l: 50))
            
            Text(tool.name)
                .font(.caption)
                .foregroundStyle(Theme.foreground)
            
            Spacer()
            
            Button {
                // Tool removal would go here
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.destructive.opacity(0.8))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Server Priority")
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
                .padding(.horizontal)
            
            // Display servers with their status
            serverList
                .padding(.horizontal)
        }
    }
    
    private var serverList: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.servers, id: \.name) { server in
                serverRow(for: server)
            }
        }
    }
    
    private func serverRow(for server: MCPServer) -> some View {
        HStack {
            Image(systemName: serverIcon(for: server.name))
                .foregroundStyle(Theme.mutedFg)
            
            Text(server.name)
                .font(.subheadline)
                .foregroundStyle(Theme.foreground)
            
            Spacer()
            
            Text(server.isEnabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundStyle(server.isEnabled ? Color.green : Theme.mutedFg)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(12)
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func serverIcon(for name: String) -> String {
        serverSuggestions.first { $0.0 == name }?.1 ?? "server.rack"
    }
    
    private var settingsSection: some View {
        VStack(spacing: 16) {
            // Connection status
            HStack {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundStyle(viewModel.servers.contains(where: { $0.isEnabled }) ? Color(h: 140, s: 100, l: 50) : Theme.mutedFg)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("MCP Connection")
                        .font(.headline)
                        .foregroundStyle(Theme.foreground)
                    
                    Text(viewModel.servers.contains(where: { $0.isEnabled }) ? "Connected to MCP servers" : "Not connected")
                        .font(.caption)
                        .foregroundStyle(Theme.mutedFg)
                }
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.servers.contains(where: { $0.isEnabled }) ? Color(h: 140, s: 100, l: 50).opacity(0.3) : Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            // Additional settings can go here
        }
    }
    
    private var saveButton: some View {
        Button {
            Task {
                viewModel.saveConfiguration()
            }
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Save Configuration")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(h: 280, s: 100, l: 50), Color(h: 220, s: 100, l: 50)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: Color(h: 250, s: 100, l: 50).opacity(0.3),
                radius: 8,
                x: 0, y: 4
            )
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    // MARK: - Helper Functions
    
    private func iconForTool(_ tool: String) -> String {
        if tool.contains("fs") || tool.contains("file") { return "doc.fill" }
        if tool.contains("grep") || tool.contains("search") { return "magnifyingglass" }
        if tool.contains("bash") || tool.contains("run") { return "terminal" }
        if tool.contains("git") { return "arrow.triangle.branch" }
        if tool.contains("docker") { return "cube.box.fill" }
        if tool.contains("write") { return "pencil" }
        if tool.contains("read") { return "eye" }
        return "wrench.and.screwdriver"
    }
    
    private func startAnimations() {
        withAnimation(
            Animation.easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
        ) {
            pulseAnimation.toggle()
        }
    }
    
    // Configuration is now managed by the ViewModel
}

// Removed - ReorderableListEnhanced is no longer needed with ViewModel pattern