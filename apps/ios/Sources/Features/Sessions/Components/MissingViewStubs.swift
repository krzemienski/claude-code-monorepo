import SwiftUI
import PhotosUI

// MARK: - ChatView
/// Main chat interface view with real-time messaging
public struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var scrollToBottom = true
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(sessionId: String? = nil, projectId: String = "default") {
        _viewModel = StateObject(wrappedValue: ChatViewModel(sessionId: sessionId, projectId: projectId))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            // Messages area
            VirtualizedChatMessageList(
                messages: viewModel.messages,
                scrollToBottom: $scrollToBottom,
                onToolTapped: { tool in
                    // Handle tool interaction
                    Task {
                        await viewModel.sendMessage("/tool \(tool.name)")
                    }
                }
            )
            
            // Message composer
            MessageComposer(
                inputText: $viewModel.inputText,
                isStreaming: $viewModel.isStreaming,
                onSend: {
                    Task {
                        await viewModel.sendMessage(viewModel.inputText)
                        viewModel.inputText = ""
                        scrollToBottom = true
                    }
                },
                onStop: {
                    Task {
                        await viewModel.stopStreaming()
                    }
                },
                onAttachment: nil
            )
        }
        .background(Theme.background)
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.monitorConnection()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                Task { await viewModel.clearError() }
            }
            if viewModel.connectionStatus == .error {
                Button("Retry") {
                    Task { await viewModel.retryLastMessage() }
                }
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Label(viewModel.modelId.replacingOccurrences(of: "-", with: " ").capitalized, systemImage: "cpu")
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.neonCyan)
                
                Text(viewModel.connectionStatus.rawValue)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                    .foregroundStyle(connectionStatusColor)
            }
            
            Spacer()
            
            if viewModel.isStreaming {
                HStack(spacing: Theme.Spacing.xs) {
                    Text("Streaming")
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                        .foregroundStyle(Theme.mutedFg)
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Token count
            if viewModel.totalTokens > 0 {
                Text("\(viewModel.totalTokens) tokens")
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.mutedFg)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.card)
    }
    
    private var connectionStatusColor: Color {
        switch viewModel.connectionStatus {
        case .connected: return Theme.success
        case .connecting: return Theme.warning
        case .disconnected: return Theme.mutedFg
        case .error: return Theme.error
        }
    }
}

// MARK: - ProfileView
/// User profile and settings view with editing capabilities
public struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingImagePicker = false
    @State private var showingDeleteAlert = false
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.dismiss) var dismiss
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Profile header with avatar
                profileHeader
                
                // Account settings
                accountSection
                
                // API configuration
                apiSection
                
                // Preferences
                preferencesSection
                
                // Save button
                if viewModel.hasUnsavedChanges {
                    saveButton
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if viewModel.hasUnsavedChanges {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await viewModel.saveProfile() }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .photosPicker(
            isPresented: $viewModel.showingImagePicker,
            selection: $viewModel.selectedPhoto,
            matching: .images
        )
        .alert("Delete Avatar", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteAvatar() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete your avatar?")
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Avatar with edit options
            ZStack(alignment: .bottomTrailing) {
                if let avatarData = viewModel.avatarData,
                   let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Theme.primary, lineWidth: 2)
                        )
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.primary, Theme.neonCyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text(viewModel.username.prefix(2).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                
                // Edit button
                Menu {
                    Button {
                        viewModel.showingImagePicker = true
                    } label: {
                        Label("Choose Photo", systemImage: "photo")
                    }
                    
                    if viewModel.avatarData != nil {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete Photo", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Theme.primary)
                        .clipShape(Circle())
                }
            }
            
            Text(viewModel.displayName.isEmpty ? viewModel.username : viewModel.displayName)
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xl, for: dynamicTypeSize)))
                .fontWeight(.semibold)
                .foregroundStyle(Theme.foreground)
            
            Text(viewModel.email)
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                .foregroundStyle(Theme.mutedFg)
            
            if !viewModel.bio.isEmpty {
                Text(viewModel.bio)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.lg)
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Account")
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.lg, for: dynamicTypeSize)))
                .fontWeight(.semibold)
                .foregroundStyle(Theme.foreground)
            
            ReactiveFormField(
                title: "Username",
                text: $viewModel.username,
                rules: []
            )
            
            ReactiveFormField(
                title: "Display Name",
                text: $viewModel.displayName,
                placeholder: "Optional display name",
                rules: []
            )
            
            ReactiveFormField(
                title: "Email",
                text: $viewModel.email,
                rules: []
            )
            
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Bio")
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.mutedFg)
                
                TextEditor(text: $viewModel.bio)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.foreground)
                    .frame(minHeight: 80)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.backgroundSecondary)
                    .cornerRadius(Theme.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            }
        }
    }
    
    private var apiSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("API Configuration")
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.lg, for: dynamicTypeSize)))
                .fontWeight(.semibold)
                .foregroundStyle(Theme.foreground)
            
            ReactiveFormField(
                title: "API Key",
                text: $viewModel.apiKey,
                isSecure: true
            )
            
            HStack {
                Button {
                    Task { await viewModel.testAPIConnection() }
                } label: {
                    Label("Test Connection", systemImage: "network")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
                .disabled(viewModel.apiKey.isEmpty || viewModel.isLoading)
                
                if viewModel.connectionStatus != "Not Connected" {
                    Text(viewModel.connectionStatus)
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                        .foregroundStyle(
                            viewModel.connectionStatus.contains("✅") ? Theme.success :
                            viewModel.connectionStatus.contains("❌") ? Theme.error :
                            Theme.warning
                        )
                }
            }
        }
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Preferences")
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.lg, for: dynamicTypeSize)))
                .fontWeight(.semibold)
                .foregroundStyle(Theme.foreground)
            
            ReactiveToggle(
                title: "Enable Streaming",
                isOn: $viewModel.enableStreaming
            )
            
            ReactiveToggle(
                title: "Dark Mode",
                isOn: $viewModel.darkModeEnabled
            )
            
            ReactiveToggle(
                title: "Reduce Motion",
                isOn: $viewModel.reduceMotion
            )
            
            ReactiveToggle(
                title: "Notifications",
                isOn: $viewModel.notificationsEnabled
            )
            
            ReactiveToggle(
                title: "Sound Effects",
                isOn: $viewModel.soundEnabled
            )
        }
    }
    
    private var saveButton: some View {
        Button {
            Task { await viewModel.saveProfile() }
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Text(viewModel.isSaving ? "Saving..." : "Save Changes")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.primary)
        .disabled(viewModel.isSaving)
    }
}

// MARK: - ToolsView
/// MCP tools and integrations view
public struct ToolsView: View {
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    
    private let categories = ["All", "File", "Git", "System", "Network", "Custom"]
    private let tools = [
        Tool(name: "Read File", category: "File", icon: "doc.text"),
        Tool(name: "Write File", category: "File", icon: "square.and.pencil"),
        Tool(name: "Git Status", category: "Git", icon: "arrow.triangle.branch"),
        Tool(name: "Bash Command", category: "System", icon: "terminal"),
        Tool(name: "HTTP Request", category: "Network", icon: "network")
    ]
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search and filter
            toolsHeader
            
            // Tools grid
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.md)
                    ],
                    spacing: Theme.Spacing.md
                ) {
                    ForEach(filteredTools) { tool in
                        ToolCard(tool: tool)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .background(Theme.background)
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var toolsHeader: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.mutedFg)
                
                TextField("Search tools...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.foreground)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.card)
            .cornerRadius(Theme.CornerRadius.md)
            
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(categories, id: \.self) { category in
                        CategoryChip(
                            title: category,
                            isSelected: selectedCategory == category,
                            action: { selectedCategory = category }
                        )
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.backgroundSecondary)
    }
    
    private var filteredTools: [Tool] {
        tools.filter { tool in
            (selectedCategory == "All" || tool.category == selectedCategory) &&
            (searchText.isEmpty || tool.name.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    // Helper types
    private struct Tool: Identifiable {
        let id = UUID()
        let name: String
        let category: String
        let icon: String
    }
    
    private struct ToolCard: View {
        let tool: Tool
        @Environment(\.dynamicTypeSize) var dynamicTypeSize
        
        var body: some View {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: tool.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.neonCyan)
                
                Text(tool.name)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)
                
                Text(tool.category)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.mutedFg)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.md)
            .background(Theme.card)
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Theme.border.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private struct CategoryChip: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 14))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .white : Theme.foreground)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(isSelected ? Theme.primary : Theme.card)
                    .cornerRadius(Theme.CornerRadius.full)
            }
        }
    }
}

// MARK: - Additional Missing Views

public struct MCPServerConfigView: View {
    @State private var serverURL = ""
    @State private var serverName = ""
    
    public init() {}
    
    public var body: some View {
        Form {
            Section("Server Configuration") {
                TextField("Server Name", text: $serverName)
                TextField("Server URL", text: $serverURL)
            }
        }
        .navigationTitle("MCP Server")
    }
}

public struct ModelSelectionView: View {
    @State private var selectedModel = "claude-3-5-haiku-20241022"
    
    public init() {}
    
    public var body: some View {
        List {
            ForEach(["claude-3-5-haiku-20241022", "claude-3-5-sonnet-20241022", "gpt-4"], id: \.self) { model in
                HStack {
                    Text(model)
                    Spacer()
                    if selectedModel == model {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Theme.primary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedModel = model
                }
            }
        }
        .navigationTitle("Select Model")
    }
}

public struct ImportExportView: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Button("Import Settings") {
                // Import logic
            }
            .buttonStyle(.borderedProminent)
            
            Button("Export Settings") {
                // Export logic
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Import/Export")
    }
}

public struct ThemeSelectionView: View {
    @State private var selectedTheme = "Cyberpunk"
    
    public init() {}
    
    public var body: some View {
        List {
            ForEach(["Cyberpunk", "Dark", "Light", "Auto"], id: \.self) { theme in
                HStack {
                    Circle()
                        .fill(themeColor(for: theme))
                        .frame(width: 30, height: 30)
                    
                    Text(theme)
                    
                    Spacer()
                    
                    if selectedTheme == theme {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Theme.primary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTheme = theme
                }
            }
        }
        .navigationTitle("Theme")
    }
    
    private func themeColor(for theme: String) -> Color {
        switch theme {
        case "Cyberpunk": return Theme.neonCyan
        case "Dark": return .gray
        case "Light": return .white
        default: return .blue
        }
    }
}

public struct AdvancedSettingsView: View {
    @State private var enableDebugMode = false
    @State private var enablePerformanceOverlay = false
    @State private var cacheSize = "100 MB"
    
    public init() {}
    
    public var body: some View {
        Form {
            Section("Developer") {
                Toggle("Debug Mode", isOn: $enableDebugMode)
                Toggle("Performance Overlay", isOn: $enablePerformanceOverlay)
            }
            
            Section("Cache") {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(cacheSize)
                        .foregroundStyle(Theme.mutedFg)
                }
                
                Button("Clear Cache") {
                    // Clear cache logic
                }
                .foregroundStyle(Theme.destructive)
            }
        }
        .navigationTitle("Advanced")
    }
}