import SwiftUI
import Combine

// Extension to add color and description properties to ConnectionStatus
extension ChatViewModel.ConnectionStatus {
    var color: Color {
        switch self {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
    
    var description: String {
        return self.rawValue
    }
}

// Extension to add status property to ToolExecution (mapping state to Status)
extension ToolExecution {
    var status: Status {
        return state  // state is already the Status type
    }
}

struct EnhancedChatConsoleView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var viewModel: ChatViewModel
    @State private var showErrorAlert = false
    @State private var showToolDetails = false
    @State private var selectedTool: ToolExecution?
    @State private var scrollToBottom = false
    @Namespace private var bottomAnchor
    
    // Animation states
    @State private var connectionPulse = false
    @State private var sendButtonScale: CGFloat = 1.0
    
    let sessionId: String?
    let projectId: String
    
    init(sessionId: String?, projectId: String) {
        self.sessionId = sessionId
        self.projectId = projectId
        
        // Initialize view model - dependencies are injected via property wrappers
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            sessionId: sessionId,
            projectId: projectId,
            modelId: "claude-3-5-haiku-20241022"
        ))
    }
    
    var body: some View {
        ZStack {
            // Animated background
            AnimatedBackgroundView()
            
            VStack(spacing: 0) {
                // Connection status bar
                connectionStatusBar
                
                // Main content area
                GeometryReader { geometry in
                    HStack(spacing: 12) {
                        // Chat messages area
                        chatMessagesView(in: geometry)
                        
                        // Tool execution sidebar
                        if geometry.size.width > 600 {
                            toolExecutionSidebar
                                .frame(width: 320)
                        }
                    }
                    .padding()
                }
                
                // Input area
                messageComposer
            }
        }
        .navigationTitle("Chat Console")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                toolbarButtons
            }
        }
        .alert("Error", isPresented: $showErrorAlert, presenting: viewModel.error) { _ in
            Button("OK") { viewModel.error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
        .sheet(isPresented: $showToolDetails) {
            if let tool = selectedTool {
                ToolDetailsView(tool: tool)
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: viewModel.error != nil) { hasError in
            showErrorAlert = hasError
        }
    }
    
    // MARK: - Connection Status Bar
    private var connectionStatusBar: some View {
        HStack(spacing: 12) {
            // Connection indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.connectionStatus.color)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(viewModel.connectionStatus.color, lineWidth: 2)
                            .scaleEffect(connectionPulse ? 2 : 1)
                            .opacity(connectionPulse ? 0 : 1)
                            .animation(
                                viewModel.isStreaming ?
                                Animation.easeOut(duration: 1).repeatForever(autoreverses: false) :
                                .default,
                                value: connectionPulse
                            )
                    )
                
                Text(viewModel.connectionStatus.description)
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
            }
            
            Spacer()
            
            // Session info
            if let sessionInfo = viewModel.sessionInfo {
                HStack(spacing: 12) {
                    Label("\(sessionInfo.messageCount)", systemImage: "message")
                    Label("\(sessionInfo.totalTokens)", systemImage: "cube")
                    Label(String(format: "$%.4f", sessionInfo.totalCost), systemImage: "dollarsign.circle")
                }
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
            }
            
            // Model selector
            Picker("Model", selection: $viewModel.modelId) {
                Text("Claude 3.5 Haiku").tag("claude-3-5-haiku-20241022")
                Text("Claude 3.5 Sonnet").tag("claude-3-5-sonnet-20241022")
            }
            .pickerStyle(.menu)
            .disabled(viewModel.isStreaming)
            
            // Streaming toggle
            Toggle(isOn: $viewModel.streamingEnabled) {
                Label("Stream", systemImage: viewModel.streamingEnabled ? "dot.radiowaves.forward" : "text.bubble")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .disabled(viewModel.isStreaming)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Theme.card.opacity(0.8))
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [viewModel.connectionStatus.color.opacity(0.3), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2),
            alignment: .bottom
        )
    }
    
    // MARK: - Chat Messages View
    private func chatMessagesView(in geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            maxWidth: geometry.size.width * 0.7
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    
                    // Typing indicator
                    if viewModel.isStreaming && viewModel.messages.last?.role != .assistant {
                        TypingIndicatorView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Scroll anchor
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchor)
                }
                .padding()
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.messages.count)
            }
            .background(Theme.background.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.border.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Tool Execution Sidebar
    private var toolExecutionSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.title3)
                    .foregroundStyle(Color(h: 180, s: 100, l: 50))
                
                Text("Tool Executions")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.tools.count)")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.card)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Tool list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.tools) { tool in
                        ToolExecutionRow(tool: tool) {
                            selectedTool = tool
                            showToolDetails = true
                        }
                        .transition(.asymmetric(
                            insertion: .slide.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.tools.count)
            }
            
            // Status line
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .background(Theme.card.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Message Composer
    private var messageComposer: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 12) {
                // Input field
                MessageInputField(text: $viewModel.inputText)
                    .disabled(viewModel.isStreaming)
                
                // Action buttons
                VStack(spacing: 8) {
                    // Send button
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            sendButtonScale = 0.9
                        }
                        Task {
                            await viewModel.sendMessage(viewModel.inputText)
                            viewModel.inputText = ""
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                sendButtonScale = 1.0
                            }
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    colors: viewModel.inputText.isEmpty ?
                                    [Theme.secondary, Theme.secondary.opacity(0.8)] :
                                    [Color(h: 280, s: 100, l: 50), Color(h: 220, s: 100, l: 50)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .scaleEffect(sendButtonScale)
                    }
                    .disabled(viewModel.inputText.isEmpty || viewModel.isStreaming)
                    
                    // Stop button (visible when streaming)
                    if viewModel.isStreaming {
                        Button {
                            Task { await viewModel.stopStreaming() }
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Theme.destructive)
                                .clipShape(Circle())
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding()
            .background(Theme.card.opacity(0.8))
        }
    }
    
    // MARK: - Toolbar Buttons
    private var toolbarButtons: some View {
        HStack(spacing: 12) {
            // Clear messages
            Button {
                withAnimation {
                    viewModel.messages.removeAll()
                    viewModel.tools.removeAll()
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Theme.destructive)
            }
            .disabled(viewModel.messages.isEmpty || viewModel.isStreaming)
            
            // Retry last message
            Button {
                Task { await viewModel.retryLastMessage() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(Theme.primary)
            }
            .disabled(viewModel.messages.isEmpty || viewModel.isStreaming)
        }
    }
    
    // MARK: - Helper Methods
    private func startAnimations() {
        withAnimation(
            Animation.easeInOut(duration: 1.5)
                .repeatForever(autoreverses: false)
        ) {
            connectionPulse = true
        }
    }
}

// MARK: - Supporting Views

struct MessageBubbleView: View {
    let message: ChatMessage
    let maxWidth: CGFloat
    
    private var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Role and timestamp
                HStack(spacing: 4) {
                    Image(systemName: isUser ? "person.fill" : "brain")
                        .font(.caption)
                        .foregroundStyle(isUser ? Color(h: 280, s: 100, l: 60) : Theme.primary)
                    
                    Text(message.role.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(Theme.mutedFg)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(Theme.mutedFg.opacity(0.5))
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(Theme.mutedFg.opacity(0.5))
                }
                
                // Message content
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : Theme.foreground)
                    .textSelection(.enabled)
                    .opacity(message.isStreaming ? 0.8 : 1.0)
                
                // Streaming indicator
                if message.isStreaming {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Theme.primary)
                                .frame(width: 4, height: 4)
                                .opacity(0.6)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(i) * 0.2),
                                    value: message.isStreaming
                                )
                        }
                    }
                }
            }
            .padding(12)
            .background(
                isUser ?
                AnyView(
                    LinearGradient(
                        colors: [Color(h: 280, s: 60, l: 30), Color(h: 250, s: 60, l: 25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ) :
                AnyView(Theme.card.opacity(0.8))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: maxWidth, alignment: isUser ? .trailing : .leading)
            
            if !isUser { Spacer() }
        }
    }
}

struct ToolExecutionRow: View {
    let tool: ToolExecution
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Status indicator
                StatusIndicator(status: tool.status)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Tool name
                    Text(tool.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.foreground)
                    
                    // Metrics
                    HStack(spacing: 8) {
                        if let duration = tool.durationMs {
                            Label("\(duration)ms", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(Theme.mutedFg)
                        }
                        
                        if let exitCode = tool.exitCode {
                            Label("\(exitCode)", systemImage: exitCode == 0 ? "checkmark.circle" : "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(exitCode == 0 ? .green : Theme.destructive)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
            }
            .padding(10)
            .background(Theme.card.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct StatusIndicator: View {
    let status: ToolExecution.Status
    
    private var color: Color {
        switch status {
        case .running: return .orange
        case .success: return .green
        case .failure: return Theme.destructive
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 24, height: 24)
            
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            if status == .running {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .scaleEffect(1.5)
                    .opacity(0)
                    .animation(
                        Animation.easeOut(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: status
                    )
            }
        }
    }
}

struct MessageInputField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Type a message...")
                    .foregroundStyle(Theme.mutedFg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.clear)
        }
        .frame(minHeight: 44, maxHeight: 120)
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ?
                    LinearGradient(
                        colors: [Theme.primary.opacity(0.6), Color(h: 280, s: 100, l: 50).opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(colors: [Theme.border], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TypingIndicatorView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.card.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { animating = true }
    }
}

struct AnimatedBackgroundView: View {
    @State private var gradientOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color(h: 280, s: 100, l: 50, a: 0.1),
                    Color(h: 220, s: 100, l: 50, a: 0.1),
                    Color(h: 180, s: 100, l: 50, a: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .offset(x: gradientOffset)
            .animation(
                Animation.linear(duration: 10)
                    .repeatForever(autoreverses: true),
                value: gradientOffset
            )
            .onAppear {
                gradientOffset = 100
            }
        }
    }
}

struct ToolDetailsView: View {
    let tool: ToolExecution
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Status
                    HStack {
                        StatusIndicator(status: tool.status)
                        Text(tool.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding()
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Metrics
                    if tool.durationMs != nil || tool.exitCode != nil {
                        HStack(spacing: 20) {
                            if let duration = tool.durationMs {
                                VStack {
                                    Text("Duration")
                                        .font(.caption)
                                        .foregroundStyle(Theme.mutedFg)
                                    Text("\(duration)ms")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                            }
                            
                            if let exitCode = tool.exitCode {
                                VStack {
                                    Text("Exit Code")
                                        .font(.caption)
                                        .foregroundStyle(Theme.mutedFg)
                                    Text("\(exitCode)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(exitCode == 0 ? .green : Theme.destructive)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Input")
                            .font(.headline)
                        Text(tool.input)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.mutedFg)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Output
                    if !tool.output.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Output")
                                .font(.headline)
                            ScrollView(.horizontal) {
                                Text(tool.output)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(tool.state == .failure ? Theme.destructive : Theme.foreground)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Tool Execution Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}