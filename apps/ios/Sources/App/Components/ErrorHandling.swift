import SwiftUI

// MARK: - Error Handling Components

public enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    var color: Color {
        switch self {
        case .info: return Theme.primary
        case .warning: return Color(h: 45, s: 100, l: 50)
        case .error: return Theme.destructive
        case .critical: return Color(h: 0, s: 100, l: 40)
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
    
    var hapticFeedback: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .info: return .success
        case .warning: return .warning
        case .error, .critical: return .error
        }
    }
}

// MARK: - Error Alert View

public struct ErrorAlertView: View {
    let title: String
    let message: String
    let severity: ErrorSeverity
    let dismissAction: (() -> Void)?
    let retryAction: (() -> Void)?
    
    @State private var isPresented = true
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    public init(
        title: String,
        message: String,
        severity: ErrorSeverity = .error,
        dismissAction: (() -> Void)? = nil,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.severity = severity
        self.dismissAction = dismissAction
        self.retryAction = retryAction
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Icon and Title
            HStack(spacing: 12) {
                Image(systemName: severity.icon)
                    .font(.title2)
                    .foregroundStyle(severity.color)
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Button {
                    dismissAction?()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.secondary)
                }
                .accessibilityLabel("Dismiss error")
                .hapticButton(.light)
            }
            
            // Message
            Text(message)
                .font(.body)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused($isFocused)
            
            // Actions
            HStack(spacing: 12) {
                if let retryAction = retryAction {
                    Button {
                        HapticManager.shared.tap()
                        retryAction()
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.primary)
                    .accessibilityHint("Retry the failed operation")
                }
                
                Button {
                    HapticManager.shared.tap()
                    dismissAction?()
                    dismiss()
                } label: {
                    Text("OK")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(severity.color)
                .accessibilityHint("Dismiss this error message")
            }
        }
        .padding()
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(severity.color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: severity.color.opacity(0.2), radius: 10)
        .padding()
        .onAppear {
            HapticManager.shared.notification(severity.hapticFeedback)
            isFocused = true
            
            // Announce error to VoiceOver
            UIAccessibility.post(
                notification: .announcement,
                argument: "\(severity == .critical ? "Critical " : "")\(title). \(message)"
            )
        }
    }
}

// MARK: - Inline Error View

public struct InlineErrorView: View {
    let message: String
    let severity: ErrorSeverity
    
    @State private var isShowing = false
    
    public init(message: String, severity: ErrorSeverity = .error) {
        self.message = message
        self.severity = severity
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: severity.icon)
                .font(.caption)
                .foregroundStyle(severity.color)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(severity.color)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(severity.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(severity.color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .scaleEffect(isShowing ? 1 : 0.95)
        .opacity(isShowing ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isShowing)
        .onAppear {
            isShowing = true
            HapticManager.shared.notification(severity.hapticFeedback)
        }
        .accessibilityElement(
            label: "\(severity == .error ? "Error" : severity == .warning ? "Warning" : "Info")",
            value: message
        )
    }
}

// MARK: - Toast Notification

public struct ToastView: View {
    let message: String
    let severity: ErrorSeverity
    let duration: TimeInterval
    
    @Binding var isPresented: Bool
    @State private var workItem: DispatchWorkItem?
    
    public init(
        message: String,
        severity: ErrorSeverity = .info,
        duration: TimeInterval = 3,
        isPresented: Binding<Bool>
    ) {
        self.message = message
        self.severity = severity
        self.duration = duration
        self._isPresented = isPresented
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: severity.icon)
                .font(.body)
                .foregroundStyle(.white)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.white)
                .lineLimit(3)
            
            Spacer()
            
            Button {
                withAnimation {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .accessibilityLabel("Dismiss notification")
        }
        .padding()
        .background(severity.color)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
        .onAppear {
            HapticManager.shared.notification(severity.hapticFeedback)
            
            // Announce to VoiceOver
            UIAccessibility.post(
                notification: .announcement,
                argument: message
            )
            
            // Auto-dismiss
            workItem?.cancel()
            let task = DispatchWorkItem {
                withAnimation {
                    isPresented = false
                }
            }
            workItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
        }
        .onDisappear {
            workItem?.cancel()
        }
    }
}

// MARK: - Error Recovery Suggestions

public struct ErrorRecoverySuggestions: View {
    let errorCode: String
    let suggestions: [String]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggestions", systemImage: "lightbulb.fill")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.primary)
                .accessibilityAddTraits(.isHeader)
            
            ForEach(suggestions, id: \.self) { suggestion in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 2)
                    
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(Theme.foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Theme.card.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

