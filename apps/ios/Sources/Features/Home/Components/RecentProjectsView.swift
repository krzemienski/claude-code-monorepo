import SwiftUI

// Type alias for convenience
typealias Project = APIClient.Project

/// Recent projects component for home view
/// Displays a list of recent projects with navigation
struct RecentProjectsView: View {
    let projects: [Project]
    let isLoading: Bool
    
    // MARK: - State
    @State private var hoveredProject: String?
    
    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    // MARK: - Body
    var body: some View {
        HomeCardComponent(
            title: "Recent Projects",
            icon: "folder.fill",
            iconColor: Color(h: 280, s: 100, l: 50)
        ) {
            if isLoading {
                loadingView
            } else if projects.isEmpty {
                emptyView
            } else {
                projectsList
            }
        }
    }
    
    // MARK: - Subviews
    private var loadingView: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
            
            Text("Loading projects...")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedFg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
    }
    
    private var emptyView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "folder.badge.questionmark")
                .font(.largeTitle)
                .foregroundStyle(Theme.mutedFg.opacity(0.5))
            
            Text("No projects yet")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedFg)
            
            Text("Create your first project to get started")
                .font(.caption)
                .foregroundStyle(Theme.mutedFg.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
    }
    
    private var projectsList: some View {
        VStack(spacing: Theme.Spacing.none) {
            ForEach(projects.prefix(3)) { project in
                VStack(spacing: Theme.Spacing.none) {
                    projectRow(for: project)
                    
                    if project.id != projects.prefix(3).last?.id {
                        Divider()
                            .background(Theme.border)
                            .padding(.leading, 44)
                    }
                }
            }
            
            if projects.count > 3 {
                viewAllButton
            }
        }
    }
    
    private func projectRow(for project: Project) -> some View {
        NavigationLink(destination: ProjectDetailView(projectId: project.id)) {
            HStack(spacing: Theme.Spacing.md) {
                // Project icon
                projectIcon(for: project)
                
                // Project info
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(Theme.foreground)
                        .applyDynamicTypeSize()
                    
                    Text(project.path ?? "No path specified")
                        .font(.caption)
                        .foregroundStyle(Theme.mutedFg)
                        .applyDynamicTypeSize()
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, Theme.Spacing.xs)
            .background(
                hoveredProject == project.id ?
                Theme.primary.opacity(0.05) :
                Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoveredProject = isHovered ? project.id : nil
                }
            }
        }
        .buttonStyle(.plain)
        .accessibleNavigationLink(
            label: "Project \(project.name)",
            hint: "Path: \(project.path ?? "No path specified"). Double tap to open."
        )
    }
    
    private func projectIcon(for project: Project) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(h: 280, s: 100, l: 50).opacity(0.2),
                            Color(h: 250, s: 100, l: 50).opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
            
            Image(systemName: iconForProject(project))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(h: 280, s: 100, l: 50))
        }
    }
    
    private var viewAllButton: some View {
        NavigationLink(destination: ProjectsListView()) {
            HStack {
                Text("View all \(projects.count) projects")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.primary)
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
            }
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, Theme.Spacing.md)
            .background(Theme.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.top, Theme.Spacing.sm)
        .accessibleNavigationLink(
            label: "View all projects",
            hint: "\(projects.count) projects available. Double tap to see all."
        )
    }
    
    // MARK: - Helper Functions
    private func iconForProject(_ project: Project) -> String {
        // Determine icon based on project type or name patterns
        let name = project.name.lowercased()
        
        if name.contains("ios") || name.contains("iphone") || name.contains("ipad") {
            return "applelogo"
        } else if name.contains("web") || name.contains("website") {
            return "globe"
        } else if name.contains("api") || name.contains("backend") {
            return "server.rack"
        } else if name.contains("ml") || name.contains("ai") {
            return "brain"
        } else if name.contains("data") || name.contains("database") {
            return "cylinder"
        } else if name.contains("game") {
            return "gamecontroller"
        } else {
            return "folder"
        }
    }
}

// MARK: - Preview
struct RecentProjectsView_Previews: PreviewProvider {
    static var sampleProjects: [Project] = [
        Project(
            id: "1",
            name: "iOS App",
            description: "Native iOS application built with SwiftUI",
            path: "/Users/dev/projects/ios-app",
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-15T00:00:00Z"
        ),
        Project(
            id: "2",
            name: "Web Dashboard",
            description: "React-based admin dashboard",
            path: "/Users/dev/projects/web-dashboard",
            createdAt: "2024-01-05T00:00:00Z",
            updatedAt: "2024-01-16T00:00:00Z"
        ),
        Project(
            id: "3",
            name: "Backend API",
            description: "Node.js REST API service",
            path: "/Users/dev/projects/backend-api",
            createdAt: "2024-01-10T00:00:00Z",
            updatedAt: "2024-01-17T00:00:00Z"
        ),
        Project(
            id: "4",
            name: "ML Model",
            description: "Machine learning model for predictions",
            path: "/Users/dev/projects/ml-model",
            createdAt: "2024-01-12T00:00:00Z",
            updatedAt: "2024-01-18T00:00:00Z"
        )
    ]
    
    static var previews: some View {
        VStack(spacing: Theme.Spacing.xl) {
            RecentProjectsView(
                projects: sampleProjects,
                isLoading: false
            )
            
            RecentProjectsView(
                projects: [],
                isLoading: false
            )
            
            RecentProjectsView(
                projects: [],
                isLoading: true
            )
        }
        .padding()
        .background(Theme.background)
    }
}