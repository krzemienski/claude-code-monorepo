import SwiftUI

/// Enhanced Message Composer with cyberpunk glow effects and animations
public struct EnhancedMessageComposer: View {
    @Binding var inputText: String
    @Binding var isStreaming: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    let onAttachment: (() -> Void)?
    let onVoiceInput: (() -> Void)?
    
    @State private var sendButtonScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 2.0
    @State private var isTyping = false
    @State private var pulseAnimation = false
    @FocusState private var isTextFieldFocused: Bool
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init(
        inputText: Binding<String>,
        isStreaming: Binding<Bool>,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onAttachment: (() -> Void)? = nil,
        onVoiceInput: (() -> Void)? = nil
    ) {
        self._inputText = inputText
        self._isStreaming = isStreaming
        self.onSend = onSend
        self.onStop = onStop
        self.onAttachment = onAttachment
        self.onVoiceInput = onVoiceInput
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Animated divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            CyberpunkTheme.neonCyan.opacity(0),
                            CyberpunkTheme.neonCyan.opacity(0.5),
                            CyberpunkTheme.neonMagenta.opacity(0.5),
                            CyberpunkTheme.neonMagenta.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .blur(radius: pulseAnimation ? 2 : 0)
                .opacity(pulseAnimation ? 0.8 : 0.5)
            
            composerContent
        }
        .background(CyberpunkTheme.darkCard)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                    glowIntensity = 4.0
                }
            }
        }
    }
    
    private var composerContent: some View {
        HStack(spacing: 12) {
            // Left actions
            leftActionButtons
            
            // Text input field with cyberpunk styling
            enhancedTextField
            
            // Right actions
            rightActionButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Left Action Buttons
    private var leftActionButtons: some View {
        HStack(spacing: 8) {
            // Attachment button
            if let onAttachment = onAttachment {
                ActionButton(
                    icon: "paperclip",
                    color: CyberpunkTheme.neonBlue,
                    action: onAttachment,
                    accessibilityLabel: "Add attachment"
                )
            }
            
            // Voice input button
            if let onVoiceInput = onVoiceInput {
                ActionButton(
                    icon: "mic.fill",
                    color: CyberpunkTheme.neonPurple,
                    action: onVoiceInput,
                    accessibilityLabel: "Voice input"
                )
            }
        }
    }
    
    // MARK: - Enhanced Text Field
    private var enhancedTextField: some View {
        ZStack(alignment: .leading) {
            // Background with glow effect
            RoundedRectangle(cornerRadius: 12)
                .fill(CyberpunkTheme.darkBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: textFieldBorderColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isTextFieldFocused ? 2 : 1
                        )
                        .blur(radius: isTextFieldFocused ? 1 : 0)
                )
            
            // Placeholder text with typing animation
            if inputText.isEmpty {
                HStack(spacing: 0) {
                    Text("Type your message")
                        .font(.system(size: 15, weight: .light, design: .monospaced))
                        .foregroundStyle(CyberpunkTheme.neonCyan.opacity(0.3))
                    
                    if isTextFieldFocused {
                        CyberpunkTypingCursor()
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Actual text field
            TextField("", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(Color.white)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .focused($isTextFieldFocused)
                .disabled(isStreaming)
                .onChange(of: inputText) { newValue in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isTyping = !newValue.isEmpty
                    }
                }
                .onSubmit {
                    if canSend {
                        sendMessage()
                    }
                }
        }
        .accessibilityLabel("Message input")
        .accessibilityHint("Type your message here")
    }
    
    // MARK: - Right Action Buttons
    private var rightActionButtons: some View {
        HStack(spacing: 8) {
            // Clear button (only when text is present)
            if !inputText.isEmpty && !isStreaming {
                ActionButton(
                    icon: "xmark.circle.fill",
                    color: CyberpunkTheme.neonOrange,
                    action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            inputText = ""
                        }
                        CyberpunkTheme.lightImpact()
                    },
                    accessibilityLabel: "Clear text"
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Send/Stop button
            SendStopButton(
                isStreaming: isStreaming,
                canSend: canSend,
                sendAction: sendMessage,
                stopAction: onStop
            )
        }
    }
    
    private var textFieldBorderColors: [Color] {
        if isTextFieldFocused {
            return [CyberpunkTheme.neonCyan, CyberpunkTheme.neonMagenta]
        } else if !inputText.isEmpty {
            return [CyberpunkTheme.neonBlue.opacity(0.6), CyberpunkTheme.neonPurple.opacity(0.6)]
        } else {
            return [CyberpunkTheme.darkBorder, CyberpunkTheme.darkBorder]
        }
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }
    
    private func sendMessage() {
        CyberpunkTheme.mediumImpact()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            sendButtonScale = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            sendButtonScale = 1.0
            onSend()
        }
    }
}

// MARK: - Action Button Component
struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    let accessibilityLabel: String
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            CyberpunkTheme.lightImpact()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 1)
                    .frame(width: 36, height: 36)
                    .scaleEffect(isPressed ? 1.2 : 1.0)
                    .opacity(isPressed ? 0.5 : 1.0)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .neonGlow(color: color, intensity: 2)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        } perform: {}
    }
}

// MARK: - Send/Stop Button Component
struct SendStopButton: View {
    let isStreaming: Bool
    let canSend: Bool
    let sendAction: () -> Void
    let stopAction: () -> Void
    
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            if isStreaming {
                CyberpunkTheme.heavyImpact()
                stopAction()
            } else if canSend {
                sendAction()
            }
        }) {
            ZStack {
                // Background circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: buttonGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                // Rotating border for streaming state
                if isStreaming {
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    CyberpunkTheme.neonMagenta,
                                    CyberpunkTheme.neonPurple,
                                    CyberpunkTheme.neonMagenta
                                ]),
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(rotationAngle))
                }
                
                // Icon
                Image(systemName: buttonIcon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(pulseScale)
            }
            .neonGlow(color: buttonGlowColor, intensity: canSend || isStreaming ? 3 : 1)
            .scaleEffect(canSend || isStreaming ? 1.0 : 0.9)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canSend)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isStreaming)
        }
        .disabled(!canSend && !isStreaming)
        .accessibilityLabel(isStreaming ? "Stop streaming" : "Send message")
        .accessibilityHint(
            isStreaming ? "Stop the current message stream" :
            (canSend ? "Send your message" : "Enter a message first")
        )
        .onAppear {
            if isStreaming {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                }
            }
        }
        .onChange(of: isStreaming) { streaming in
            if streaming {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                }
            } else {
                rotationAngle = 0
                pulseScale = 1.0
            }
        }
    }
    
    private var buttonIcon: String {
        isStreaming ? "stop.fill" : "arrow.up"
    }
    
    private var buttonGradientColors: [Color] {
        if isStreaming {
            return [CyberpunkTheme.neonMagenta, CyberpunkTheme.neonPurple]
        } else if canSend {
            return [CyberpunkTheme.neonCyan, CyberpunkTheme.neonBlue]
        } else {
            return [CyberpunkTheme.darkBorder, CyberpunkTheme.darkBorder]
        }
    }
    
    private var buttonGlowColor: Color {
        if isStreaming {
            return CyberpunkTheme.neonMagenta
        } else if canSend {
            return CyberpunkTheme.neonCyan
        } else {
            return CyberpunkTheme.darkBorder
        }
    }
}

// MARK: - Typing Cursor Animation
struct CyberpunkTypingCursor: View {
    @State private var isBlinking = false
    
    var body: some View {
        Rectangle()
            .fill(CyberpunkTheme.neonCyan)
            .frame(width: 2, height: 20)
            .opacity(isBlinking ? 0 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    isBlinking = true
                }
            }
    }
}