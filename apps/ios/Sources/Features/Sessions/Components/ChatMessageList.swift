import SwiftUI

/// Extracted chat message list component
/// Handles displaying messages with proper scrolling and accessibility
struct ChatMessageList: View {
    let messages: [ChatMessage]
    @Binding var scrollToBottom: Bool
    let onToolTapped: (ToolExecution) -> Void
    
    @Namespace private var bottomAnchor
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(messages) { message in
                        ChatMessageRow(
                            message: message,
                            onToolTapped: onToolTapped
                        )
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    
                    // Bottom anchor for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.background)
            .onChange(of: messages.count) { _ in
                if scrollToBottom {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onChange(of: scrollToBottom) { shouldScroll in
                if shouldScroll {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message list")
        .accessibilityHint("\(messages.count) messages")
    }
}

/// Individual message row component
struct ChatMessageRow: View {
    let message: ChatMessage
    let onToolTapped: (ToolExecution) -> Void
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            // Avatar
            messageAvatar
            
            // Message content
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Sender name and timestamp
                HStack {
                    Text(message.role == .user ? "You" : "Assistant")
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                        .fontWeight(.medium)
                        .foregroundStyle(message.role == .user ? Theme.primary : Theme.neonCyan)
                    
                    Spacer()
                    
                    if let timestamp = message.timestamp {
                        Text(formatTimestamp(timestamp))
                            .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                            .foregroundStyle(Theme.mutedFg)
                    }
                }
                
                // Message content
                Text(message.content)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.foreground)
                    .textSelection(.enabled)
                
                // Tool executions if any
                if let tools = message.toolExecutions, !tools.isEmpty {
                    ToolExecutionList(
                        tools: tools,
                        onToolTapped: onToolTapped
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(message.role == .user ? Theme.card : Theme.secondaryBackground.opacity(0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? "You" : "Assistant") said: \(message.content)")
    }
    
    private var messageAvatar: some View {
        Circle()
            .fill(message.role == .user ? Theme.primary : Theme.neonCyan)
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: message.role == .user ? "person.fill" : "cpu")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Tool execution list component
struct ToolExecutionList: View {
    let tools: [ToolExecution]
    let onToolTapped: (ToolExecution) -> Void
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(tools) { tool in
                Button {
                    onToolTapped(tool)
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        // Status indicator
                        Image(systemName: tool.status.icon)
                            .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                            .foregroundStyle(tool.status.color)
                        
                        Text(tool.name)
                            .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                            .foregroundStyle(Theme.foreground)
                        
                        if let duration = tool.duration {
                            Text("(\(String(format: "%.2fs", duration)))")
                                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                                .foregroundStyle(Theme.mutedFg)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.card)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tool: \(tool.name)")
                .accessibilityHint("Status: \(tool.status.rawValue). Tap for details")
            }
        }
    }
}

// MARK: - Preview
struct ChatMessageList_Previews: PreviewProvider {
    static var previews: some View {
        ChatMessageList(
            messages: [
                ChatMessage(
                    id: "1",
                    role: .user,
                    content: "Hello, can you help me?",
                    timestamp: Date()
                ),
                ChatMessage(
                    id: "2",
                    role: .assistant,
                    content: "Of course! I'd be happy to help you. What do you need assistance with?",
                    timestamp: Date(),
                    toolExecutions: [
                        ToolExecution(
                            id: "t1",
                            name: "analyze_code",
                            state: .completed,
                            duration: 1.5
                        )
                    ]
                )
            ],
            scrollToBottom: .constant(true),
            onToolTapped: { _ in }
        )
        .background(Theme.background)
        .previewDisplayName("Chat Message List")
    }
}