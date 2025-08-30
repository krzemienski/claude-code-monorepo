import SwiftUI

/// Message list view component for displaying chat messages
/// Handles scrolling, animations, and message rendering
struct MessageListView: View {
    let messages: [ChatMessage]
    let isStreaming: Bool
    let maxMessageWidth: CGFloat?
    
    // MARK: - State
    @State private var scrollToBottom = false
    @Namespace private var bottomAnchor
    
    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    
    // MARK: - Body
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    // Messages
                    ForEach(messages) { message in
                        MessageBubbleComponent(
                            message: message,
                            maxWidth: maxMessageWidth
                        )
                        .frame(maxWidth: .infinity, alignment: alignmentForMessage(message))
                        .padding(.horizontal)
                        .transition(messageTransition)
                        .id(message.id)
                    }
                    
                    // Typing indicator
                    if isStreaming && shouldShowTypingIndicator {
                        TypingIndicatorComponent()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .transition(typingTransition)
                    }
                    
                    // Scroll anchor
                    scrollAnchor
                        .id(bottomAnchor)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .animation(listAnimation, value: messages.count)
            }
            .background(backgroundView)
            .overlay(borderOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onChange(of: messages.count) { _ in
                scrollToLatestMessage(proxy: proxy)
            }
            .onChange(of: isStreaming) { _ in
                if isStreaming {
                    scrollToLatestMessage(proxy: proxy)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message list")
        .accessibilityHint("Shows conversation history")
    }
    
    // MARK: - Subviews
    private var scrollAnchor: some View {
        Color.clear
            .frame(height: Theme.Spacing.xxs)
            .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if reduceTransparency {
            Theme.background
        } else {
            Theme.background.opacity(0.5)
        }
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                LinearGradient(
                    colors: [Theme.primary.opacity(0.3), Theme.border],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    // MARK: - Computed Properties
    private var shouldShowTypingIndicator: Bool {
        guard let lastMessage = messages.last else { return true }
        return lastMessage.role != .assistant
    }
    
    private var messageTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        } else {
            return .asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .opacity
            )
        }
    }
    
    private var typingTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        } else {
            return .scale(scale: 0.8).combined(with: .opacity)
        }
    }
    
    private var listAnimation: Animation? {
        if reduceMotion {
            return .none
        } else {
            return .spring(response: 0.3, dampingFraction: 0.8)
        }
    }
    
    // MARK: - Helper Functions
    private func alignmentForMessage(_ message: ChatMessage) -> Alignment {
        message.role == .user ? .trailing : .leading
    }
    
    private func scrollToLatestMessage(proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.3)) {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }
}

/// Typing indicator component
struct TypingIndicatorComponent: View {
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.primary.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.2 : 0.8)
                    .animation(dotAnimation(for: index), value: animating)
            }
            
            Text("Assistant is typing...")
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
                .padding(.leading, Theme.Spacing.xs)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            if !reduceMotion {
                animating = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Assistant is typing")
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    private func dotAnimation(for index: Int) -> Animation? {
        if reduceMotion {
            return .none
        } else {
            return Animation.easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.2)
        }
    }
}

// MARK: - Preview
struct MessageListView_Previews: PreviewProvider {
    static var sampleMessages: [ChatMessage] = [
        ChatMessage(
            id: "1",
            role: .user,
            content: "Hello, I need help with SwiftUI",
            timestamp: Date().addingTimeInterval(-300),
            isStreaming: false
        ),
        ChatMessage(
            id: "2",
            role: .assistant,
            content: "I'd be happy to help you with SwiftUI! What specific aspect would you like to explore?",
            timestamp: Date().addingTimeInterval(-240),
            isStreaming: false
        ),
        ChatMessage(
            id: "3",
            role: .user,
            content: "How do I create custom components?",
            timestamp: Date().addingTimeInterval(-180),
            isStreaming: false
        ),
        ChatMessage(
            id: "4",
            role: .assistant,
            content: "Creating custom components in SwiftUI involves defining reusable views...",
            timestamp: Date(),
            isStreaming: true
        )
    ]
    
    static var previews: some View {
        MessageListView(
            messages: sampleMessages,
            isStreaming: true,
            maxMessageWidth: 300
        )
        .frame(height: 600)
        .padding()
        .background(Theme.background)
    }
}