import SwiftUI
import Foundation
import os.log

struct ChatConsoleView: View {
    // MARK: - View Model Integration
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var settings = AppSettings()
    
    // MARK: - Properties
    let sessionId: String?
    let projectId: String
    
    // MARK: - Local UI State
    @State private var composing: String = ""
    @State private var glowAnimation = false
    @State private var scrollToBottom = false
    @State private var showToolDetails = false
    @State private var selectedTool: ToolExecution?
    @State private var messageAppearAnimation = false
    @State private var toolbarExpanded = false
    
    // MARK: - Environment
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) var voiceOverEnabled
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @FocusState private var isInputFocused: Bool
    
    @Namespace private var transcriptBottom
    
    // MARK: - Initialization
    init(sessionId: String? = nil, projectId: String) {
        self.sessionId = sessionId
        self.projectId = projectId
        
        // Initialize ViewModel with dependencies
        let settings = AppSettings()
        self._viewModel = StateObject(wrappedValue: ChatViewModel(
            sessionId: sessionId,
            projectId: projectId,
            // Dependencies injected via property wrappers
            modelId: "claude-3-5-haiku-20241022"
        ))
        self._settings = StateObject(wrappedValue: settings)
    }

    var body: some View {
        ZStack {
            // Cyberpunk background
            backgroundView
            
            VStack(spacing: Theme.Spacing.none) {
                headerBar
                
                // Simplified main content
                mainContentView
                
                composerBar
            }
        }
        .navigationTitle("Chat Console")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { 
            viewModel.streamingEnabled = settings.streamingDefault
            startAnimations()
            Task {
                await viewModel.monitorConnection()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil), presenting: viewModel.error) { _ in
            Button("OK", role: .cancel) { 
                Task {
                    await viewModel.clearError()
                }
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        HStack(spacing: Theme.Spacing.md) {
            chatAreaView
            toolTimelineView
        } // End of HStack (Main chat area + Tool timeline)
    } // End of mainContentView
    
    @ViewBuilder
    private var chatAreaView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(viewModel.messages) { message in
                        enhancedBubbleView(message)
                            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                            .padding(.horizontal)
                            .transition(reduceMotion ? .opacity : .asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    
                    // Typing indicator
                    if viewModel.isStreaming {
                        typingIndicatorView
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    }
                    
                    // Scroll anchor
                    Color.clear
                        .frame(height: Theme.Spacing.xxs)
                        .id(transcriptBottom)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: viewModel.messages.count)
            }
            .background(reduceTransparency ? Theme.background : Theme.background.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.primary.opacity(0.3), Theme.border],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation {
                    proxy.scrollTo(transcriptBottom, anchor: .bottom)
                }
            }
        } // End of ScrollViewReader
    }
    
    @ViewBuilder
    private var toolTimelineView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                toolTimelineHeader
                connectionStatusView
                tokenUsageView
                
                ForEach(viewModel.tools) { tool in
                    enhancedToolRowView(tool)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .slide.combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .adaptivePadding()
            .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: viewModel.tools.count)
        }
        .frame(width: horizontalSizeClass == .regular ? 320 : 280)
        .accessibilityElement(
            label: "Tool timeline",
            hint: "Shows the history of tool usage in this session"
        )
        .background(reduceTransparency ? Theme.card : Theme.card.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color(h: 180, s: 100, l: 50).opacity(0.3), Theme.border],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private var toolTimelineHeader: some View {
        HStack {
            Image(systemName: "terminal.fill")
                .foregroundStyle(Color(h: 180, s: 100, l: 50))
                // .symbolEffect(.pulse, value: glowAnimation) // iOS 17+
            Text("Tool Timeline")
                .font(.headline)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.primary, Color(h: 180, s: 100, l: 50)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Spacer()
        }
    }
    
    @ViewBuilder
    private var connectionStatusView: some View {
        if viewModel.connectionStatus != .connected {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(colorForConnectionStatus(viewModel.connectionStatus))
                    .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                Text(viewModel.connectionStatus.rawValue)
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
            }
            .adaptivePadding(.horizontal, Theme.Spacing.sm)
            .adaptivePadding(.vertical, Theme.Spacing.xs)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.xs))
            .accessibilityElement(
                label: "Connection status",
                value: viewModel.connectionStatus.rawValue
            )
        }
    }
    
    @ViewBuilder
    private var tokenUsageView: some View {
        if viewModel.totalTokens > 0 {
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: "square.stack.3d.up")
                    .font(.caption)
                Text("Tokens: \(viewModel.totalTokens)")
                    .font(.caption)
                if viewModel.totalCost > 0 {
                    Text("• $\(String(format: "%.4f", viewModel.totalCost))")
                        .font(.caption)
                }
            }
            .foregroundStyle(Theme.mutedFg)
            .adaptivePadding(.horizontal, Theme.Spacing.sm)
            .adaptivePadding(.vertical, Theme.Spacing.xs)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.xs))
            .accessibilityElement(
                label: "Token usage",
                value: "\(viewModel.totalTokens) tokens, cost $\(String(format: "%.4f", viewModel.totalCost))"
            )
        }
    }
    
    // MARK: - UI Components
    
    private var backgroundView: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            // Animated grid pattern
            GeometryReader { geo in
                ForEach(0..<20) { i in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.primary.opacity(0.05), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1)
                        .position(
                            x: CGFloat(i) * geo.size.width / 20,
                            y: geo.size.height / 2
                        )
                }
                
                ForEach(0..<10) { i in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.primary.opacity(0.05), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .position(
                            x: geo.size.width / 2,
                            y: CGFloat(i) * geo.size.height / 10
                        )
                }
            }
            .ignoresSafeArea()
        }
    }
    
    private var headerBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Session info
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "cube.transparent.fill")
                    .foregroundStyle(Color(h: 220, s: 100, l: 50))
                    // .symbolEffect(.pulse, value: viewModel.isStreaming) // iOS 17+
                
                Text("Session")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
                
                Text(viewModel.sessionId ?? "New")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.primary)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
            
            Spacer()
            
            // Model selector
            Picker("Model", selection: $viewModel.modelId) {
                Text("Claude 3.5 Haiku").tag("claude-3-5-haiku-20241022")
                Text("Claude 3.5 Sonnet").tag("claude-3-5-sonnet-20241022")
                Text("GPT-4").tag("gpt-4")
                Text("GPT-3.5 Turbo").tag("gpt-3.5-turbo")
            }
            .pickerStyle(.menu)
            .tint(Theme.primary)
            
            // Streaming toggle
            Toggle(isOn: $viewModel.streamingEnabled) {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: viewModel.streamingEnabled ? "dot.radiowaves.forward" : "text.bubble")
                    Text("Stream")
                }
                .font(.subheadline)
            }
            .toggleStyle(.switch)
            .tint(Color(h: 180, s: 100, l: 50))
            
            // Stop button
            Button { 
                Task { 
                    await viewModel.stopStreaming() 
                }
            } label: {
                Label("Stop", systemImage: "stop.circle.fill")
                    .foregroundStyle(viewModel.isStreaming ? Theme.destructive : Theme.mutedFg)
            }
            .buttonStyle(.bordered)
            .tint(Theme.destructive.opacity(viewModel.isStreaming ? 1 : 0.3))
            .disabled(!viewModel.isStreaming)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isStreaming)
        }
        .padding(.horizontal)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Theme.card.opacity(0.8)
                .overlay(
                    LinearGradient(
                        colors: [Theme.primary.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }
    
    private var composerBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
                // Enhanced input field with animation
                AnimatedTextEditor(
                    placeholder: "Type your message...",
                    text: $composing,
                    minHeight: 44,
                    maxHeight: 120
                )
                .focused($isInputFocused)
                .accessibilityElement(
                    label: "Message input",
                    hint: "Type your message and press send",
                    traits: .isSearchField
                )
                
                // Send button with enhanced styling
                Button {
                    let text = composing.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    Task { 
                        await viewModel.sendMessage(text)
                        composing = ""
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "paperplane.fill")
                            // .symbolEffect(.bounce, value: !composing.isEmpty) // iOS 17+
                        Text("Send")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
                .background(
                    LinearGradient(
                        colors: composing.isEmpty ?
                        [Theme.secondary, Theme.secondary.opacity(0.8)] :
                        [Color(h: 280, s: 100, l: 50), Color(h: 220, s: 100, l: 50)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(composing.isEmpty ? Theme.mutedFg : .white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.md))
                .disabled(viewModel.isStreaming || composing.isEmpty)
                .shadow(
                    color: composing.isEmpty ? .clear : Color(h: 250, s: 100, l: 50).opacity(0.4),
                    radius: Theme.Spacing.sm,
                    x: 0, y: Theme.Spacing.xxs
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: composing.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(
            (reduceTransparency ? Theme.card : Theme.card.opacity(0.8))
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Theme.primary.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }

    private func enhancedBubbleView(_ message: ChatMessage) -> some View {
        let isUser = message.role == .user
        let gradientColors = isUser ? 
            [Color(h: 280, s: 60, l: 30), Color(h: 250, s: 60, l: 25)] :
            [Theme.card, Theme.card.opacity(0.8)]
        
        return VStack(alignment: .leading, spacing: 6) {
            // Role indicator with icon
            HStack(spacing: 4) {
                Image(systemName: isUser ? "person.fill" : "brain")
                    .font(.caption)
                    .foregroundStyle(isUser ? Color(h: 280, s: 100, l: 60) : Theme.primary)
                
                Text(message.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
                
                Spacer()
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(Theme.mutedFg.opacity(0.6))
            }
            
            // Message content
            Text(message.content)
                .font(.body)
                .foregroundStyle(isUser ? .white : Theme.foreground)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isUser ?
                    Color(h: 280, s: 100, l: 50).opacity(0.4) :
                    Theme.border.opacity(0.3),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: isUser ? Color(h: 280, s: 100, l: 50).opacity(0.2) : .clear,
            radius: 6,
            x: 0, y: 3
        )
    }

    private func enhancedToolRowView(_ tool: ToolExecution) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Status indicator with animation
            ZStack {
                Circle()
                    .fill(color(for: tool.state).opacity(0.2))
                    .frame(width: 24, height: 24)
                
                Circle()
                    .fill(color(for: tool.state))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(color(for: tool.state), lineWidth: 2)
                            .frame(width: 20, height: 20)
                            .opacity(tool.state == .running ? 1 : 0)
                            .scaleEffect(tool.state == .running ? 1.5 : 1)
                            .animation(
                                reduceMotion ? .none : (tool.state == .running ?
                                Animation.easeOut(duration: 1).repeatForever(autoreverses: false) :
                                .default),
                                value: tool.state
                            )
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Tool header
                HStack {
                    Image(systemName: iconForTool(tool.name))
                        .font(.caption)
                        .foregroundStyle(color(for: tool.state))
                    
                    Text(tool.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.foreground)
                    
                    Spacer()
                    
                    // Metrics
                    if let ms = tool.durationMs {
                        Label("\(ms)ms", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(Theme.mutedFg)
                    }
                    
                    if let ec = tool.exitCode {
                        Label("\(ec)", systemImage: ec == 0 ? "checkmark.circle" : "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(ec == 0 ? Color.green : Theme.destructive)
                    }
                }
                
                // Input preview
                if !tool.input.isEmpty {
                    Text(formatJSON(tool.input))
                        .font(.caption)
                        .foregroundStyle(Theme.mutedFg)
                        .lineLimit(2)
                        .padding(6)
                        .background(Theme.background.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                // Output preview
                if !tool.output.isEmpty {
                    Text(tool.output)
                        .font(.caption)
                        .foregroundStyle(tool.state == .failure ? Theme.destructive : Color(h: 140, s: 60, l: 60))
                        .lineLimit(4)
                        .padding(6)
                        .background(
                            tool.state == .failure ?
                            Theme.destructive.opacity(0.1) :
                            Theme.background.opacity(0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [
                    Theme.card,
                    tool.state == .running ? color(for: tool.state).opacity(0.1) : Theme.card
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    tool.state == .running ?
                    color(for: tool.state).opacity(0.4) :
                    Theme.border.opacity(0.3),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var typingIndicatorView: some View {
        LoadingIndicator(
            style: .dots,
            color: Theme.primary,
            size: 8,
            message: "Assistant is typing..."
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(
            label: "Assistant is typing",
            traits: .updatesFrequently
        )
    }

    // MARK: - Helper Functions
    
    private func color(for status: ToolExecution.Status) -> Color {
        switch status {
        case .running: return Color(h: 45, s: 100, l: 50)   // Yellow
        case .success: return Color(h: 140, s: 100, l: 50)  // Green
        case .failure: return Theme.destructive
        }
    }
    
    private func colorForConnectionStatus(_ status: ChatViewModel.ConnectionStatus) -> Color {
        switch status {
        case .disconnected: return Color.gray
        case .connecting: return Color.yellow
        case .connected: return Color.green
        case .error: return Color.red
        }
    }
    
    private func iconForTool(_ name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("grep") || lowercased.contains("search") { return "magnifyingglass" }
        if lowercased.contains("edit") || lowercased.contains("write") { return "pencil" }
        if lowercased.contains("read") || lowercased.contains("file") { return "doc.text" }
        if lowercased.contains("bash") || lowercased.contains("command") { return "terminal" }
        if lowercased.contains("git") { return "arrow.triangle.branch" }
        return "wrench.and.screwdriver"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatAccessibilityTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatJSON(_ json: String) -> String {
        // Simple JSON formatting for display
        return json
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: ",", with: ", ")
    }
    
    private func startAnimations() {
        // Start glow animation only if reduce motion is disabled
        guard !reduceMotion else { return }
        withAnimation(
            Animation.easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
        ) {
            glowAnimation.toggle()
        }
    }
}

// MARK: - Preview
struct ChatConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        ChatConsoleView(sessionId: nil, projectId: "test")
    }
}
