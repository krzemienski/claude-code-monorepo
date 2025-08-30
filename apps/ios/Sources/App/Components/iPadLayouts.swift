import SwiftUI

// MARK: - iPad Layout Configuration

struct iPadLayoutConfiguration {
    // iPad Model-Specific Optimizations
    enum iPadModel {
        case mini        // 8.3" - 744 x 1133 points
        case regular     // 10.2" - 810 x 1080 points
        case air         // 10.9" - 820 x 1180 points
        case pro11       // 11" - 834 x 1194 points
        case pro12_9     // 12.9" - 1024 x 1366 points
        
        static func current(width: CGFloat) -> iPadModel {
            switch width {
            case ..<760: return .mini
            case ..<820: return .regular
            case ..<830: return .air
            case ..<1000: return .pro11
            default: return .pro12_9
            }
        }
        
        var sidebarConfig: (min: CGFloat, ideal: CGFloat, max: CGFloat) {
            switch self {
            case .mini:
                return (280, 320, 380)
            case .regular:
                return (300, 360, 420)
            case .air:
                return (320, 380, 450)
            case .pro11:
                return (340, 400, 480)
            case .pro12_9:
                return (380, 450, 550)
            }
        }
        
        var detailConfig: (min: CGFloat, ideal: CGFloat) {
            switch self {
            case .mini:
                return (400, 500)
            case .regular:
                return (450, 600)
            case .air:
                return (500, 650)
            case .pro11:
                return (550, 700)
            case .pro12_9:
                return (650, 850)
            }
        }
    }
    
    // Multitasking Support
    enum MultitaskingMode: Equatable {
        case fullScreen
        case splitView(ratio: CGFloat)  // 0.5 = half, 0.33 = one-third
        case slideOver
        
        static func detect(screenWidth: CGFloat, windowWidth: CGFloat) -> MultitaskingMode {
            let ratio = windowWidth / screenWidth
            
            if ratio > 0.9 {
                return .fullScreen
            } else if ratio > 0.6 {
                return .splitView(ratio: ratio)
            } else if ratio > 0.4 {
                return .splitView(ratio: 0.5)
            } else if ratio > 0.3 {
                return .splitView(ratio: 0.33)
            } else {
                return .slideOver
            }
        }
    }
    
    static let compactBreakpoint: CGFloat = 768
    static let regularBreakpoint: CGFloat = 1024
    static let largeBreakpoint: CGFloat = 1366
    
    static func columnsFor(width: CGFloat, multitaskingMode: MultitaskingMode) -> Int {
        switch multitaskingMode {
        case .fullScreen:
            switch width {
            case ..<compactBreakpoint: return 1
            case ..<regularBreakpoint: return 2
            case ..<largeBreakpoint: return 3
            default: return 3  // Max 3 columns for better readability
            }
        case .splitView(let ratio):
            // Reduce columns in split view based on available space
            if ratio > 0.6 {
                return width < regularBreakpoint ? 1 : 2
            } else {
                return 1  // Always single column in narrow split
            }
        case .slideOver:
            return 1  // Always single column in slide over
        }
    }
}

// MARK: - Adaptive Split View

struct AdaptiveSplitView<Sidebar: View, Detail: View, Secondary: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selectedItem: String?
    @State private var currentOrientation = UIDevice.current.orientation
    @State private var multitaskingMode: iPadLayoutConfiguration.MultitaskingMode = .fullScreen
    
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
        GeometryReader { geometry in
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    iPadLayout(geometry: geometry)
                } else {
                    // iPhone layout
                    NavigationStack {
                        sidebar()
                    }
                }
            }
            .onAppear {
                detectMultitaskingMode(geometry: geometry)
            }
            .onChange(of: geometry.size) { _ in
                detectMultitaskingMode(geometry: geometry)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentOrientation = UIDevice.current.orientation
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
    
    @ViewBuilder
    private func iPadLayout(geometry: GeometryProxy) -> some View {
        let iPadModel = iPadLayoutConfiguration.iPadModel.current(width: geometry.size.width)
        let sidebarConfig = iPadModel.sidebarConfig
        let detailConfig = iPadModel.detailConfig
        
        // Adjust column visibility based on multitasking mode
        let shouldShowAllColumns = multitaskingMode == .fullScreen && geometry.size.width > iPadLayoutConfiguration.regularBreakpoint
        
        if let secondary = secondary, shouldShowAllColumns {
            // Three-column layout for larger iPads in full screen
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebar()
                    .navigationSplitViewColumnWidth(
                        min: sidebarConfig.min,
                        ideal: sidebarConfig.ideal,
                        max: sidebarConfig.max
                    )
            } content: {
                detail()
                    .navigationSplitViewColumnWidth(
                        min: detailConfig.min,
                        ideal: detailConfig.ideal
                    )
            } detail: {
                secondary()
            }
            .navigationSplitViewStyle(.automatic)
        } else {
            // Two-column layout for standard iPads or multitasking
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebar()
                    .navigationSplitViewColumnWidth(
                        min: adjustForMultitasking(sidebarConfig.min),
                        ideal: adjustForMultitasking(sidebarConfig.ideal),
                        max: adjustForMultitasking(sidebarConfig.max)
                    )
            } detail: {
                detail()
            }
            .navigationSplitViewStyle(.automatic)
        }
    }
    
    private func detectMultitaskingMode(geometry: GeometryProxy) {
        let screenWidth = UIScreen.main.bounds.width
        let windowWidth = geometry.size.width
        multitaskingMode = iPadLayoutConfiguration.MultitaskingMode.detect(
            screenWidth: screenWidth,
            windowWidth: windowWidth
        )
    }
    
    private func adjustForMultitasking(_ value: CGFloat) -> CGFloat {
        switch multitaskingMode {
        case .fullScreen:
            return value
        case .splitView(let ratio):
            return value * ratio
        case .slideOver:
            return value * 0.8  // Reduce sizes for slide over
        }
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
        if #available(iOS 17.0, *) {
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
        } else {
            // Fallback for iOS 16.0 - keyboard navigation not available
            content
                .focused($isFocused)
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