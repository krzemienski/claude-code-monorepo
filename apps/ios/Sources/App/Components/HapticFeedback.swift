import SwiftUI
import UIKit

// MARK: - Haptic Feedback Manager

public final class HapticManager {
    public static let shared = HapticManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    private init() {
        // Prepare generators for immediate use
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactSoft.prepare()
        impactRigid.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    // MARK: - Impact Feedback
    
    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .heavy:
            impactHeavy.impactOccurred()
        case .soft:
            impactSoft.impactOccurred()
        case .rigid:
            impactRigid.impactOccurred()
        @unknown default:
            impactMedium.impactOccurred()
        }
    }
    
    public func impactWithIntensity(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        switch style {
        case .light:
            impactLight.impactOccurred(intensity: intensity)
        case .medium:
            impactMedium.impactOccurred(intensity: intensity)
        case .heavy:
            impactHeavy.impactOccurred(intensity: intensity)
        case .soft:
            impactSoft.impactOccurred(intensity: intensity)
        case .rigid:
            impactRigid.impactOccurred(intensity: intensity)
        @unknown default:
            impactMedium.impactOccurred(intensity: intensity)
        }
    }
    
    // MARK: - Notification Feedback
    
    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
    }
    
    // MARK: - Selection Feedback
    
    public func selection() {
        selectionGenerator.selectionChanged()
    }
    
    // MARK: - Custom Patterns
    
    public func success() {
        notificationGenerator.notificationOccurred(.success)
    }
    
    public func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }
    
    public func error() {
        notificationGenerator.notificationOccurred(.error)
    }
    
    public func tap() {
        impact(.light)
    }
    
    public func doubleTap() {
        impact(.medium)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impact(.medium)
        }
    }
    
    public func longPress() {
        impact(.heavy)
    }
    
    public func swipe() {
        impact(.soft)
    }
    
    public func toggle() {
        selection()
    }
    
    public func refresh() {
        impact(.rigid)
    }
    
    // MARK: - Pattern Sequences
    
    public func pulse(count: Int = 3, interval: TimeInterval = 0.1) {
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + (interval * Double(i))) {
                self.impact(.soft)
            }
        }
    }
    
    public func ascending() {
        impact(.light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impact(.medium)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.impact(.heavy)
        }
    }
    
    public func descending() {
        impact(.heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impact(.medium)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.impact(.light)
        }
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Add haptic feedback to any interaction
    public func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.onTapGesture {
            HapticManager.shared.impact(style)
        }
    }
    
    /// Add haptic feedback to button taps
    public func hapticButton(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    HapticManager.shared.impact(style)
                }
        )
    }
    
    /// Add haptic feedback on appear
    public func hapticOnAppear(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) -> some View {
        self.onAppear {
            HapticManager.shared.impact(style)
        }
    }
    
    /// Add haptic feedback on disappear
    public func hapticOnDisappear(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) -> some View {
        self.onDisappear {
            HapticManager.shared.impact(style)
        }
    }
    
    /// Add haptic feedback to navigation
    public func hapticNavigation() -> some View {
        self
            .hapticOnAppear(.soft)
            .hapticOnDisappear(.light)
    }
    
    /// Add haptic feedback to toggles
    public func hapticToggle() -> some View {
        self.onChange(of: true as Bool) { _ in
            HapticManager.shared.toggle()
        }
    }
    
    /// Add haptic feedback to long press
    public func hapticLongPress(minimumDuration: Double = 0.5) -> some View {
        self.onLongPressGesture(minimumDuration: minimumDuration) {
            HapticManager.shared.longPress()
        }
    }
    
    /// Add haptic feedback to swipe
    public func hapticSwipe() -> some View {
        self.onTapGesture {
            HapticManager.shared.swipe()
        }
    }
    
    /// Add success haptic feedback
    public func hapticSuccess() -> some View {
        self.onTapGesture {
            HapticManager.shared.success()
        }
    }
    
    /// Add warning haptic feedback
    public func hapticWarning() -> some View {
        self.onTapGesture {
            HapticManager.shared.warning()
        }
    }
    
    /// Add error haptic feedback
    public func hapticError() -> some View {
        self.onTapGesture {
            HapticManager.shared.error()
        }
    }
    
    /// Add refresh haptic feedback
    public func hapticRefresh() -> some View {
        self.onTapGesture {
            HapticManager.shared.refresh()
        }
    }
}

// MARK: - Haptic Button Style

struct HapticButtonStyle: ButtonStyle {
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    let scaleAmount: CGFloat
    
    init(
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        scaleAmount: CGFloat = 0.95
    ) {
        self.hapticStyle = hapticStyle
        self.scaleAmount = scaleAmount
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed {
                    HapticManager.shared.impact(hapticStyle)
                }
            }
    }
}

// MARK: - Haptic Toggle Style

struct HapticToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
            HapticManager.shared.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                ZStack {
                    Capsule()
                        .fill(configuration.isOn ? Theme.primary : Theme.secondary)
                        .frame(width: 50, height: 30)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Contextual Haptic Feedback

public struct HapticContext {
    public static func navigationForward() {
        HapticManager.shared.impact(.soft)
    }
    
    public static func navigationBack() {
        HapticManager.shared.impact(.light)
    }
    
    public static func pullToRefresh() {
        HapticManager.shared.refresh()
    }
    
    public static func sendMessage() {
        HapticManager.shared.impact(.medium)
    }
    
    public static func receiveMessage() {
        HapticManager.shared.impact(.soft)
    }
    
    public static func startLoading() {
        HapticManager.shared.impact(.light)
    }
    
    public static func stopLoading() {
        HapticManager.shared.impact(.soft)
    }
    
    public static func expand() {
        HapticManager.shared.ascending()
    }
    
    public static func collapse() {
        HapticManager.shared.descending()
    }
    
    public static func delete() {
        HapticManager.shared.impact(.heavy)
    }
    
    public static func archive() {
        HapticManager.shared.impact(.medium)
    }
}