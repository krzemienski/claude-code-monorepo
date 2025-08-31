import SwiftUI

/// SessionListComponent - Displays list of chat sessions
public struct SessionListComponent: View {
    let sessions: [APIClient.Session]
    let onSessionTap: (APIClient.Session) -> Void
    let onNewSession: () -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    public init(
        sessions: [APIClient.Session],
        onSessionTap: @escaping (APIClient.Session) -> Void,
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
                SessionEmptyStateView(
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
    let sessions: [APIClient.Session]
    let onTap: (APIClient.Session) -> Void
    
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
    let session: APIClient.Session
    let onTap: (APIClient.Session) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { onTap(session) }) {
            HStack(spacing: 12) {
                // Session Icon
                Image(systemName: session.icon)
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
                    
                    Text(session.updatedAt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Message Count
                if let count = session.messageCount, count > 0 {
                    Text("\(count)")
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
                    .fill(isHovered ? Theme.backgroundSecondary : Theme.background)
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
private struct SessionEmptyStateView: View {
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

// MARK: - API Session Extension
// Extension moved to APISessionListComponent.swift to avoid duplication

// MARK: - Preview Provider
struct SessionListComponent_Previews: PreviewProvider {
    static let mockSessions = [
        APIClient.Session(
            id: "1",
            projectId: "proj-1",
            title: "SwiftUI Navigation Help",
            model: "claude-3-opus",
            systemPrompt: nil,
            createdAt: "2024-01-20T10:00:00Z",
            updatedAt: "2024-01-20T10:30:00Z",
            isActive: true,
            totalTokens: 1250,
            totalCost: 0.05,
            messageCount: 10
        ),
        APIClient.Session(
            id: "2",
            projectId: "proj-1",
            title: "API Documentation",
            model: "gpt-4",
            systemPrompt: nil,
            createdAt: "2024-01-19T10:00:00Z",
            updatedAt: "2024-01-19T12:00:00Z",
            isActive: false,
            totalTokens: 850,
            totalCost: 0.03,
            messageCount: 5
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