import SwiftUI

/// QuickActionsComponent - Grid of quick action buttons
public struct QuickActionsComponent: View {
    let actions: [QuickAction]
    let columns: Int
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    public init(actions: [QuickAction], columns: Int? = nil) {
        self.actions = actions
        self.columns = columns ?? (horizontalSizeClass == .regular ? 4 : 2)
    }
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Quick Actions", systemImage: "square.grid.2x2")
                .font(.headline)
                .foregroundStyle(Theme.primary)
                .accessibilityAddTraits(.isHeader)
            
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(actions) { action in
                    QuickActionButton(action: action)
                }
            }
        }
    }
}

// MARK: - Quick Action Model
public struct QuickAction: Identifiable {
    public let id = UUID()
    public let title: String
    public let icon: String
    public let color: Color
    public let badge: String?
    public let action: () -> Void
    
    public init(
        title: String,
        icon: String,
        color: Color = Theme.primary,
        badge: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.badge = badge
        self.action = action
    }
}

// MARK: - Quick Action Button
private struct QuickActionButton: View {
    let action: QuickAction
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action.action()
            }
        }) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    // Icon Container
                    ZStack {
                        Circle()
                            .fill(action.color.opacity(0.1))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: action.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(action.color)
                    }
                    
                    // Badge
                    if let badge = action.badge {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                            )
                            .offset(x: 8, y: -4)
                    }
                }
                
                Text(action.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isHovered ? Theme.secondaryBackground : Theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        action.color.opacity(isHovered ? 0.3 : 0.1),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
            .animation(.easeInOut(duration: 0.2), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(action.title)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(action.badge ?? "")
    }
}

// MARK: - Preview Provider
struct QuickActionsComponent_Previews: PreviewProvider {
    static let mockActions = [
        QuickAction(
            title: "New Session",
            icon: "plus.bubble",
            color: .blue,
            action: {}
        ),
        QuickAction(
            title: "Browse Files",
            icon: "folder",
            color: .orange,
            badge: "12",
            action: {}
        ),
        QuickAction(
            title: "Settings",
            icon: "gearshape",
            color: .gray,
            action: {}
        ),
        QuickAction(
            title: "Analytics",
            icon: "chart.bar",
            color: .green,
            badge: "New",
            action: {}
        )
    ]
    
    static var previews: some View {
        Group {
            QuickActionsComponent(actions: mockActions, columns: 2)
                .previewDisplayName("2 Columns")
            
            QuickActionsComponent(actions: mockActions, columns: 4)
                .previewDisplayName("4 Columns")
                .previewDevice("iPad Pro (11-inch)")
            
            QuickActionsComponent(actions: Array(mockActions.prefix(2)))
                .previewDisplayName("Minimal")
        }
        .padding()
        .background(Color(.systemBackground))
    }
}