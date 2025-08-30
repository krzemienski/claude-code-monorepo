import SwiftUI

// MARK: - Accessibility Extensions

public extension View {
    /// Enhanced accessibility label with automatic trait detection
    func accessibilityElement(
        label: String,
        value: String? = nil,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
    
    /// Create accessible button with proper traits
    func accessibleButton(
        label: String,
        hint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .onTapGesture(perform: action)
    }
    
    /// Add focus border for keyboard navigation
    func accessibilityFocusBorder(
        isFocused: Bool,
        color: Color = Theme.neonCyan
    ) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(color, lineWidth: isFocused ? 3 : 0)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        )
    }
    
    /// Dynamic Type support with min/max constraints
    func dynamicTypeAccessibility(
        minimumScaleFactor: CGFloat = 0.5,
        lineLimit: Int? = nil
    ) -> some View {
        self
            .minimumScaleFactor(minimumScaleFactor)
            .lineLimit(lineLimit)
    }
    
    /// High contrast mode support
    func highContrastCompatible(
        normalColor: Color,
        highContrastColor: Color
    ) -> some View {
        self.foregroundColor(
            UIAccessibility.isDarkerSystemColorsEnabled ? highContrastColor : normalColor
        )
    }
    
    /// Reduce motion support
    func reduceMotionCompatible<T: Equatable>(
        animation: Animation?,
        value: T
    ) -> some View {
        self.animation(
            UIAccessibility.isReduceMotionEnabled ? .none : animation,
            value: value
        )
    }
    
    /// Voice Control support
    func voiceControlCompatible(
        label: String,
        alternativeLabels: [String] = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityInputLabels([label] + alternativeLabels)
    }
    
    /// Announcement for screen readers
    func announceToVoiceOver(_ message: String, delay: Double = 0.1) -> some View {
        self.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: message
                )
            }
        }
    }
    
    /// Screen change notification for major updates
    func notifyScreenChange(delay: Double = 0.1) -> some View {
        self.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                UIAccessibility.post(
                    notification: .screenChanged,
                    argument: nil
                )
            }
        }
    }
    
    /// Layout change notification for minor updates
    func notifyLayoutChange(_ element: Any? = nil, delay: Double = 0.1) -> some View {
        self.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                UIAccessibility.post(
                    notification: .layoutChanged,
                    argument: element
                )
            }
        }
    }
}

// MARK: - Accessibility Container View

public struct AccessibleContainer<Content: View>: View {
    let label: String
    let role: AccessibilityRole
    let content: () -> Content
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    
    public init(
        label: String,
        role: AccessibilityRole = .none,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.role = role
        self.content = content
    }
    
    public var body: some View {
        content()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
            .accessibilityAddTraits(traitsForRole(role))
    }
    
    private func traitsForRole(_ role: AccessibilityRole) -> AccessibilityTraits {
        switch role {
        case .button: return .isButton
        case .link: return .isLink
        case .search: return [.isSearchField]
        case .image: return .isImage
        case .adjustable: return []  // adjustable trait not available in SwiftUI
        case .header: return .isHeader
        case .summary: return .isSummaryElement
        case .tabBar:
            if #available(iOS 17.0, *) {
                return .isTabBar
            } else {
                return []
            }
        case .none: return []
        @unknown default: return []
        }
    }
}

// MARK: - Accessibility Role

public enum AccessibilityRole {
    case button
    case link
    case search
    case image
    case adjustable
    case header
    case summary
    case tabBar
    case none
}

// MARK: - Accessibility Preferences

public struct AccessibilityPreferences {
    public static var shared = AccessibilityPreferences()
    
    public var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }
    
    public var isSwitchControlRunning: Bool {
        UIAccessibility.isSwitchControlRunning
    }
    
    public var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    public var isReduceTransparencyEnabled: Bool {
        UIAccessibility.isReduceTransparencyEnabled
    }
    
    public var isDarkerSystemColorsEnabled: Bool {
        UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    public var isBoldTextEnabled: Bool {
        UIAccessibility.isBoldTextEnabled
    }
    
    public var isGrayscaleEnabled: Bool {
        UIAccessibility.isGrayscaleEnabled
    }
    
    public var isInvertColorsEnabled: Bool {
        UIAccessibility.isInvertColorsEnabled
    }
    
    public var isMonoAudioEnabled: Bool {
        UIAccessibility.isMonoAudioEnabled
    }
    
    public var prefersCrossFadeTransitions: Bool {
        UIAccessibility.prefersCrossFadeTransitions
    }
    
    public var isVideoAutoplayEnabled: Bool {
        UIAccessibility.isVideoAutoplayEnabled
    }
    
    public var isSpeakScreenEnabled: Bool {
        UIAccessibility.isSpeakScreenEnabled
    }
    
    public var isSpeakSelectionEnabled: Bool {
        UIAccessibility.isSpeakSelectionEnabled
    }
    
    public var isShakeToUndoEnabled: Bool {
        UIAccessibility.isShakeToUndoEnabled
    }
    
    public var isAssistiveTouchRunning: Bool {
        UIAccessibility.isAssistiveTouchRunning
    }
    
    public var shouldDifferentiateWithoutColor: Bool {
        UIAccessibility.shouldDifferentiateWithoutColor
    }
    
    public var isOnOffSwitchLabelsEnabled: Bool {
        UIAccessibility.isOnOffSwitchLabelsEnabled
    }
}

// MARK: - Focus Management

public struct AppAccessibilityFocusState {
    @FocusState private var isFocused: Bool
    
    public mutating func focus() {
        isFocused = true
    }
    
    public mutating func unfocus() {
        isFocused = false
    }
    
    public var isCurrentlyFocused: Bool {
        isFocused
    }
}

// MARK: - Accessible Loading Indicator

public struct AccessibleLoadingIndicator: View {
    let message: String
    let progress: Double?
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var announcementTimer: Timer?
    @State private var lastAnnouncedProgress: Int = -1
    
    public init(message: String = "Loading", progress: Double? = nil) {
        self.message = message
        self.progress = progress
    }
    
    public var body: some View {
        Group {
            if let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .accessibilityLabel("\(message), \(Int(progress * 100)) percent complete")
                    .onChange(of: progress) { newValue in
                        announceProgressChange(newValue)
                    }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .accessibilityLabel("\(message), please wait")
            }
        }
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    private func announceProgressChange(_ progress: Double) {
        let currentProgress = Int(progress * 100)
        
        // Only announce at 25%, 50%, 75%, and 100%
        let milestones = [25, 50, 75, 100]
        
        for milestone in milestones {
            if currentProgress >= milestone && lastAnnouncedProgress < milestone {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "\(milestone) percent complete"
                )
                lastAnnouncedProgress = milestone
                break
            }
        }
    }
}

// MARK: - Accessible Error View

public struct AccessibleErrorView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(
        title: String = "Error",
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }
    
    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.error)
                .accessibilityHidden(true)
            
            Text(title)
                .font(.headline)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                .accessibilityAddTraits(.isHeader)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Double tap to retry the operation")
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .announceToVoiceOver("\(title). \(message)")
    }
}

// MARK: - Semantic HTML Role Mapping

public enum SemanticRole: String {
    case navigation = "navigation"
    case main = "main"
    case complementary = "complementary"
    case contentInfo = "contentinfo"
    case banner = "banner"
    case search = "search"
    case form = "form"
    case region = "region"
    case article = "article"
    case section = "section"
    
    var accessibilityTraits: AccessibilityTraits {
        switch self {
        case .navigation: 
            if #available(iOS 17.0, *) {
                return .isTabBar
            } else {
                return []
            }
        case .search: return .isSearchField
        default: return []
        }
    }
}

// MARK: - Keyboard Navigation Support

public struct KeyboardNavigatable: ViewModifier {
    @FocusState private var isFocused: Bool
    let onReturn: () -> Void
    let onEscape: (() -> Void)?
    
    public init(
        onReturn: @escaping () -> Void,
        onEscape: (() -> Void)? = nil
    ) {
        self.onReturn = onReturn
        self.onEscape = onEscape
    }
    
    public func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .focused($isFocused)
                .onKeyPress(.return) {
                    onReturn()
                    return .handled
                }
                .onKeyPress(.escape) {
                    onEscape?()
                    return .handled
                }
        } else {
            content
                .focused($isFocused)
                .accessibilityFocusBorder(isFocused: isFocused)
        }
    }
}

// MARK: - WCAG Compliance Helpers

public struct WCAGCompliance {
    /// Check if text color has sufficient contrast against background
    public static func checkContrast(
        text: UIColor,
        background: UIColor,
        level: WCAGLevel = .AA
    ) -> Bool {
        let ratio = contrastRatio(between: text, and: background)
        
        switch level {
        case .AA:
            return ratio >= 4.5 // Normal text
        case .AAA:
            return ratio >= 7.0 // Enhanced contrast
        case .AALarge:
            return ratio >= 3.0 // Large text (18pt+)
        case .AAALarge:
            return ratio >= 4.5 // Large text enhanced
        }
    }
    
    public enum WCAGLevel {
        case AA
        case AAA
        case AALarge
        case AAALarge
    }
    
    private static func contrastRatio(between color1: UIColor, and color2: UIColor) -> Double {
        let l1 = relativeLuminance(of: color1)
        let l2 = relativeLuminance(of: color2)
        
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    private static func relativeLuminance(of color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = red <= 0.03928 ? red / 12.92 : pow((red + 0.055) / 1.055, 2.4)
        let g = green <= 0.03928 ? green / 12.92 : pow((green + 0.055) / 1.055, 2.4)
        let b = blue <= 0.03928 ? blue / 12.92 : pow((blue + 0.055) / 1.055, 2.4)
        
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}