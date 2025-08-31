import SwiftUI

/// Extracted message composer component for chat interfaces
/// Handles text input, sending messages, and action buttons
struct MessageComposer: View {
    @Binding var inputText: String
    @Binding var isStreaming: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    let onAttachment: (() -> Void)?
    
    @State private var sendButtonScale: CGFloat = 1.0
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Theme.border)
            
            HStack(spacing: Theme.Spacing.sm) {
                // Attachment button
                if let onAttachment = onAttachment {
                    Button(action: onAttachment) {
                        Image(systemName: "paperclip")
                            .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.lg, for: dynamicTypeSize)))
                            .foregroundStyle(Theme.mutedFg)
                    }
                    .accessibilityLabel("Add attachment")
                    .accessibilityHint("Attach files to your message")
                }
                
                // Text input
                messageTextField
                
                // Send/Stop button
                actionButton
            }
            .padding(Theme.Spacing.md)
            .background(Theme.card)
        }
    }
    
    private var messageTextField: some View {
        TextField("Type a message...", text: $inputText, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
            .foregroundStyle(Theme.foreground)
            .lineLimit(1...5)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Theme.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(isTextFieldFocused ? Theme.primary : Theme.border, lineWidth: 1)
            )
            .focused($isTextFieldFocused)
            .disabled(isStreaming)
            .accessibilityLabel("Message input")
            .accessibilityHint("Type your message here")
            .onSubmit {
                if !inputText.isEmpty && !isStreaming {
                    onSend()
                }
            }
    }
    
    private var actionButton: some View {
        Button {
            if isStreaming {
                onStop()
            } else if !inputText.isEmpty {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    sendButtonScale = 0.8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    sendButtonScale = 1.0
                    onSend()
                }
            }
        } label: {
            Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: Theme.FontSize.scalable(30, for: dynamicTypeSize)))
                .foregroundStyle(
                    isStreaming ? Theme.error :
                    (!inputText.isEmpty ? Theme.primary : Theme.mutedFg)
                )
                .scaleEffect(sendButtonScale)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6),
                    value: sendButtonScale
                )
        }
        .disabled(!isStreaming && inputText.isEmpty)
        .accessibilityLabel(isStreaming ? "Stop streaming" : "Send message")
        .accessibilityHint(
            isStreaming ? "Stop the current message stream" :
            (inputText.isEmpty ? "Enter a message first" : "Send your message")
        )
    }
}

// MARK: - Preview
struct MessageComposer_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            MessageComposer(
                inputText: .constant("Hello world"),
                isStreaming: .constant(false),
                onSend: {},
                onStop: {},
                onAttachment: {}
            )
        }
        .background(Theme.background)
        .previewDisplayName("Message Composer")
    }
}