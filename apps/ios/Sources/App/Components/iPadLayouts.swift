import SwiftUI

// MARK: - iPad Layout Configuration

struct iPadLayoutConfiguration {
    static let sidebarMinWidth: CGFloat = 320
    static let sidebarIdealWidth: CGFloat = 400
    static let sidebarMaxWidth: CGFloat = 500
    
    static let detailMinWidth: CGFloat = 600
    static let detailIdealWidth: CGFloat = 800
    
    static let compactBreakpoint: CGFloat = 768
    static let regularBreakpoint: CGFloat = 1024
    static let largeBreakpoint: CGFloat = 1366
    
    static func columnsFor(width: CGFloat) -> Int {
        switch width {
        case ..<compactBreakpoint: return 1
        case ..<regularBreakpoint: return 2
        case ..<largeBreakpoint: return 3
        default: return 4
        }
    }
}

// MARK: - Adaptive Split View

struct AdaptiveSplitView<Sidebar: View, Detail: View, Secondary: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selectedItem: String?
    
    let sidebar: () -> Sidebar
    let detail: () -> Detail
    let secondary: (() -> Secondary)?
    
    init(
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder detail: @escaping () -> Detail,
        @ViewBuilder secondary: @escaping () -> Secondary
    ) {
        self.sidebar = sidebar
        self.detail = detail
        self.secondary = secondary
    }
    
    init(
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder detail: @escaping () -> Detail
    ) where Secondary == EmptyView {
        self.sidebar = sidebar
        self.detail = detail
        self.secondary = nil
    }
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                if let secondary = secondary {
                    // Three-column layout for larger iPads
                    NavigationSplitView(columnVisibility: $columnVisibility) {
                        sidebar()
                            .navigationSplitViewColumnWidth(
                                min: iPadLayoutConfiguration.sidebarMinWidth,
                                ideal: iPadLayoutConfiguration.sidebarIdealWidth,
                                max: iPadLayoutConfiguration.sidebarMaxWidth
                            )
                    } content: {
                        detail()
                            .navigationSplitViewColumnWidth(
                                min: iPadLayoutConfiguration.detailMinWidth,
                                ideal: iPadLayoutConfiguration.detailIdealWidth
                            )
                    } detail: {
                        secondary()
                    }
                    .navigationSplitViewStyle(.balanced)
                } else {
                    // Two-column layout for standard iPads
                    NavigationSplitView(columnVisibility: $columnVisibility) {
                        sidebar()
                            .navigationSplitViewColumnWidth(
                                min: iPadLayoutConfiguration.sidebarMinWidth,
                                ideal: iPadLayoutConfiguration.sidebarIdealWidth,
                                max: iPadLayoutConfiguration.sidebarMaxWidth
                            )
                    } detail: {
                        detail()
                    }
                    .navigationSplitViewStyle(.balanced)
                }
            } else {
                // iPhone layout
                NavigationStack {
                    sidebar()
                }
            }
        }
        .accessibilityElement(
            label: "Navigation",
            hint: UIDevice.current.userInterfaceIdiom == .pad ? 
                "Split view navigation with sidebar and detail" : 
                "Stack navigation"
        )
    }
}

// MARK: - Adaptive Grid Layout

struct AdaptiveGridLayout: Layout {
    var minItemWidth: CGFloat = 300
    var spacing: CGFloat = 16
    var alignment: Alignment = .topLeading
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? 0
        let columns = max(1, Int(containerWidth / minItemWidth))
        let itemWidth = (containerWidth - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            
            if currentX + itemWidth > containerWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            lineHeight = max(lineHeight, size.height)
            currentX += itemWidth + spacing
            totalHeight = currentY + lineHeight
        }
        
        return CGSize(width: containerWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let containerWidth = bounds.width
        let columns = max(1, Int(containerWidth / minItemWidth))
        let itemWidth = (containerWidth - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            
            if currentX + itemWidth > bounds.maxX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: itemWidth, height: size.height)
            )
            
            lineHeight = max(lineHeight, size.height)
            currentX += itemWidth + spacing
        }
    }
}

// MARK: - iPad Floating Panel

struct iPadFloatingPanel<Content: View>: View {
    @Binding var isPresented: Bool
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    
    let title: String
    let content: () -> Content
    
    var body: some View {
        if isPresented {
            VStack(spacing: 0) {
                // Panel Header
                HStack {
                    Text(title)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .accessibleButton(
                                label: "Close panel",
                                hint: "Dismiss the floating panel",
                                action: { isPresented = false }
                            )
                    }
                }
                .padding()
                .background(Theme.card)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation
                            isDragging = true
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                
                Divider()
                
                // Panel Content
                ScrollView {
                    content()
                        .padding()
                }
            }
            .frame(width: 400, height: 600)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .shadow(radius: isDragging ? 30 : 20)
            .offset(offset)
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
            .accessibilityElement(
                label: title,
                hint: "Floating panel. Swipe to move, double tap to close",
                traits: .isModal
            )
        }
    }
}

// MARK: - iPad Keyboard Navigation

struct KeyboardNavigationModifier: ViewModifier {
    @FocusState private var isFocused: Bool
    let onEnter: () -> Void
    let onEscape: (() -> Void)?
    let onArrowKeys: ((KeyboardArrow) -> Void)?
    
    enum KeyboardArrow {
        case up, down, left, right
    }
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onKeyPress(.return) {
                onEnter()
                return .handled
            }
            .onKeyPress(.escape) {
                onEscape?()
                return .handled
            }
            .onKeyPress(.upArrow) {
                onArrowKeys?(.up)
                return .handled
            }
            .onKeyPress(.downArrow) {
                onArrowKeys?(.down)
                return .handled
            }
            .onKeyPress(.leftArrow) {
                onArrowKeys?(.left)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                onArrowKeys?(.right)
                return .handled
            }
    }
}

extension View {
    func keyboardNavigation(
        onEnter: @escaping () -> Void,
        onEscape: (() -> Void)? = nil,
        onArrowKeys: ((KeyboardNavigationModifier.KeyboardArrow) -> Void)? = nil
    ) -> some View {
        self.modifier(KeyboardNavigationModifier(
            onEnter: onEnter,
            onEscape: onEscape,
            onArrowKeys: onArrowKeys
        ))
    }
}

// MARK: - iPad Multitasking Support

struct MultitaskingAdaptiveView<Content: View>: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let content: (MultitaskingMode) -> Content
    
    enum MultitaskingMode {
        case fullScreen
        case splitView
        case slideOver
        case compact
        
        var description: String {
            switch self {
            case .fullScreen: return "Full screen mode"
            case .splitView: return "Split view mode"
            case .slideOver: return "Slide over mode"
            case .compact: return "Compact mode"
            }
        }
    }
    
    private var currentMode: MultitaskingMode {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            return .compact
        }
        
        let screen = UIScreen.main
        let appBounds = UIApplication.shared.windows.first?.bounds ?? .zero
        
        if appBounds.width == screen.bounds.width {
            return .fullScreen
        } else if appBounds.width < 400 {
            return .slideOver
        } else {
            return .splitView
        }
    }
    
    var body: some View {
        content(currentMode)
            .accessibilityElement(
                label: "Layout",
                value: currentMode.description
            )
    }
}

// MARK: - iPad Toolbar Extensions

struct iPadToolbar<Content: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let content: () -> Content
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            HStack(spacing: 16) {
                content()
                    .buttonStyle(iPadToolbarButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Theme.card)
            .clipShape(Capsule())
            .shadow(radius: 4)
        } else {
            HStack {
                content()
            }
        }
    }
}

struct iPadToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Theme.primary.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}