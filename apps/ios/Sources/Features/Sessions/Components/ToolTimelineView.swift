import SwiftUI

/// Tool timeline view component for displaying tool execution history
/// Shows connection status, token usage, and tool execution details
struct ToolTimelineView: View {
    let tools: [ToolExecution]
    let connectionStatus: ChatViewModel.ConnectionStatus
    let totalTokens: Int
    let totalCost: Double
    let isExpanded: Bool
    
    // MARK: - State
    @State private var selectedTool: ToolExecution?
    @State private var showToolDetails = false
    @State private var glowAnimation = false
    
    // MARK: - Environment
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    
    // MARK: - Computed Properties
    private var timelineWidth: CGFloat {
        horizontalSizeClass == .regular ? 320 : 280
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header
            timelineHeader
            
            // Connection status
            if connectionStatus != .connected {
                connectionStatusView
            }
            
            // Token usage
            if totalTokens > 0 {
                tokenUsageView
            }
            
            // Tool list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(tools) { tool in
                        ToolExecutionRowComponent(
                            tool: tool,
                            onTap: {
                                selectedTool = tool
                                showToolDetails = true
                            }
                        )
                        .transition(toolTransition)
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .animation(listAnimation, value: tools.count)
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(width: timelineWidth)
        .background(backgroundView)
        .overlay(borderOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showToolDetails) {
            if let tool = selectedTool {
                ToolDetailsSheet(tool: tool)
            }
        }
        .onAppear {
            startAnimations()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tool timeline")
        .accessibilityHint("Shows the history of tool usage in this session")
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var timelineHeader: some View {
        HStack {
            Image(systemName: "terminal.fill")
                .foregroundStyle(Color(h: 180, s: 100, l: 50))
                .scaleEffect(glowAnimation ? 1.1 : 1.0)
                .animation(glowingAnimation, value: glowAnimation)
            
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
            
            if !tools.isEmpty {
                Text("\(tools.count)")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(Theme.card)
                    .clipShape(Capsule())
            }
        }
    }
    
    @ViewBuilder
    private var connectionStatusView: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(colorForConnectionStatus(connectionStatus))
                .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                .overlay(pulsingCircle)
            
            Text(connectionStatus.rawValue)
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.xs))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection status: \(connectionStatus.rawValue)")
    }
    
    @ViewBuilder
    private var tokenUsageView: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "square.stack.3d.up")
                .font(.caption)
            
            Text("Tokens: \(totalTokens)")
                .font(.caption)
            
            if totalCost > 0 {
                Text("• $\(String(format: "%.4f", totalCost))")
                    .font(.caption)
            }
        }
        .foregroundStyle(Theme.mutedFg)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.xs))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Token usage: \(totalTokens) tokens, cost $\(String(format: "%.4f", totalCost))")
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if reduceTransparency {
            Theme.card
        } else {
            Theme.card.opacity(0.3)
        }
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                LinearGradient(
                    colors: [Color(h: 180, s: 100, l: 50).opacity(0.3), Theme.border],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    @ViewBuilder
    private var pulsingCircle: some View {
        if connectionStatus == .connecting {
            Circle()
                .stroke(colorForConnectionStatus(connectionStatus), lineWidth: 2)
                .scaleEffect(glowAnimation ? 2 : 1)
                .opacity(glowAnimation ? 0 : 1)
                .animation(
                    reduceMotion ? .none :
                    Animation.easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: glowAnimation
                )
        }
    }
    
    // MARK: - Animations
    private var toolTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        } else {
            return .asymmetric(
                insertion: .slide.combined(with: .opacity),
                removal: .opacity
            )
        }
    }
    
    private var listAnimation: Animation? {
        if reduceMotion {
            return .none
        } else {
            return .spring(response: 0.3, dampingFraction: 0.8)
        }
    }
    
    private var glowingAnimation: Animation? {
        if reduceMotion {
            return .none
        } else {
            return Animation.easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
        }
    }
    
    // MARK: - Helper Functions
    private func colorForConnectionStatus(_ status: ChatViewModel.ConnectionStatus) -> Color {
        switch status {
        case .disconnected: return Color.gray
        case .connecting: return Color.yellow
        case .connected: return Color.green
        case .error: return Color.red
        }
    }
    
    private func startAnimations() {
        guard !reduceMotion else { return }
        withAnimation {
            glowAnimation = true
        }
    }
}

/// Tool execution row component
struct ToolExecutionRowComponent: View {
    let tool: ToolExecution
    let onTap: () -> Void
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                // Status indicator
                ToolStatusIndicator(status: tool.state)
                
                // Tool info
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    toolHeader
                    
                    if !tool.input.isEmpty {
                        inputPreview
                    }
                    
                    if !tool.output.isEmpty {
                        outputPreview
                    }
                }
                
                Spacer()
            }
            .padding(Theme.Spacing.sm)
            .background(toolBackground)
            .overlay(toolBorder)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tool.name) tool")
        .accessibilityHint("Tap to see details")
        .accessibilityValue(statusDescription)
    }
    
    @ViewBuilder
    private var toolHeader: some View {
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
            HStack(spacing: Theme.Spacing.xs) {
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
        }
    }
    
    @ViewBuilder
    private var inputPreview: some View {
        Text(formatJSON(tool.input))
            .font(.caption)
            .foregroundStyle(Theme.mutedFg)
            .lineLimit(2)
            .padding(Theme.Spacing.xs)
            .background(Theme.background.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    @ViewBuilder
    private var outputPreview: some View {
        Text(tool.output)
            .font(.caption)
            .foregroundStyle(outputColor)
            .lineLimit(4)
            .padding(Theme.Spacing.xs)
            .background(outputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var toolBackground: some View {
        LinearGradient(
            colors: [
                Theme.card,
                tool.state == .running ? color(for: tool.state).opacity(0.1) : Theme.card
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var toolBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                tool.state == .running ?
                color(for: tool.state).opacity(0.4) :
                Theme.border.opacity(0.3),
                lineWidth: 1
            )
    }
    
    private var outputColor: Color {
        tool.state == .failure ? Theme.destructive : Color(h: 140, s: 60, l: 60)
    }
    
    private var outputBackground: Color {
        tool.state == .failure ?
        Theme.destructive.opacity(0.1) :
        Theme.background.opacity(0.5)
    }
    
    private var statusDescription: String {
        switch tool.state {
        case .running: return "Running"
        case .success: return "Completed successfully"
        case .failure: return "Failed"
        }
    }
    
    private func color(for status: ToolExecution.Status) -> Color {
        switch status {
        case .running: return Color(h: 45, s: 100, l: 50)   // Yellow
        case .success: return Color(h: 140, s: 100, l: 50)  // Green
        case .failure: return Theme.destructive
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
    
    private func formatJSON(_ json: String) -> String {
        json
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: ",", with: ", ")
    }
}

/// Tool status indicator component
struct ToolStatusIndicator: View {
    let status: ToolExecution.Status
    
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    private var color: Color {
        switch status {
        case .running: return Color(h: 45, s: 100, l: 50)
        case .success: return Color(h: 140, s: 100, l: 50)
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
            
            if status == .running && !reduceMotion {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .scaleEffect(animating ? 1.5 : 1)
                    .opacity(animating ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: animating
                    )
                    .onAppear { animating = true }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview
struct ToolTimelineView_Previews: PreviewProvider {
    static var sampleTools: [ToolExecution] = [
        ToolExecution(
            id: "1",
            name: "Grep Search",
            input: "{\"pattern\": \"TODO\", \"path\": \"./src\"}",
            output: "Found 3 matches",
            state: .success,
            durationMs: 125,
            exitCode: 0
        ),
        ToolExecution(
            id: "2",
            name: "Edit File",
            input: "{\"file\": \"main.swift\", \"line\": 42}",
            output: "",
            state: .running,
            durationMs: nil,
            exitCode: nil
        ),
        ToolExecution(
            id: "3",
            name: "Bash Command",
            input: "{\"command\": \"ls -la\"}",
            output: "Error: Permission denied",
            state: .failure,
            durationMs: 50,
            exitCode: 1
        )
    ]
    
    static var previews: some View {
        ToolTimelineView(
            tools: sampleTools,
            connectionStatus: .connected,
            totalTokens: 1234,
            totalCost: 0.0042,
            isExpanded: true
        )
        .padding()
        .background(Theme.background)
    }
}