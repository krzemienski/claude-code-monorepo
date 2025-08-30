import SwiftUI

// MARK: - Loading State View

struct LoadingStateView: View {
    let message: String
    let showProgress: Bool
    let progress: Double?
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) var voiceOverEnabled
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @State private var animationPhase = 0.0
    @State private var lastAnnouncedProgress: Int = -1
    
    init(message: String = "Loading...", showProgress: Bool = false, progress: Double? = nil) {
        self.message = message
        self.showProgress = showProgress
        self.progress = progress
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Loading indicator
            ZStack {
                // Cyberpunk glow effect
                Circle()
                    .fill(Theme.neonCyan.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .blur(radius: reduceMotion ? 0 : 20)
                    .scaleEffect(reduceMotion ? 1 : (1 + animationPhase * 0.2))
                
                // Main loading ring
                Circle()
                    .stroke(Theme.border, lineWidth: 2)
                    .frame(width: 60, height: 60)
                
                // Animated progress ring
                Circle()
                    .trim(from: 0, to: progress ?? 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.neonCyan, Theme.neonBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(reduceMotion ? 0 : animationPhase * 360))
            }
            .accessibilityHidden(true) // Hide decorative element
            
            // Loading message
            Text(message)
                .font(.headline)
                .foregroundColor(Theme.foreground)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.updatesFrequently)
            
            // Progress indicator if available
            if showProgress, let progress = progress {
                VStack(spacing: Theme.Spacing.sm) {
                    ProgressView(value: progress)
                        .progressViewStyle(CyberpunkProgressStyle())
                        .frame(width: 200)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(Theme.mutedFg)
                        .accessibilityLabel("\(Int(progress * 100)) percent complete")
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .padding(Theme.Spacing.xl)
        .background(
            Theme.card
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .stroke(Theme.border, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
        .shadow(color: Theme.neonCyan.opacity(0.2), radius: reduceMotion ? 0 : 20)
        .onAppear {
            if !reduceMotion {
                withAnimation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false)
                ) {
                    animationPhase = 1
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(progress != nil ? "\(message), \(Int((progress ?? 0) * 100)) percent complete" : message)
        .accessibilityHint("Loading in progress")
        .accessibilityAddTraits(.updatesFrequently)
        .onChange(of: progress) { newValue in
            announceProgressChange(newValue)
        }
        .onAppear {
            // Announce loading state for VoiceOver users
            if voiceOverEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: message
                    )
                }
            }
        }
    }
    
    private func announceProgressChange(_ progress: Double?) {
        guard let progress = progress, voiceOverEnabled else { return }
        let currentProgress = Int(progress * 100)
        
        // Announce at milestones: 25%, 50%, 75%, 100%
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

// MARK: - Skeleton Loading View

struct SkeletonLoadingView: View {
    let lineCount: Int
    let showAvatar: Bool
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var shimmerPhase = 0.0
    
    init(lineCount: Int = 3, showAvatar: Bool = false) {
        self.lineCount = lineCount
        self.showAvatar = showAvatar
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            if showAvatar {
                // Avatar skeleton
                Circle()
                    .fill(shimmerGradient)
                    .frame(width: 48, height: 48)
            }
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(0..<lineCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(shimmerGradient)
                        .frame(height: 16 * dynamicTypeSize.scale)
                        .frame(maxWidth: index == lineCount - 1 ? 200 : .infinity)
                }
            }
        }
        .padding()
        .onAppear {
            if !reduceMotion {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    shimmerPhase = 1
                }
            }
        }
        .accessibilityHidden(true) // Skeleton is purely decorative
    }
    
    private var shimmerGradient: some ShapeStyle {
        LinearGradient(
            colors: [
                Theme.card,
                Theme.card.opacity(0.6),
                Theme.card
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .opacity(reduceMotion ? 1 : 0.8 + shimmerPhase * 0.2)
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var pulseAnimation = false
    
    init(
        title: String = "Something went wrong",
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.error, Theme.neonPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(pulseAnimation && !reduceMotion ? 1.1 : 1.0)
                .accessibilityHidden(true)
            
            // Error title
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.foreground)
                .multilineTextAlignment(.center)
            
            // Error message
            Text(message)
                .font(.body)
                .foregroundColor(Theme.mutedFg)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Retry button
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(CyberpunkButtonStyle())
                .accessibilityHint("Double tap to retry the operation")
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 400)
        .background(
            Theme.card
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .stroke(Theme.error.opacity(0.3), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
        .shadow(color: Theme.error.opacity(0.2), radius: reduceMotion ? 0 : 20)
        .onAppear {
            if !reduceMotion {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    pulseAnimation = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityHint(retryAction != nil ? "Button available to retry" : "")
        .accessibilityAddTraits(.isStaticText)
        .onAppear {
            // Announce error immediately for VoiceOver users
            if UIAccessibility.isVoiceOverRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "\(title). \(message)"
                    )
                }
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var bounceAnimation = false
    
    init(
        title: String,
        message: String,
        systemImage: String = "tray",
        action: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.action = action
        self.actionTitle = actionTitle
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Empty state icon
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.mutedFg, Theme.dimFg],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(y: bounceAnimation && !reduceMotion ? -5 : 0)
                .accessibilityHidden(true)
            
            // Title
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.foreground)
                .multilineTextAlignment(.center)
            
            // Message
            Text(message)
                .font(.body)
                .foregroundColor(Theme.mutedFg)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Action button
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(CyberpunkButtonStyle())
                .accessibilityHint("Double tap to \(actionTitle.lowercased())")
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 400)
        .onAppear {
            if !reduceMotion {
                withAnimation(
                    .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
                ) {
                    bounceAnimation = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityHint(action != nil && actionTitle != nil ? "\(actionTitle!) button available" : "")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Cyberpunk Progress Style

struct CyberpunkProgressStyle: ProgressViewStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                
                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Theme.neonCyan, Theme.neonBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0))
                    .animation(reduceMotion ? .none : .spring(response: 0.3), value: configuration.fractionCompleted)
                
                // Glow effect
                if !reduceMotion {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.neonCyan.opacity(0.3))
                        .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0))
                        .blur(radius: 8)
                }
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Cyberpunk Button Style

struct CyberpunkButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    colors: configuration.isPressed ?
                    [Theme.neonCyan.opacity(0.8), Theme.neonBlue.opacity(0.8)] :
                    [Theme.neonCyan, Theme.neonBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Theme.neonCyan.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1.0)
            .shadow(
                color: Theme.neonCyan.opacity(configuration.isPressed ? 0.6 : 0.3),
                radius: reduceMotion ? 0 : (configuration.isPressed ? 15 : 10)
            )
            .animation(reduceMotion ? .none : .spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct LoadingStateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            LoadingStateView(message: "Loading data...")
            
            LoadingStateView(
                message: "Processing...",
                showProgress: true,
                progress: 0.65
            )
            
            SkeletonLoadingView(lineCount: 4, showAvatar: true)
            
            ErrorStateView(
                title: "Connection Failed",
                message: "Unable to connect to the server. Please check your internet connection.",
                retryAction: {}
            )
            
            EmptyStateView(
                title: "No Sessions",
                message: "Start a new chat session to begin",
                systemImage: "message",
                action: {},
                actionTitle: "New Session"
            )
        }
        .padding()
        .background(Theme.background)
    }
}