import SwiftUI

/// Input bar component for message composition
/// Handles text input, send button, and accessibility
struct InputBarView: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () async -> Void
    let onStop: () async -> Void
    
    // MARK: - State
    @FocusState private var isInputFocused: Bool
    @State private var sendButtonScale: CGFloat = 1.0
    @State private var stopButtonScale: CGFloat = 1.0
    
    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorSchemeContrast) var colorContrast
    
    // MARK: - Computed Properties
    private var sendButtonGradient: LinearGradient {
        if text.isEmpty {
            return LinearGradient(
                colors: [Theme.secondary, Theme.secondary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(h: 280, s: 100, l: 50),
                    Color(h: 220, s: 100, l: 50)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: Theme.Spacing.none) {
            Divider()
                .background(Theme.border)
            
            HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
                // Text input field
                textInputField
                
                // Action buttons
                VStack(spacing: Theme.Spacing.sm) {
                    sendButton
                    
                    if isStreaming {
                        stopButton
                            .transition(buttonTransition)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(backgroundView)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message input area")
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var textInputField: some View {
        AnimatedTextEditor(
            placeholder: "Type your message...",
            text: $text,
            minHeight: 44,
            maxHeight: 120
        )
        .focused($isInputFocused)
        .disabled(isStreaming)
        .overlay(inputFieldOverlay)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Message input")
        .accessibilityHint("Type your message here")
        .accessibilityValue(text.isEmpty ? "Empty" : "Contains text")
        .accessibilityAddTraits(.isSearchField)
    }
    
    private var inputFieldOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                isInputFocused ?
                LinearGradient(
                    colors: [
                        Theme.primary.opacity(0.6),
                        Color(h: 280, s: 100, l: 50).opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [Theme.border],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isInputFocused ? 2 : 1
            )
    }
    
    @ViewBuilder
    private var sendButton: some View {
        Button {
            performSend()
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .medium))
                    .rotationEffect(.degrees(canSend ? 0 : -45))
                
                if !isCompact {
                    Text("Send")
                        .fontWeight(.medium)
                }
            }
            .foregroundStyle(canSend ? .white : Theme.mutedFg)
            .padding(.horizontal, isCompact ? Theme.Spacing.sm : Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(minWidth: 44, minHeight: 44)
        }
        .background(sendButtonGradient)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.md))
        .disabled(!canSend)
        .scaleEffect(sendButtonScale)
        .shadow(
            color: sendButtonShadowColor,
            radius: sendButtonShadowRadius,
            x: 0,
            y: Theme.Spacing.xxs
        )
        .animation(buttonAnimation, value: canSend)
        .animation(buttonAnimation, value: sendButtonScale)
        .accessibilityLabel("Send message")
        .accessibilityHint(canSend ? "Double tap to send" : "Type a message first")
        .accessibilityAddTraits(canSend ? [] : .isNotEnabled)
    }
    
    @ViewBuilder
    private var stopButton: some View {
        Button {
            performStop()
        } label: {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .background(Theme.destructive)
        .clipShape(Circle())
        .scaleEffect(stopButtonScale)
        .shadow(
            color: Theme.destructive.opacity(0.3),
            radius: reduceTransparency ? 0 : Theme.Spacing.sm,
            x: 0,
            y: Theme.Spacing.xxs
        )
        .accessibilityLabel("Stop streaming")
        .accessibilityHint("Double tap to stop the current response")
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if reduceTransparency {
            Theme.card
        } else {
            Theme.card.opacity(0.8)
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Theme.primary.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
    
    // MARK: - Computed Properties for Styling
    private var isCompact: Bool {
        UIScreen.main.bounds.width < 390
    }
    
    private var sendButtonShadowColor: Color {
        canSend ? Color(h: 250, s: 100, l: 50).opacity(0.4) : .clear
    }
    
    private var sendButtonShadowRadius: CGFloat {
        reduceTransparency ? 0 : Theme.Spacing.sm
    }
    
    private var buttonTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        } else {
            return .scale(scale: 0.8).combined(with: .opacity)
        }
    }
    
    private var buttonAnimation: Animation? {
        if reduceMotion {
            return .none
        } else {
            return .spring(response: 0.3, dampingFraction: 0.7)
        }
    }
    
    // MARK: - Actions
    private func performSend() {
        guard canSend else { return }
        
        // Button press animation
        if !reduceMotion {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                sendButtonScale = 0.9
            }
        }
        
        // Send message
        Task {
            await onSend()
            
            // Reset button scale
            if !reduceMotion {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    sendButtonScale = 1.0
                }
            }
        }
    }
    
    private func performStop() {
        // Button press animation
        if !reduceMotion {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                stopButtonScale = 0.9
            }
        }
        
        // Stop streaming
        Task {
            await onStop()
            
            // Reset button scale
            if !reduceMotion {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    stopButtonScale = 1.0
                }
            }
        }
    }
}

// MARK: - Preview
struct InputBarView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var text = ""
        @State private var isStreaming = false
        
        var body: some View {
            VStack {
                Spacer()
                
                InputBarView(
                    text: $text,
                    isStreaming: isStreaming,
                    onSend: {
                        print("Send: \(text)")
                        text = ""
                        isStreaming = true
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        isStreaming = false
                    },
                    onStop: {
                        print("Stop")
                        isStreaming = false
                    }
                )
            }
            .background(Theme.background)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}