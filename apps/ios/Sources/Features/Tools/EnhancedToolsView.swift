import SwiftUI

// MARK: - Enhanced Tools View
/// MCP tools management view with real API integration
public struct EnhancedToolsView: View {
    @StateObject private var viewModel: ToolsViewModel
    @State private var showingStatistics = false
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(sessionId: String? = nil) {
        _viewModel = StateObject(wrappedValue: ToolsViewModel(sessionId: sessionId))
    }
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with search and filters
                toolsHeader
                
                // Tools grid or list
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.filteredTools.isEmpty {
                    emptyStateView
                } else {
                    toolsContent
                }
            }
            .background(Theme.background)
            
            // Statistics overlay
            if showingStatistics {
                statisticsOverlay
            }
        }
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: Theme.Spacing.sm) {
                    // Statistics button
                    Button {
                        showingStatistics.toggle()
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    
                    // Refresh button
                    Button {
                        Task { await viewModel.refreshTools() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
            Button("Retry") {
                Task { await viewModel.loadTools() }
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Header
    private var toolsHeader: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.mutedFg)
                
                TextField("Search tools...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.foreground)
                
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.mutedFg)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.card)
            .cornerRadius(Theme.CornerRadius.md)
            
            // Category filter and sort
            HStack {
                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.categories, id: \.self) { category in
                            CategoryChip(
                                title: category,
                                isSelected: viewModel.selectedCategory == category
                            ) {
                                viewModel.selectedCategory = category
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Sort menu
                Menu {
                    ForEach(ToolsViewModel.SortOption.allCases, id: \.self) { option in
                        Button {
                            viewModel.sortOption = option
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if viewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.backgroundSecondary)
    }
    
    // MARK: - Content
    private var toolsContent: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 160), spacing: Theme.Spacing.md)
                ],
                spacing: Theme.Spacing.md
            ) {
                ForEach(viewModel.filteredTools) { tool in
                    ToolCard(
                        tool: tool,
                        onToggle: {
                            Task { await viewModel.toggleTool(tool) }
                        }
                    )
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading tools...")
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                .foregroundStyle(Theme.mutedFg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 60))
                .foregroundStyle(Theme.mutedFg.opacity(0.5))
            
            Text("No tools found")
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.lg, for: dynamicTypeSize)))
                .fontWeight(.semibold)
                .foregroundStyle(Theme.foreground)
            
            Text("Try adjusting your search or filters")
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                .foregroundStyle(Theme.mutedFg)
            
            Button {
                viewModel.searchText = ""
                viewModel.selectedCategory = "All"
            } label: {
                Text("Clear Filters")
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Statistics Overlay
    private var statisticsOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { showingStatistics = false }
            
            VStack(spacing: Theme.Spacing.lg) {
                HStack {
                    Text("Tool Statistics")
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xl, for: dynamicTypeSize)))
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button {
                        showingStatistics = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.mutedFg)
                    }
                }
                
                if let stats = viewModel.statistics {
                    StatisticsView(statistics: stats)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.card)
            .cornerRadius(Theme.CornerRadius.lg)
            .padding(Theme.Spacing.xl)
        }
    }
}

// MARK: - Tool Card
private struct ToolCard: View {
    let tool: MCPTool
    let onToggle: () -> Void
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header with icon and toggle
            HStack {
                Image(systemName: tool.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(tool.isEnabled ? Theme.neonCyan : Theme.mutedFg)
                
                Spacer()
                
                Toggle("", isOn: .constant(tool.isEnabled))
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .onTapGesture { onToggle() }
            }
            
            // Tool name
            Text(tool.name)
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                .fontWeight(.semibold)
                .foregroundStyle(Theme.foreground)
                .lineLimit(2)
            
            // Category badge
            Text(tool.category)
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 2)
                .background(Theme.primary.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.sm)
            
            // Usage stats
            if tool.usageCount > 0 {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12))
                    Text("\(tool.usageCount) uses")
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                }
                .foregroundStyle(Theme.mutedFg)
            }
            
            // Server indicator
            if let server = tool.server {
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(Theme.success)
                        .frame(width: 6, height: 6)
                    Text(server)
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                        .foregroundStyle(Theme.mutedFg)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tool.isEnabled ? Theme.card : Theme.card.opacity(0.6))
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(
                    tool.isEnabled ? Theme.primary.opacity(0.3) : Theme.border.opacity(0.2),
                    lineWidth: 1
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
    }
}

// MARK: - Statistics View
private struct StatisticsView: View {
    let statistics: ToolStatistics
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Summary cards
            HStack(spacing: Theme.Spacing.md) {
                StatCard(
                    title: "Total Tools",
                    value: "\(statistics.totalTools)",
                    icon: "wrench.and.screwdriver"
                )
                
                StatCard(
                    title: "Enabled",
                    value: "\(statistics.enabledTools)",
                    icon: "checkmark.circle"
                )
            }
            
            HStack(spacing: Theme.Spacing.md) {
                StatCard(
                    title: "Executions",
                    value: "\(statistics.totalExecutions)",
                    icon: "play.circle"
                )
                
                StatCard(
                    title: "Avg Time",
                    value: String(format: "%.2fs", statistics.avgExecutionTime),
                    icon: "timer"
                )
            }
            
            // Most used tool
            if let mostUsed = statistics.mostUsedTool {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Most Used Tool")
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                        .foregroundStyle(Theme.mutedFg)
                    
                    Text(mostUsed)
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.lg, for: dynamicTypeSize)))
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.neonCyan)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.md)
                .background(Theme.backgroundSecondary)
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
    }
}

// MARK: - Stat Card
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Theme.primary)
            
            Text(value)
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xl, for: dynamicTypeSize)))
                .fontWeight(.bold)
                .foregroundStyle(Theme.foreground)
            
            Text(title)
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                .foregroundStyle(Theme.mutedFg)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(Theme.backgroundSecondary)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Category Chip
private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Theme.foreground)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    isSelected ?
                    LinearGradient(
                        colors: [Theme.primary, Theme.neonCyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) : LinearGradient(
                        colors: [Theme.card, Theme.card],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(Theme.CornerRadius.full)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.full)
                        .stroke(isSelected ? Color.clear : Theme.border.opacity(0.3), lineWidth: 1)
                )
        }
    }
}