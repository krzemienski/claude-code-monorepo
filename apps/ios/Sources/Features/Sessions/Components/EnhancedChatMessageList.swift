import SwiftUI

/// Enhanced Chat Message List with cyberpunk animations and haptic feedback
public struct EnhancedChatMessageList: View {
    let messages: [ChatMessage]
    @Binding var scrollToBottom: Bool
    let onToolTapped: (ToolExecution) -> Void
    
    @Namespace private var bottomAnchor
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    @State private var appearingMessages: Set<String> = []
    @State private var typingIndicator = false
    
    public init(
        messages: [ChatMessage],
        scrollToBottom: Binding<Bool>,
        onToolTapped: @escaping (ToolExecution) -> Void
    ) {
        self.messages = messages
        self._scrollToBottom = scrollToBottom
        self.onToolTapped = onToolTapped
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { message in
                        EnhancedChatMessageRow(
                            message: message,
                            onToolTapped: onToolTapped,
                            isAppearing: appearingMessages.contains(message.id)
                        )
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.8)),
                            removal: .opacity.combined(with: .scale(scale: 0.8))
                        ))
                        .onAppear {
                            animateMessageAppearance(message.id)
                        }
                    }
                    
                    // Typing indicator
                    if typingIndicator {
                        TypingIndicatorView()
                            .transition(.opacity.combined(with: .scale))
                    }
                    
                    // Bottom anchor for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(20)
            }
            .background(
                ZStack {
                    CyberpunkTheme.darkBackground
                    
                    // Subtle matrix rain effect in background
                    if !reduceMotion {
                        MatrixRainEffect(columnCount: 10)
                            .opacity(0.05)
                    }
                }
            )
            .onChange(of: messages.count) { _ in
                if scrollToBottom {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    // Haptic feedback for new message
                    CyberpunkTheme.lightImpact()
                }
            }
            .onChange(of: scrollToBottom) { shouldScroll in
                if shouldScroll {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Enhanced message list")
        .accessibilityHint("\(messages.count) messages")
    }
    
    private func animateMessageAppearance(_ id: String) {
        guard !appearingMessages.contains(id) else { return }
        
        appearingMessages.insert(id)
        
        // Remove from appearing set after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            appearingMessages.remove(id)
        }
    }
}

/// Enhanced message row with cyberpunk styling
struct EnhancedChatMessageRow: View {
    let message: ChatMessage
    let onToolTapped: (ToolExecution) -> Void
    let isAppearing: Bool
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var isHovered = false
    @State private var glowAnimation = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Enhanced avatar
            enhancedAvatar
            
            // Message content with cyberpunk styling
            VStack(alignment: .leading, spacing: 8) {
                // Header with name and timestamp
                messageHeader
                
                // Message content with glow effect
                messageContent
                
                // Tool executions with animations
                if let tools = message.toolExecutions, !tools.isEmpty {
                    EnhancedToolExecutionList(
                        tools: tools,
                        onToolTapped: onToolTapped
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(messageBackground)
        .scaleEffect(isAppearing ? 0.95 : 1.0)
        .opacity(isAppearing ? 0.8 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isAppearing)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            if hovering {
                CyberpunkTheme.selectionFeedback()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? "You" : "Assistant") said: \(message.content)")
    }
    
    private var enhancedAvatar: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: avatarGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 44, height: 44)
                .blur(radius: isHovered ? 3 : 1)
                .opacity(isHovered ? 0.8 : 0.5)
            
            // Inner circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: avatarGradientColors.map { $0.opacity(0.2) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
            
            // Icon
            Image(systemName: message.role == .user ? "person.fill" : "cpu")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(avatarColor)
                .neonGlow(color: avatarColor, intensity: 2)
        }
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
    
    private var messageHeader: some View {
        HStack {
            Text(message.role == .user ? "YOU" : "ASSISTANT")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(avatarColor)
            
            Spacer()
            
            if let timestamp = message.timestamp {
                Text(formatTimestamp(timestamp))
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .foregroundStyle(CyberpunkTheme.neonGreen.opacity(0.5))
            }
        }
    }
    
    private var messageContent: some View {
        Text(message.content)
            .font(.system(size: 15, weight: .regular, design: .default))
            .foregroundStyle(Color.white.opacity(0.9))
            .textSelection(.enabled)
            .padding(.vertical, 4)
    }
    
    private var messageBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(message.role == .user ? 
                    CyberpunkTheme.darkCard : 
                    CyberpunkTheme.darkBackground)
            
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: borderGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .blur(radius: isHovered ? 2 : 0)
                .opacity(isHovered ? 0.8 : 0.3)
        }
    }
    
    private var avatarColor: Color {
        message.role == .user ? CyberpunkTheme.neonCyan : CyberpunkTheme.neonMagenta
    }
    
    private var avatarGradientColors: [Color] {
        message.role == .user ? 
            [CyberpunkTheme.neonCyan, CyberpunkTheme.neonBlue] :
            [CyberpunkTheme.neonMagenta, CyberpunkTheme.neonPurple]
    }
    
    private var borderGradientColors: [Color] {
        message.role == .user ?
            [CyberpunkTheme.neonCyan.opacity(0.6), CyberpunkTheme.neonBlue.opacity(0.3)] :
            [CyberpunkTheme.neonMagenta.opacity(0.6), CyberpunkTheme.neonPurple.opacity(0.3)]
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Enhanced tool execution list with animations
struct EnhancedToolExecutionList: View {
    let tools: [ToolExecution]
    let onToolTapped: (ToolExecution) -> Void
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(tools) { tool in
                EnhancedToolButton(tool: tool, onTap: {
                    onToolTapped(tool)
                })
            }
        }
    }
}

struct EnhancedToolButton: View {
    let tool: ToolExecution
    let onTap: () -> Void
    
    @State private var isPressed = false
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        Button(action: {
            CyberpunkTheme.mediumImpact()
            onTap()
        }) {
            HStack(spacing: 8) {
                // Animated status indicator
                ZStack {
                    Circle()
                        .fill(tool.status.color.opacity(0.2))
                        .frame(width: 20, height: 20)
                    
                    Image(systemName: tool.status.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(tool.status.color)
                        .neonGlow(color: tool.status.color, intensity: 2)
                }
                
                Text(tool.name)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(CyberpunkTheme.neonGreen)
                
                if let duration = tool.duration {
                    Text("[\(String(format: "%.2fs", duration))]")
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonGreen.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(CyberpunkTheme.neonGreen.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(CyberpunkTheme.darkCard)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tool.status.color.opacity(0.4), lineWidth: 1)
                }
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        } perform: {
            // Long press action if needed
        }
        .accessibilityLabel("Tool: \(tool.name)")
        .accessibilityHint("Status: \(tool.status.rawValue). Tap for details")
    }
}

/// Typing indicator with cyberpunk animation
struct TypingIndicatorView: View {
    @State private var animationPhase = 0.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar for assistant
            ZStack {
                Circle()
                    .stroke(CyberpunkTheme.neonMagenta.opacity(0.5), lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                Image(systemName: "cpu")
                    .font(.system(size: 20))
                    .foregroundStyle(CyberpunkTheme.neonMagenta)
            }
            
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(CyberpunkTheme.neonMagenta)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationScale(for: index))
                        .opacity(animationOpacity(for: index))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(CyberpunkTheme.darkCard)
            )
            
            Spacer()
        }
        .padding(16)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                animationPhase = 1.0
            }
        }
    }
    
    private func animationScale(for index: Int) -> CGFloat {
        let phase = animationPhase + Double(index) * 0.3
        return 1.0 + 0.3 * sin(phase * .pi * 2)
    }
    
    private func animationOpacity(for index: Int) -> Double {
        let phase = animationPhase + Double(index) * 0.3
        return 0.5 + 0.5 * sin(phase * .pi * 2)
    }
}