import SwiftUI

// MARK: - Dynamic Type Font Scaling
public extension Font {
    /// Creates a scalable font that respects Dynamic Type
    static func scalableFont(_ style: Font.TextStyle, size: CGFloat? = nil) -> Font {
        if let size = size {
            return .system(size: size, design: .default)
        }
        return Font.system(style)
    }
}

public extension View {
    /// Applies Dynamic Type scaling to any font
    func applyDynamicTypeSize() -> some View {
        self.modifier(DynamicTypeSizeModifier())
    }
}

struct DynamicTypeSizeModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(dynamicTypeSize.uiScale)
    }
}

extension DynamicTypeSize {
    var uiScale: CGFloat {
        switch self {
        case .xSmall: return 0.8
        case .small: return 0.85
        case .medium: return 0.9
        case .large: return 1.0
        case .xLarge: return 1.1
        case .xxLarge: return 1.2
        case .xxxLarge: return 1.3
        case .accessibility1: return 1.4
        case .accessibility2: return 1.5
        case .accessibility3: return 1.6
        case .accessibility4: return 1.7
        case .accessibility5: return 1.8
        @unknown default: return 1.0
        }
    }
}

// MARK: - Adaptive Stack Layout
public struct AdaptiveStack<Content: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var horizontalAlignment: HorizontalAlignment = .center
    var verticalAlignment: VerticalAlignment = .center
    var spacing: CGFloat? = nil
    @ViewBuilder var content: () -> Content
    
    public init(
        horizontalAlignment: HorizontalAlignment = .center,
        verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content
    }
    
    public var body: some View {
        if horizontalSizeClass == .compact || verticalSizeClass == .compact {
            VStack(alignment: horizontalAlignment, spacing: spacing, content: content)
        } else {
            HStack(alignment: verticalAlignment, spacing: spacing, content: content)
        }
    }
}

// MARK: - Adaptive Padding
public extension View {
    /// Applies adaptive padding based on device and size class
    func adaptivePadding(_ edges: Edge.Set = .all, _ amount: CGFloat? = nil) -> some View {
        self.modifier(AdaptivePaddingModifier(edges: edges, amount: amount))
    }
}

struct AdaptivePaddingModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    let edges: Edge.Set
    let amount: CGFloat?
    
    func body(content: Content) -> some View {
        let padding = computePadding()
        return content.padding(edges, padding)
    }
    
    private func computePadding() -> CGFloat {
        let baseAmount = amount ?? Theme.Spacing.md
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            return baseAmount * 1.5
        } else if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return baseAmount * 1.2
        } else {
            return baseAmount
        }
    }
}

// MARK: - Touch Target Enforcement
public extension View {
    /// Ensures minimum touch target size (default 44pt)
    func ensureAccessibleTouchTarget(minSize: CGFloat = 44) -> some View {
        self.modifier(TouchTargetModifier(minSize: minSize))
    }
}

struct TouchTargetModifier: ViewModifier {
    let minSize: CGFloat
    
    func body(content: Content) -> some View {
        content
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
}

// MARK: - Enhanced Loading Components
public struct LoadingOverlay: View {
    let message: String
    let progress: Double?
    @State private var rotation: Double = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init(message: String = "Loading...", progress: Double? = nil) {
        self.message = message
        self.progress = progress
    }
    
    public var body: some View {
        ZStack {
            // Background blur
            Theme.background
                .opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Loading indicator
                if let progress = progress {
                    // Determinate progress
                    ProgressView(value: progress)
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                        .scaleEffect(1.5)
                } else {
                    // Indeterminate spinner
                    Image(systemName: "arrow.2.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.primary, Theme.primary.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .rotationEffect(.degrees(rotation))
                        .animation(
                            reduceMotion ? nil :
                            Animation.linear(duration: 1)
                                .repeatForever(autoreverses: false),
                            value: rotation
                        )
                }
                
                Text(message)
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)
                
                if progress != nil {
                    Text("\(Int((progress ?? 0) * 100))%")
                        .font(.caption)
                        .foregroundStyle(Theme.mutedFg)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.card)
                    .shadow(color: Theme.primary.opacity(0.3), radius: 20)
            )
        }
        .accessibilityElement(
            label: message,
            hint: progress != nil ? "Loading \(Int((progress ?? 0) * 100)) percent complete" : nil,
            traits: .updatesFrequently
        )
        .onAppear {
            if !reduceMotion && progress == nil {
                rotation = 360
            }
        }
    }
}

// MARK: - Skeleton Loading View
public struct SkeletonView: View {
    let height: CGFloat
    @State private var shimmerOffset: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init(height: CGFloat = 20) {
        self.height = height
    }
    
    public var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Theme.card)
            .frame(height: height)
            .overlay(
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.card,
                                    Theme.card.opacity(0.4),
                                    Theme.card
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset * geometry.size.width)
                        .animation(
                            reduceMotion ? nil :
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: shimmerOffset
                        )
                }
            )
            .onAppear {
                if !reduceMotion {
                    shimmerOffset = 2
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Pull to Refresh Indicator
public struct PullToRefreshIndicator: View {
    let isRefreshing: Bool
    @State private var rotation: Double = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init(isRefreshing: Bool) {
        self.isRefreshing = isRefreshing
    }
    
    public var body: some View {
        HStack {
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                Text("Refreshing...")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
                    .rotationEffect(.degrees(rotation))
                Text("Pull to refresh")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
            }
        }
        .padding(.vertical, 8)
        .animation(.easeInOut, value: isRefreshing)
        .onChange(of: isRefreshing) { refreshing in
            if refreshing && !reduceMotion {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                rotation = 0
            }
        }
        .accessibilityElement(
            label: isRefreshing ? "Refreshing content" : "Pull to refresh",
            traits: isRefreshing ? .updatesFrequently : []
        )
    }
}

// MARK: - Animated Success/Failure Icons
public struct StatusIcon: View {
    public enum Status {
        case success, failure, warning, info
        
        var systemName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success: return .green
            case .failure: return .red
            case .warning: return .orange
            case .info: return Theme.primary
            }
        }
    }
    
    let status: Status
    let size: CGFloat
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init(status: Status, size: CGFloat = 60) {
        self.status = status
        self.size = size
    }
    
    public var body: some View {
        Image(systemName: status.systemName)
            .font(.system(size: size))
            .foregroundStyle(status.color)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                if reduceMotion {
                    scale = 1
                    opacity = 1
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        scale = 1
                        opacity = 1
                    }
                    
                    // Haptic feedback
                    switch status {
                    case .success:
                        HapticManager.shared.success()
                    case .failure:
                        HapticManager.shared.error()
                    case .warning:
                        HapticManager.shared.warning()
                    case .info:
                        HapticManager.shared.impact(.light)
                    }
                }
            }
            .accessibilityElement(
                label: "\(status) status",
                traits: .isImage
            )
    }
}

// MARK: - Orientation Support
public struct OrientationAwareView<Portrait: View, Landscape: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    let portrait: () -> Portrait
    let landscape: () -> Landscape
    
    public init(
        @ViewBuilder portrait: @escaping () -> Portrait,
        @ViewBuilder landscape: @escaping () -> Landscape
    ) {
        self.portrait = portrait
        self.landscape = landscape
    }
    
    public var body: some View {
        Group {
            if verticalSizeClass == .regular && horizontalSizeClass == .compact {
                // Portrait
                portrait()
            } else {
                // Landscape or iPad
                landscape()
            }
        }
    }
}

// MARK: - Multitasking Support
public struct MultitaskingAwareView<Content: View>: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let content: () -> Content
    @State private var isInSplitView = false
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    public var body: some View {
        GeometryReader { geometry in
            content()
                .onChange(of: geometry.size) { newSize in
                    // Detect split view by checking if width is less than full iPad width
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        isInSplitView = newSize.width < UIScreen.main.bounds.width * 0.7
                    }
                }
                .environment(\.isInSplitView, isInSplitView)
        }
    }
}

// MARK: - Environment Key for Split View
private struct IsInSplitViewKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var isInSplitView: Bool {
        get { self[IsInSplitViewKey.self] }
        set { self[IsInSplitViewKey.self] = newValue }
    }
}

// MARK: - Animated Placeholder
public struct AnimatedPlaceholder: View {
    let text: String
    @State private var opacity: Double = 0.3
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init(_ text: String) {
        self.text = text
    }
    
    public var body: some View {
        Text(text)
            .foregroundStyle(Theme.mutedFg)
            .opacity(opacity)
            .animation(
                reduceMotion ? nil :
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                value: opacity
            )
            .onAppear {
                if !reduceMotion {
                    opacity = 1
                }
            }
    }
}

// MARK: - Progress Bar with Animation
public struct EnhancedProgressBar: View {
    let progress: Double
    let color: Color
    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init(progress: Double, color: Color = Theme.primary) {
        self.progress = min(max(progress, 0), 1) // Clamp between 0 and 1
        self.color = color
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.card)
                    .frame(height: 8)
                
                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * animatedProgress, height: 8)
                    .animation(
                        reduceMotion ? nil :
                        .spring(response: 0.5, dampingFraction: 0.8),
                        value: animatedProgress
                    )
            }
        }
        .frame(height: 8)
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { newProgress in
            animatedProgress = newProgress
            
            // Haptic feedback on completion
            if newProgress >= 1.0 {
                HapticManager.shared.success()
            }
        }
        .accessibilityElement(
            label: "Progress",
            value: "\(Int(progress * 100)) percent"
        )
    }
}

// MARK: - Accessibility Extensions

public extension View {
    /// Announces screen changes to VoiceOver
    func accessibilityScreenChanged() -> some View {
        self.onAppear {
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }
    
    /// Creates an accessible navigation link
    func accessibleNavigationLink(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityAddTraits(.isLink)
    }
    
    /// Applies animation with reduced motion support
    func reducedMotionAnimation<V: Hashable>(
        _ animation: Animation?,
        value: V
    ) -> some View {
        self.modifier(ReducedMotionAnimationModifier(animation: animation, value: value))
    }
    
    /// Sets accessibility status description
    func accessibleStatus(
        _ status: String
    ) -> some View {
        self.accessibilityValue(status)
    }
    
    /// Ensures minimum touch target size for accessibility
    func accessibleTouchTarget(minSize: CGFloat = 44) -> some View {
        self.frame(minWidth: minSize, minHeight: minSize)
    }
}

// MARK: - Reduced Motion Animation Modifier

struct ReducedMotionAnimationModifier<V: Hashable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    let value: V
    
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.animation(animation, value: value)
        }
    }
}