import SwiftUI

/// Reusable message bubble component for chat messages
/// Maintains accessibility and Cyberpunk theme
struct MessageBubbleComponent: View {
    let message: ChatMessage
    let maxWidth: CGFloat?
    
    // MARK: - Environment
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorSchemeContrast) var colorContrast
    
    // MARK: - Computed Properties
    private var isUser: Bool {
        message.role == .user
    }
    
    private var bubbleGradient: LinearGradient {
        if isUser {
            return LinearGradient(
                colors: [
                    Color(h: 280, s: 60, l: 30),
                    Color(h: 250, s: 60, l: 25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Theme.card, Theme.card.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var roleIcon: String {
        isUser ? "person.fill" : "brain"
    }
    
    private var roleColor: Color {
        isUser ? Color(h: 280, s: 100, l: 60) : Theme.primary
    }
    
    private var textColor: Color {
        isUser ? .white : Theme.foreground
    }
    
    // MARK: - Body
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                // Header with role and timestamp
                messageHeader
                
                // Message content
                messageContent
                
                // Streaming indicator if needed
                if message.isStreaming {
                    streamingIndicator
                }
            }
            .padding(Theme.Spacing.md)
            .background(backgroundView)
            .overlay(borderOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: 3
            )
            .frame(maxWidth: maxWidth ?? .infinity, alignment: isUser ? .trailing : .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
            
            if !isUser { Spacer() }
        }
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var messageHeader: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: roleIcon)
                .font(.caption)
                .foregroundStyle(roleColor)
                .accessibilityHidden(true)
            
            Text(message.role.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
            
            Spacer()
            
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundStyle(Theme.mutedFg.opacity(0.6))
        }
    }
    
    @ViewBuilder
    private var messageContent: some View {
        Text(message.content)
            .font(.body)
            .foregroundStyle(textColor)
            .textSelection(.enabled)
            .opacity(message.isStreaming ? 0.8 : 1.0)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private var streamingIndicator: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 4, height: 4)
                    .opacity(0.6)
                    .scaleEffect(message.isStreaming ? 1.2 : 0.8)
                    .animation(
                        reduceMotion ? .none :
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: message.isStreaming
                    )
            }
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if reduceTransparency {
            bubbleGradient
        } else {
            bubbleGradient.opacity(0.95)
        }
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                isUser ?
                Color(h: 280, s: 100, l: 50).opacity(0.4) :
                Theme.border.opacity(0.3),
                lineWidth: 1
            )
    }
    
    // MARK: - Computed Properties for Styling
    private var shadowColor: Color {
        isUser ? Color(h: 280, s: 100, l: 50).opacity(0.2) : .clear
    }
    
    private var shadowRadius: CGFloat {
        reduceTransparency ? 0 : 6
    }
    
    // MARK: - Accessibility
    private var accessibilityLabel: String {
        "\(message.role.rawValue.capitalized) said: \(message.content)"
    }
    
    private var accessibilityHint: String {
        "Sent at \(formatAccessibilityTime(message.timestamp))"
    }
    
    // MARK: - Helper Functions
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
}

// MARK: - Preview
struct MessageBubbleComponent_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.md) {
            MessageBubbleComponent(
                message: ChatMessage(
                    id: "1",
                    role: .user,
                    content: "Hello, can you help me with SwiftUI?",
                    timestamp: Date(),
                    isStreaming: false
                ),
                maxWidth: 300
            )
            
            MessageBubbleComponent(
                message: ChatMessage(
                    id: "2",
                    role: .assistant,
                    content: "Of course! I'd be happy to help you with SwiftUI. What specific aspect would you like to explore?",
                    timestamp: Date(),
                    isStreaming: false
                ),
                maxWidth: 300
            )
            
            MessageBubbleComponent(
                message: ChatMessage(
                    id: "3",
                    role: .assistant,
                    content: "Let me think about that...",
                    timestamp: Date(),
                    isStreaming: true
                ),
                maxWidth: 300
            )
        }
        .padding()
        .background(Theme.background)
    }
}