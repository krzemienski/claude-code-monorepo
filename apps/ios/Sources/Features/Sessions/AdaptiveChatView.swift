import SwiftUI

/// An adaptive chat view that provides optimal layouts for both iPhone and iPad
/// Uses NavigationSplitView on iPad for master-detail layout
public struct AdaptiveChatView: View {
    @StateObject private var sessionsViewModel = SessionsViewModel()
    @StateObject private var projectsViewModel = ProjectsViewModel()
    @State private var selectedSessionId: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init() {}
    
    public var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Use NavigationSplitView for optimal layout
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    // Sidebar: Sessions list
                    SessionsListView(
                        viewModel: sessionsViewModel,
                        selectedSessionId: $selectedSessionId
                    )
                    .navigationTitle("Sessions")
                    .navigationSplitViewColumnWidth(
                        min: 280,
                        ideal: 320,
                        max: 400
                    )
                } detail: {
                    // Detail: Chat console
                    if let sessionId = selectedSessionId {
                        ChatConsoleView(
                            sessionId: sessionId,
                            projectId: "default"  // Using default project ID
                        )
                        .id(sessionId) // Force view refresh on session change
                    } else {
                        EmptyStateView(
                            title: "No Session Selected",
                            message: "Select a session from the sidebar to start chatting",
                            systemImage: "message.circle",
                            action: {
                                Task {
                                    // Note: createSession requires parameters - this needs to be handled with a sheet or default values
                                    _ = await sessionsViewModel.createSession(projectId: "default", model: "gpt-4", title: "New Session", systemPrompt: nil)
                                }
                            },
                            actionTitle: "Create New Session"
                        )
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                // Note: createSession requires parameters - this needs to be handled with a sheet or default values
                                _ = await sessionsViewModel.createSession(projectId: "default", model: "gpt-4", title: "New Session", systemPrompt: nil)
                            }
                        } label: {
                            Label("New Session", systemImage: "plus.circle.fill")
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
            } else {
                // iPhone: Use NavigationStack
                NavigationStack {
                    SessionsListView(
                        viewModel: sessionsViewModel,
                        selectedSessionId: $selectedSessionId
                    )
                    .navigationTitle("Sessions")
                    .navigationDestination(isPresented: .constant(selectedSessionId != nil)) {
                        if let sessionId = selectedSessionId {
                            ChatConsoleView(
                                sessionId: sessionId,
                                projectId: "default"  // Using default project ID
                            )
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            Button {
                                Task {
                                    // Note: createSession requires parameters - this needs to be handled with a sheet or default values
                                    _ = await sessionsViewModel.createSession(projectId: "default", model: "gpt-4", title: "New Session", systemPrompt: nil)
                                }
                            } label: {
                                Label("New Session", systemImage: "plus.circle.fill")
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                    }
                }
            }
        }
        .tint(Theme.primary)
        .onAppear {
            // Select first session on iPad if none selected
            if UIDevice.current.userInterfaceIdiom == .pad && 
               selectedSessionId == nil && 
               !sessionsViewModel.sessions.isEmpty {
                selectedSessionId = sessionsViewModel.sessions.first?.id
            }
        }
    }
}

// MARK: - Sessions List View

struct SessionsListView: View {
    @ObservedObject var viewModel: SessionsViewModel
    @Binding var selectedSessionId: String?
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        List(selection: $selectedSessionId) {
            ForEach(viewModel.sessions) { session in
                SessionRowView(session: session)
                    .tag(session.id)
                    .listRowBackground(
                        selectedSessionId == session.id ?
                        Theme.primary.opacity(0.1) :
                        Theme.card.opacity(0.3)
                    )
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await viewModel.deleteSession(viewModel.sessions[index].id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .refreshable {
            await viewModel.loadSessions()
        }
        // TODO: Add search functionality when searchQuery is added to SessionsViewModel
        // .searchable(text: $viewModel.searchQuery, prompt: "Search sessions...")
        .accessibilityElement(
            label: "Sessions list",
            hint: "Select a session to view the chat"
        )
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    let session: APIClient.Session
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.adaptive(Theme.Spacing.xs)) {
            HStack {
                // Session icon with animation
                Image(systemName: session.isActive ? "circle.fill" : "circle")
                    .font(.system(size: Theme.FontSize.adaptive(8)))
                    .foregroundStyle(
                        session.isActive ? Theme.neonGreen : Theme.mutedFg
                    )
                    .scaleEffect(session.isActive ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: session.isActive)
                
                // Session title
                Text(session.title ?? "Untitled Session")
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                
                Spacer()
                
                // Message count badge
                if let messageCount = session.messageCount, messageCount > 0 {
                    Text("\(messageCount)")
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Theme.primary.opacity(0.8))
                        )
                }
            }
            
            // Last message preview - TODO: Add when available in API
            /*if let lastMessage = session.lastMessage {
                Text(lastMessage)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.mutedFg)
                    .lineLimit(2)
            }*/
            
            // Timestamp
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: Theme.FontSize.adaptive(Theme.FontSize.xs)))
                    .foregroundStyle(Theme.mutedFg.opacity(0.6))
                
                Text(formatRelativeTime(dateFromString(session.updatedAt)))
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.mutedFg.opacity(0.6))
                
                Spacer()
                
                // Model indicator
                Text(formatModelName(session.model))
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                        .foregroundStyle(Theme.neonCyan.opacity(0.6))
            }
        }
        .padding(.vertical, Theme.Spacing.adaptive(Theme.Spacing.xs))
        .accessibilityElement(
            label: session.title ?? "Untitled Session",
            value: "\(session.messageCount ?? 0) messages, last updated \(formatRelativeTime(dateFromString(session.updatedAt)))"
        )
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func dateFromString(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString) ?? Date()
    }
    
    private func formatModelName(_ model: String) -> String {
        if model.contains("claude") { return "Claude" }
        if model.contains("gpt-4") { return "GPT-4" }
        if model.contains("gpt-3") { return "GPT-3.5" }
        return "AI"
    }
}

// MARK: - Chat Session Model

// Using APIClient.Session instead of local ChatSession struct

// MARK: - Preview Provider

struct AdaptiveChatView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // iPad Preview
            AdaptiveChatView()
                .previewDevice("iPad Pro (12.9-inch)")
                .previewDisplayName("iPad Pro")
            
            // iPhone Preview
            AdaptiveChatView()
                .previewDevice("iPhone 14 Pro")
                .previewDisplayName("iPhone 14 Pro")
        }
    }
}