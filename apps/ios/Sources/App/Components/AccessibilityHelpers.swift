import SwiftUI
import Combine

// MARK: - Accessibility Settings Observer

class AccessibilitySettings: ObservableObject {
    @Published var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    @Published var isDynamicTypeEnabled = UIApplication.shared.preferredContentSizeCategory != .large
    @Published var isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    @Published var isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
    @Published var isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
    @Published var preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
            .sink { [weak self] _ in
                self?.preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
                self?.isDynamicTypeEnabled = UIApplication.shared.preferredContentSizeCategory != .large
            }
            .store(in: &cancellables)
    }
}

// MARK: - Accessibility View Modifiers

extension View {
    /// Adds comprehensive accessibility support
    func accessibilityElement(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityValue(value ?? "")
    }
    
    /// Adaptive layout modifier for iPad
    func adaptiveFrame(
        minWidth: CGFloat? = nil,
        idealWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        idealHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil
    ) -> some View {
        let idiom = UIDevice.current.userInterfaceIdiom
        let multiplier: CGFloat = idiom == .pad ? 1.3 : 1.0
        
        return self.frame(
            minWidth: minWidth.map { $0 * multiplier },
            idealWidth: idealWidth.map { $0 * multiplier },
            maxWidth: maxWidth.map { $0 * multiplier },
            minHeight: minHeight.map { $0 * multiplier },
            idealHeight: idealHeight.map { $0 * multiplier },
            maxHeight: maxHeight.map { $0 * multiplier }
        )
    }
    
    /// Adaptive padding for different device sizes
    func adaptivePadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        let spacing = length ?? Theme.Spacing.md
        let adaptiveSpacing = Theme.Spacing.adaptive(spacing)
        return self.padding(edges, adaptiveSpacing)
    }
    
    /// Dynamic type support for text
    func dynamicTypeSize() -> some View {
        self.dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }
    
    /// Interactive element with proper accessibility
    func accessibleButton(
        label: String,
        hint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        self
            .onTapGesture(perform: action)
            .accessibilityElement(
                label: label,
                hint: hint,
                traits: .isButton
            )
    }
    
    /// Navigation link with accessibility
    func accessibleNavigationLink(
        label: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityElement(
                label: label,
                hint: hint ?? "Double tap to navigate",
                traits: [.isLink, .isButton]
            )
    }
    
    /// Header with accessibility
    func accessibleHeader(label: String) -> some View {
        self
            .accessibilityElement(
                label: label,
                traits: .isHeader
            )
    }
    
    /// Status indicator with accessibility
    func accessibleStatus(
        label: String,
        value: String,
        isUpdating: Bool = false
    ) -> some View {
        self
            .accessibilityElement(
                label: label,
                traits: isUpdating ? [.updatesFrequently] : [],
                value: value
            )
    }
}

// MARK: - Adaptive Layout Helpers

struct AdaptiveStack<Content: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        let isCompact = horizontalSizeClass == .compact
        let isLargeText = dynamicTypeSize >= .accessibility1
        
        if isCompact || isLargeText {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                content()
            }
        } else {
            HStack(spacing: Theme.Spacing.lg) {
                content()
            }
        }
    }
}

struct AdaptiveGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let content: () -> Content
    
    var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible()), count: count)
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.adaptive(Theme.Spacing.lg)) {
            content()
        }
    }
}

// MARK: - iPad Split View Helper

struct AdaptiveNavigationView<Sidebar: View, Detail: View>: View {
    let sidebar: () -> Sidebar
    let detail: () -> Detail
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                sidebar()
                    .navigationSplitViewColumnWidth(
                        min: 320,
                        ideal: 400,
                        max: 500
                    )
            } detail: {
                detail()
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack {
                sidebar()
            }
        }
    }
}

// MARK: - Focus Management

struct FocusableModifier: ViewModifier {
    @FocusState private var isFocused: Bool
    let label: String
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .accessibilityElement(
                label: label,
                traits: isFocused ? [.isSelected] : []
            )
    }
}

extension View {
    func focusableAccessibility(label: String) -> some View {
        self.modifier(FocusableModifier(label: label))
    }
}

// MARK: - Voice Control Support

extension View {
    func voiceControlLabel(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityInputLabels([label])
    }
    
    /// VoiceOver custom actions support
    func accessibilityCustomActions(_ actions: [AccessibilityCustomAction]) -> some View {
        self.accessibilityElement(children: .combine)
            .accessibilityActions {
                ForEach(actions, id: \.self) { action in
                    Button(action.name) {
                        action.handler()
                    }
                }
            }
    }
    
    /// VoiceOver rotor support
    func accessibilityRotor<Content>(
        _ label: String,
        entries: [String],
        @ViewBuilder content: @escaping (String) -> Content
    ) -> some View where Content: View {
        self.accessibilityRotor(label) {
            ForEach(entries, id: \.self) { entry in
                AccessibilityRotorEntry(entry, id: entry)
            }
        }
    }
}

// MARK: - Accessibility Custom Action

struct AccessibilityCustomAction: Hashable {
    let id = UUID()
    let name: String
    let handler: () -> Void
    
    static func == (lhs: AccessibilityCustomAction, rhs: AccessibilityCustomAction) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Semantic Content

struct SemanticContent: ViewModifier {
    let role: AccessibilityRole
    let label: String
    let importance: AccessibilityImportance
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityAddTraits(traitsForRole(role))
            .accessibilitySortPriority(importance == .high ? 1 : 0)
    }
    
    private func traitsForRole(_ role: AccessibilityRole) -> AccessibilityTraits {
        switch role {
        case .button: return .isButton
        case .link: return [.isLink, .isButton]
        case .search: return .isSearchField
        case .image: return .isImage
        case .text: return .isStaticText
        case .header: return .isHeader
        case .summary: return .isSummaryElement
        @unknown default: return []
        }
    }
}

enum AccessibilityRole {
    case button, link, search, image, text, header, summary
}

enum AccessibilityImportance {
    case high, normal, low
}

extension View {
    func semanticContent(
        role: AccessibilityRole,
        label: String,
        importance: AccessibilityImportance = .normal
    ) -> some View {
        self.modifier(SemanticContent(role: role, label: label, importance: importance))
    }
    
    /// Reduce motion support
    func reducedMotionAnimation<V>(
        _ animation: Animation?,
        value: V
    ) -> some View where V: Equatable {
        @Environment(\.accessibilityReduceMotion) var reduceMotion
        return self.animation(reduceMotion ? .none : animation, value: value)
    }
    
    /// High contrast color support
    func highContrastColor(
        normal: Color,
        highContrast: Color
    ) -> some View {
        @Environment(\.colorSchemeContrast) var contrast
        return self.foregroundColor(contrast == .increased ? highContrast : normal)
    }
    
    /// Minimum touch target size for accessibility (44x44 points)
    func accessibleTouchTarget(minSize: CGFloat = 44) -> some View {
        self.frame(minWidth: minSize, minHeight: minSize)
    }
    
    /// Scalable font for Dynamic Type
    func scalableFont(_ font: Font, minSize: CGFloat? = nil, maxSize: CGFloat? = nil) -> some View {
        @Environment(\.sizeCategory) var sizeCategory
        
        // For dynamic type support, we'll use the font directly
        // The system automatically handles dynamic type scaling
        return self.font(font)
    }
    
    /// Accessibility announcement
    func accessibilityAnnouncement(_ text: String, delay: Double = 0.1) -> some View {
        self.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                UIAccessibility.post(notification: .announcement, argument: text)
            }
        }
    }
    
    /// Accessibility screen change notification
    func accessibilityScreenChanged() -> some View {
        self.onAppear {
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }
}