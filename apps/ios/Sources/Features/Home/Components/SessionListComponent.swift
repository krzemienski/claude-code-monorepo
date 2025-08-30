import SwiftUI

/// SessionListComponent - Displays list of chat sessions
public struct SessionListComponent: View {
    let sessions: [ChatSession]
    let onSessionTap: (ChatSession) -> Void
    let onNewSession: () -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    public init(
        sessions: [ChatSession],
        onSessionTap: @escaping (ChatSession) -> Void,
        onNewSession: @escaping () -> Void
    ) {
        self.sessions = sessions
        self.onSessionTap = onSessionTap
        self.onNewSession = onNewSession
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Label("Recent Sessions", systemImage: "bubble.left.and.bubble.right")
                    .font(.headline)
                    .foregroundStyle(Theme.primary)
                
                Spacer()
                
                Button(action: onNewSession) {
                    Label("New", systemImage: "plus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("New Session")
                .accessibilityHint("Create a new chat session")
            }
            
            if sessions.isEmpty {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: "No Sessions",
                    message: "Start a new session to begin",
                    actionTitle: "New Session",
                    action: onNewSession
                )
            } else {
                SessionList(sessions: sessions, onTap: onSessionTap)
            }
        }
    }
}

// MARK: - Session List
private struct SessionList: View {
    let sessions: [ChatSession]
    let onTap: (ChatSession) -> Void
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(sessions.prefix(5)) { session in
                SessionRow(session: session, onTap: onTap)
            }
        }
    }
}

// MARK: - Session Row
private struct SessionRow: View {
    let session: ChatSession
    let onTap: (ChatSession) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { onTap(session) }) {
            HStack(spacing: 12) {
                // Session Icon
                Image(systemName: session.icon ?? "bubble.left")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Theme.accent.opacity(0.1))
                    )
                
                // Session Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(session.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Message Count
                if session.messageCount > 0 {
                    Text("\(session.messageCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Theme.primary)
                        )
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Theme.secondaryBackground : Theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.title), \(session.formattedDate), \(session.messageCount) messages")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Empty State View
private struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: action) {
                Label(actionTitle, systemImage: "plus.circle")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Chat Session Extension
extension ChatSession {
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
    
    var icon: String? {
        // Return icon based on session type or content
        switch type {
        case .coding:
            return "chevron.left.forwardslash.chevron.right"
        case .documentation:
            return "doc.text"
        case .general:
            return "bubble.left"
        default:
            return "bubble.left"
        }
    }
    
    var messageCount: Int {
        messages?.count ?? 0
    }
}

// MARK: - Preview Provider
struct SessionListComponent_Previews: PreviewProvider {
    static let mockSessions = [
        ChatSession(
            id: "1",
            title: "SwiftUI Navigation Help",
            type: .coding,
            messages: Array(repeating: Message(role: .user, content: "test"), count: 5),
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-1800)
        ),
        ChatSession(
            id: "2",
            title: "API Documentation",
            type: .documentation,
            messages: Array(repeating: Message(role: .assistant, content: "test"), count: 12),
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date().addingTimeInterval(-7200)
        )
    ]
    
    static var previews: some View {
        Group {
            SessionListComponent(
                sessions: mockSessions,
                onSessionTap: { _ in },
                onNewSession: {}
            )
            .previewDisplayName("With Sessions")
            
            SessionListComponent(
                sessions: [],
                onSessionTap: { _ in },
                onNewSession: {}
            )
            .previewDisplayName("Empty State")
        }
        .padding()
        .background(Color(.systemBackground))
    }
}