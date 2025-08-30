import SwiftUI

// MARK: - Cyberpunk Text Field

public struct CyberpunkTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String? = nil
    
    @FocusState private var isFocused: Bool
    @State private var glowAnimation = false
    
    public var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(isFocused ? Theme.neonCyan : Theme.mutedFg)
                    .font(.system(size: Theme.FontSize.lg))
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.foreground)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.foreground)
                    .focused($isFocused)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(isFocused ? Theme.inputFocus : Theme.input)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(isFocused ? Theme.borderActive : Theme.border, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.neonCyan.opacity(glowAnimation ? 0.6 : 0), lineWidth: 2)
                .blur(radius: 4)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowAnimation)
        )
        .onAppear { glowAnimation = isFocused }
        .onChange(of: isFocused) { glowAnimation = $0 }
    }
}

// MARK: - Gradient Button

public struct GradientButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var style: ButtonStyle = .primary
    var isLoading: Bool = false
    
    public enum ButtonStyle {
        case primary, secondary, destructive, ghost
    }
    
    @State private var isPressed = false
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                }
                
                Text(title)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .foregroundColor(textColor)
            .background(backgroundView)
            .cornerRadius(Theme.CornerRadius.md)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(Theme.Animation.spring, value: isPressed)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) {
            isPressed = true
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
        .disabled(isLoading)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Theme.neonGradient
        case .secondary:
            Theme.accentGradient
        case .destructive:
            Theme.error
        case .ghost:
            Color.clear
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
    }
    
    private var textColor: Color {
        switch style {
        case .ghost:
            return Theme.foreground
        default:
            return .white
        }
    }
}

// MARK: - Message Bubble

public struct MessageBubble: View {
    let message: String
    let role: MessageRole
    let timestamp: Date
    var isStreaming: Bool = false
    
    public enum MessageRole {
        case user, assistant, system
    }
    
    public var body: some View {
        HStack {
            if role == .user { Spacer(minLength: 60) }
            
            VStack(alignment: role == .user ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                Text(message)
                    .font(.system(size: Theme.FontSize.base))
                    .foregroundColor(Theme.foreground)
                    .multilineTextAlignment(role == .user ? .trailing : .leading)
                
                HStack(spacing: Theme.Spacing.xs) {
                    if isStreaming {
                        StreamingIndicator()
                    }
                    
                    Text(timestamp, style: .time)
                        .font(.system(size: Theme.FontSize.xs))
                        .foregroundColor(Theme.mutedFg)
                }
            }
            .padding(Theme.Spacing.md)
            .background(bubbleBackground)
            .cornerRadius(Theme.CornerRadius.lg, corners: bubbleCorners)
            
            if role != .user { Spacer(minLength: 60) }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    private var bubbleBackground: some View {
        Group {
            switch role {
            case .user:
                Theme.neonGradient.opacity(0.2)
            case .assistant:
                Theme.backgroundTertiary
            case .system:
                Theme.warning.opacity(0.1)
            }
        }
    }
    
    private var bubbleCorners: UIRectCorner {
        switch role {
        case .user:
            return [.topLeft, .topRight, .bottomLeft]
        case .assistant, .system:
            return [.topLeft, .topRight, .bottomRight]
        }
    }
}

// MARK: - Streaming Indicator

public struct StreamingIndicator: View {
    @State private var phase = 0
    
    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.neonCyan)
                    .frame(width: 4, height: 4)
                    .opacity(phase == index ? 1.0 : 0.3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Metric Card

public struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let trend: Trend?
    let icon: String
    let color: Color
    
    public enum Trend {
        case up(Double)
        case down(Double)
        case neutral
    }
    
    @State private var isAnimated = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: Theme.FontSize.xl))
                    .foregroundColor(color)
                    .rotationEffect(.degrees(isAnimated ? 360 : 0))
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: false), value: isAnimated)
                
                Spacer()
                
                if let trend = trend {
                    TrendIndicator(trend: trend)
                }
            }
            
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(value)
                    .font(.system(size: Theme.FontSize.xxxl, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.foreground)
                
                Text(title)
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedFg)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: Theme.FontSize.xs))
                        .foregroundColor(Theme.dimFg)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.2), radius: 10)
        .onAppear { isAnimated = true }
    }
}

// MARK: - Trend Indicator

public struct TrendIndicator: View {
    let trend: MetricCard.Trend
    
    public var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: trendIcon)
                .font(.system(size: Theme.FontSize.sm))
            
            if case let .up(value) = trend {
                Text("+\(value, specifier: "%.1f")%")
                    .font(.system(size: Theme.FontSize.sm, weight: .semibold))
            } else if case let .down(value) = trend {
                Text("-\(value, specifier: "%.1f")%")
                    .font(.system(size: Theme.FontSize.sm, weight: .semibold))
            }
        }
        .foregroundColor(trendColor)
    }
    
    private var trendIcon: String {
        switch trend {
        case .up:
            return "arrow.up.right"
        case .down:
            return "arrow.down.right"
        case .neutral:
            return "minus"
        }
    }
    
    private var trendColor: Color {
        switch trend {
        case .up:
            return Theme.success
        case .down:
            return Theme.error
        case .neutral:
            return Theme.mutedFg
        }
    }
}

// MARK: - Cyberpunk Navigation Bar

public struct CyberpunkNavigationBar: View {
    let title: String
    var subtitle: String? = nil
    var leadingAction: (() -> Void)? = nil
    var trailingActions: [NavigationAction] = []
    
    public struct NavigationAction {
        let icon: String
        let action: () -> Void
    }
    
    public var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            if let leadingAction = leadingAction {
                Button(action: leadingAction) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: Theme.FontSize.lg, weight: .semibold))
                        .foregroundColor(Theme.neonCyan)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: Theme.FontSize.xl, weight: .bold))
                    .foregroundColor(Theme.foreground)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedFg)
                }
            }
            
            Spacer()
            
            HStack(spacing: Theme.Spacing.md) {
                ForEach(trailingActions.indices, id: \.self) { index in
                    Button(action: trailingActions[index].action) {
                        Image(systemName: trailingActions[index].icon)
                            .font(.system(size: Theme.FontSize.lg))
                            .foregroundColor(Theme.neonCyan)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            Theme.darkGradient
                .ignoresSafeArea()
        )
    }
}

// MARK: - Tool Timeline Item

public struct ToolTimelineItem: View {
    let toolName: String
    let status: ToolStatus
    let duration: String?
    let icon: String
    
    public enum ToolStatus {
        case pending, running, success, failed
    }
    
    public var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Timeline connector
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                
                ZStack {
                    Circle()
                        .fill(Theme.background)
                        .frame(width: 20, height: 20)
                    
                    Circle()
                        .stroke(statusColor, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    Image(systemName: statusIcon)
                        .font(.system(size: 10))
                        .foregroundColor(statusColor)
                }
                
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)
            
            // Tool info
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: Theme.FontSize.sm))
                        .foregroundColor(statusColor)
                    
                    Text(toolName)
                        .font(.system(size: Theme.FontSize.sm, weight: .medium))
                        .foregroundColor(Theme.foreground)
                    
                    Spacer()
                    
                    if let duration = duration {
                        Text(duration)
                            .font(.system(size: Theme.FontSize.xs))
                            .foregroundColor(Theme.mutedFg)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending:
            return Theme.mutedFg
        case .running:
            return Theme.neonCyan
        case .success:
            return Theme.success
        case .failed:
            return Theme.error
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .pending:
            return "clock"
        case .running:
            return "arrow.2.circlepath"
        case .success:
            return "checkmark"
        case .failed:
            return "xmark"
        }
    }
}

// MARK: - File Browser Row

public struct FileBrowserRow: View {
    let name: String
    let type: FileType
    let size: String?
    let modified: Date?
    let depth: Int
    
    public enum FileType {
        case folder, swift, javascript, json, markdown, image, other
    }
    
    public var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 0) {
                ForEach(0..<depth, id: \.self) { _ in
                    Spacer()
                        .frame(width: Theme.Spacing.lg)
                }
                
                Image(systemName: fileIcon)
                    .font(.system(size: Theme.FontSize.lg))
                    .foregroundColor(fileColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundColor(Theme.foreground)
                
                if let size = size, let modified = modified {
                    HStack(spacing: Theme.Spacing.md) {
                        Text(size)
                            .font(.system(size: Theme.FontSize.xs))
                            .foregroundColor(Theme.dimFg)
                        
                        Text(modified, style: .date)
                            .font(.system(size: Theme.FontSize.xs))
                            .foregroundColor(Theme.dimFg)
                    }
                }
            }
            
            Spacer()
            
            if type == .folder {
                Image(systemName: "chevron.right")
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedFg)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
    
    private var fileIcon: String {
        switch type {
        case .folder:
            return "folder.fill"
        case .swift:
            return "swift"
        case .javascript:
            return "curlybraces"
        case .json:
            return "doc.text"
        case .markdown:
            return "doc.richtext"
        case .image:
            return "photo"
        case .other:
            return "doc"
        }
    }
    
    private var fileColor: Color {
        switch type {
        case .folder:
            return Theme.neonBlue
        case .swift:
            return .orange
        case .javascript:
            return .yellow
        case .json:
            return Theme.neonGreen
        case .markdown:
            return Theme.neonPurple
        case .image:
            return Theme.neonPink
        case .other:
            return Theme.mutedFg
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Animated Background

public struct AnimatedBackground: View {
    @State private var animationPhase = 0.0
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient
                Theme.darkGradient
                
                // Animated orbs
                ForEach(0..<5) { index in
                    Circle()
                        .fill(orbColor(for: index))
                        .frame(width: orbSize(for: index), height: orbSize(for: index))
                        .blur(radius: 60)
                        .offset(orbOffset(for: index, in: geometry.size))
                        .opacity(0.3)
                        .animation(
                            .easeInOut(duration: Double(10 + index * 2))
                                .repeatForever(autoreverses: true),
                            value: animationPhase
                        )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            animationPhase = 1.0
        }
    }
    
    private func orbColor(for index: Int) -> Color {
        let colors = [Theme.neonCyan, Theme.neonPink, Theme.neonPurple, Theme.neonBlue, Theme.neonGreen]
        return colors[index % colors.count]
    }
    
    private func orbSize(for index: Int) -> CGFloat {
        return CGFloat(150 + index * 50)
    }
    
    private func orbOffset(for index: Int, in size: CGSize) -> CGSize {
        let phase = animationPhase * Double(index + 1)
        let x = sin(phase) * size.width * 0.3
        let y = cos(phase * 0.7) * size.height * 0.3
        return CGSize(width: x, height: y)
    }
}