import SwiftUI
import Combine

// MARK: - Orientation Handler

/// Manages device orientation changes and provides smooth transition support
public class OrientationHandler: ObservableObject {
    @Published var orientation: UIDeviceOrientation = UIDevice.current.orientation
    @Published var isLandscape: Bool = false
    @Published var isPortrait: Bool = true
    @Published var isTransitioning: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var transitionTimer: Timer?
    
    public init() {
        setupOrientationObserver()
        updateOrientation()
    }
    
    private func setupOrientationObserver() {
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleOrientationChange()
            }
            .store(in: &cancellables)
        
        // Also observe app becoming active to check orientation
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.updateOrientation()
            }
            .store(in: &cancellables)
    }
    
    private func handleOrientationChange() {
        // Mark as transitioning
        isTransitioning = true
        
        // Cancel any existing timer
        transitionTimer?.invalidate()
        
        // Update orientation
        updateOrientation()
        
        // Set a timer to mark transition as complete
        transitionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.isTransitioning = false
            }
        }
    }
    
    private func updateOrientation() {
        let currentOrientation = UIDevice.current.orientation
        
        // Only update if it's a valid orientation
        guard currentOrientation.isValidInterfaceOrientation else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            orientation = currentOrientation
            isLandscape = currentOrientation.isLandscape
            isPortrait = currentOrientation.isPortrait
        }
    }
}

// MARK: - Orientation-Aware View Modifier

public struct OrientationAwareModifier: ViewModifier {
    @StateObject private var orientationHandler = OrientationHandler()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    let onOrientationChange: ((UIDeviceOrientation, Bool) -> Void)?
    
    public func body(content: Content) -> some View {
        content
            .environmentObject(orientationHandler)
            .onChange(of: orientationHandler.orientation) { newOrientation in
                onOrientationChange?(newOrientation, orientationHandler.isTransitioning)
            }
            .overlay(
                // Transition overlay for smooth animations
                Group {
                    if orientationHandler.isTransitioning {
                        Color.clear
                            .background(.ultraThinMaterial)
                            .opacity(0.01) // Nearly invisible but helps with transition
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
            )
    }
}

// MARK: - Convenience Extensions

public extension View {
    /// Adds orientation awareness to the view
    func orientationAware(
        onOrientationChange: ((UIDeviceOrientation, Bool) -> Void)? = nil
    ) -> some View {
        self.modifier(OrientationAwareModifier(onOrientationChange: onOrientationChange))
    }
    
    /// Applies different layouts based on orientation
    @ViewBuilder
    func orientationLayout<Portrait: View, Landscape: View>(
        @ViewBuilder portrait: @escaping () -> Portrait,
        @ViewBuilder landscape: @escaping () -> Landscape
    ) -> some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                landscape()
            } else {
                portrait()
            }
        }
    }
}

// MARK: - iPad-Specific Orientation Support

public struct iPadOrientationLayout<Content: View>: View {
    @EnvironmentObject private var orientationHandler: OrientationHandler
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    let content: (UIDeviceOrientation, Bool) -> Content
    
    public init(@ViewBuilder content: @escaping (UIDeviceOrientation, Bool) -> Content) {
        self.content = content
    }
    
    public var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                GeometryReader { geometry in
                    content(orientationHandler.orientation, orientationHandler.isTransitioning)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .animation(
                            orientationHandler.isTransitioning ? .easeInOut(duration: 0.3) : .none,
                            value: orientationHandler.orientation
                        )
                }
            } else {
                // iPhone doesn't need special handling
                content(.portrait, false)
            }
        }
    }
}

// MARK: - Adaptive Column Count

public struct AdaptiveColumns {
    public static func columnsFor(
        width: CGFloat,
        orientation: UIDeviceOrientation,
        sizeClass: UserInterfaceSizeClass?
    ) -> Int {
        let isCompact = sizeClass == .compact
        
        if orientation.isLandscape {
            // More columns in landscape
            switch width {
            case ..<600: return isCompact ? 1 : 2
            case ..<900: return isCompact ? 2 : 3
            case ..<1200: return 3
            default: return 4
            }
        } else {
            // Fewer columns in portrait
            switch width {
            case ..<400: return 1
            case ..<700: return isCompact ? 1 : 2
            case ..<1000: return 2
            default: return 3
            }
        }
    }
}

// MARK: - Transition Helpers

public struct SmoothOrientationTransition: ViewModifier {
    @State private var previousOrientation: UIDeviceOrientation = UIDevice.current.orientation
    @State private var isAnimating = false
    
    public func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                let newOrientation = UIDevice.current.orientation
                
                // Only animate for significant changes
                if newOrientation.isValidInterfaceOrientation && 
                   newOrientation != previousOrientation {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isAnimating = true
                        previousOrientation = newOrientation
                    }
                    
                    // Reset animation flag
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        isAnimating = false
                    }
                }
            }
            .transaction { transaction in
                if isAnimating {
                    transaction.animation = .easeInOut(duration: 0.4)
                }
            }
    }
}

public extension View {
    /// Adds smooth orientation transition support
    func smoothOrientationTransition() -> some View {
        self.modifier(SmoothOrientationTransition())
    }
}