import SwiftUI
import Charts

/// Enhanced StatusBarComponent with Cyberpunk animations and real-time metrics
public struct StatusBarComponentEnhanced: View {
    let metrics: SystemMetrics
    let isConnected: Bool
    let syncStatus: SyncStatus
    
    @State private var animateProgress = false
    @State private var pulseAnimation = false
    @State private var dataFlowAnimation = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        metrics: SystemMetrics,
        isConnected: Bool = true,
        syncStatus: SyncStatus = .idle
    ) {
        self.metrics = metrics
        self.isConnected = isConnected
        self.syncStatus = syncStatus
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main status bar
            HStack(spacing: 20) {
                // Enhanced Connection Status
                EnhancedConnectionIndicator(isConnected: isConnected)
                
                CyberpunkDivider()
                
                // Enhanced Token Usage with animation
                EnhancedTokenIndicator(usage: metrics.tokenUsage)
                
                CyberpunkDivider()
                
                // Enhanced Memory with visualization
                EnhancedMemoryIndicator(usage: metrics.memoryUsage)
                
                CyberpunkDivider()
                
                // Enhanced Sync Status
                EnhancedSyncIndicator(status: syncStatus)
                
                Spacer()
                
                // Enhanced Performance Score
                EnhancedPerformanceScore(score: metrics.performanceScore)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Data flow visualization
            if !reduceMotion {
                DataFlowVisualization()
                    .frame(height: 2)
                    .opacity(dataFlowAnimation ? 0.8 : 0.3)
            }
        }
        .background(
            ZStack {
                // Base background
                RoundedRectangle(cornerRadius: 12)
                    .fill(CyberpunkThemeEnhanced.darkCard)
                
                // Animated border glow
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                CyberpunkThemeEnhanced.neonCyan.opacity(0.6),
                                CyberpunkThemeEnhanced.neonMagenta.opacity(0.3),
                                CyberpunkThemeEnhanced.neonBlue.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blur(radius: pulseAnimation ? 2 : 0)
                    .opacity(pulseAnimation ? 0.8 : 0.4)
            }
        )
        .neonGlow(color: isConnected ? CyberpunkThemeEnhanced.neonCyan : CyberpunkThemeEnhanced.neonRed, intensity: 1)
        .onAppear {
            if !reduceMotion {
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        withAnimation(
            .easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
        ) {
            pulseAnimation = true
            dataFlowAnimation = true
        }
    }
}

// MARK: - Enhanced Connection Indicator
private struct EnhancedConnectionIndicator: View {
    let isConnected: Bool
    @State private var pulseAnimation = false
    @State private var signalStrength: [Bool] = [false, false, false]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: 8) {
            // Animated connection orb
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                isConnected ? CyberpunkThemeEnhanced.neonGreen : CyberpunkThemeEnhanced.neonRed,
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .opacity(pulseAnimation ? 0.3 : 0.1)
                
                // Inner core
                Circle()
                    .fill(isConnected ? CyberpunkThemeEnhanced.neonGreen : CyberpunkThemeEnhanced.neonRed)
                    .frame(width: 10, height: 10)
                    .neonGlow(
                        color: isConnected ? CyberpunkThemeEnhanced.neonGreen : CyberpunkThemeEnhanced.neonRed,
                        intensity: 2
                    )
                
                // Signal waves
                if isConnected && !reduceMotion {
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(CyberpunkThemeEnhanced.neonGreen, lineWidth: 1)
                            .frame(width: CGFloat(15 + index * 8), height: CGFloat(15 + index * 8))
                            .scaleEffect(signalStrength[index] ? 1.3 : 1.0)
                            .opacity(signalStrength[index] ? 0 : 0.5)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isConnected ? "ONLINE" : "OFFLINE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isConnected ? CyberpunkThemeEnhanced.neonGreen : CyberpunkThemeEnhanced.neonRed)
                
                Text(isConnected ? "SSE Active" : "Disconnected")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .onAppear {
            if !reduceMotion {
                startAnimations()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isConnected ? "Connected to server" : "Offline")
    }
    
    private func startAnimations() {
        // Pulse animation
        withAnimation(
            .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            pulseAnimation = true
        }
        
        // Signal wave animation
        if isConnected {
            for index in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                    withAnimation(
                        .easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                    ) {
                        signalStrength[index] = true
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Token Indicator
private struct EnhancedTokenIndicator: View {
    let usage: TokenUsage
    @State private var animatedPercentage: Double = 0
    @State private var glowIntensity: Double = 0
    
    var color: Color {
        switch usage.percentage {
        case 0..<50: return CyberpunkThemeEnhanced.neonGreen
        case 50..<80: return CyberpunkThemeEnhanced.neonYellow
        default: return CyberpunkThemeEnhanced.neonRed
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon with glow
            ZStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
                    .neonGlow(color: color, intensity: CGFloat(glowIntensity))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("TOKENS")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                
                HStack(spacing: 4) {
                    Text("\(usage.used.formatted())")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                    
                    Text("/ \(usage.limit.formatted())")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            
            // Animated progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (animatedPercentage / 100))
                    
                    // Glow overlay
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * (animatedPercentage / 100))
                        .blur(radius: 3)
                        .opacity(0.5)
                }
            }
            .frame(width: 50, height: 6)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedPercentage = usage.percentage
            }
            
            withAnimation(
                .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                glowIntensity = 2
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Token usage: \(Int(usage.percentage))%")
    }
}

// MARK: - Enhanced Memory Indicator
private struct EnhancedMemoryIndicator: View {
    let usage: MemoryUsage
    @State private var waveAnimation = false
    
    var color: Color {
        switch usage.percentage {
        case 0..<60: return CyberpunkThemeEnhanced.neonBlue
        case 60..<85: return CyberpunkThemeEnhanced.neonOrange
        default: return CyberpunkThemeEnhanced.neonRed
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Animated memory chip icon
            ZStack {
                Image(systemName: "memorychip")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
                    .scaleEffect(waveAnimation ? 1.1 : 1.0)
                    .neonGlow(color: color, intensity: 1.5)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("MEMORY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                
                HStack(spacing: 2) {
                    Text("\(Int(usage.percentage))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                    
                    Text("%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))
                    
                    // Mini bars visualization
                    HStack(spacing: 1) {
                        ForEach(0..<5) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(
                                    index < Int(usage.percentage / 20) ? color : Color.white.opacity(0.1)
                                )
                                .frame(width: 3, height: 8)
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
            ) {
                waveAnimation = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Memory usage: \(Int(usage.percentage))%")
    }
}

// MARK: - Enhanced Sync Indicator
private struct EnhancedSyncIndicator: View {
    let status: SyncStatus
    @State private var rotationAngle: Double = 0
    @State private var glowAnimation = false
    
    var statusColor: Color {
        switch status {
        case .idle, .success: return CyberpunkThemeEnhanced.neonGreen
        case .syncing: return CyberpunkThemeEnhanced.neonBlue
        case .error: return CyberpunkThemeEnhanced.neonRed
        }
    }
    
    var statusIcon: String {
        switch status {
        case .idle: return "checkmark.circle"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle"
        case .success: return "checkmark.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                // Background glow
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .blur(radius: glowAnimation ? 4 : 2)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(statusColor)
                    .rotationEffect(status == .syncing ? .degrees(rotationAngle) : .zero)
                    .neonGlow(color: statusColor, intensity: 1)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(statusColor)
                
                if case .error(let message) = status {
                    Text(message)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
        }
        .onAppear {
            if status == .syncing {
                withAnimation(
                    .linear(duration: 1.0)
                        .repeatForever(autoreverses: false)
                ) {
                    rotationAngle = 360
                }
            }
            
            withAnimation(
                .easeInOut(duration: 1)
                    .repeatForever(autoreverses: true)
            ) {
                glowAnimation = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sync status: \(statusText)")
    }
    
    private var statusText: String {
        switch status {
        case .idle: return "SYNCED"
        case .syncing: return "SYNCING"
        case .error: return "ERROR"
        case .success: return "UPDATED"
        }
    }
}

// MARK: - Enhanced Performance Score
private struct EnhancedPerformanceScore: View {
    let score: Double
    @State private var animatedScore: Double = 0
    @State private var ringAnimation = false
    
    var color: Color {
        switch score {
        case 90...100: return CyberpunkThemeEnhanced.neonGreen
        case 70..<90: return CyberpunkThemeEnhanced.neonYellow
        default: return CyberpunkThemeEnhanced.neonRed
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Circular progress indicator
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 30, height: 30)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedScore / 100)
                    .stroke(
                        LinearGradient(
                            colors: [color, color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(ringAnimation ? 1.1 : 1.0)
                
                // Center value
                Text("\(Int(animatedScore))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("PERFORMANCE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                
                Text("SCORE")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(color)
            }
        }
        .neonGlow(color: color, intensity: 1)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animatedScore = score
            }
            
            withAnimation(
                .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
            ) {
                ringAnimation = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Performance score: \(Int(score))%")
    }
}

// MARK: - Cyberpunk Divider
private struct CyberpunkDivider: View {
    @State private var glowAnimation = false
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        CyberpunkThemeEnhanced.neonCyan.opacity(0.3),
                        Color.white.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1, height: 20)
            .blur(radius: glowAnimation ? 1 : 0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2)
                        .repeatForever(autoreverses: true)
                ) {
                    glowAnimation = true
                }
            }
    }
}

// MARK: - Data Flow Visualization
private struct DataFlowVisualization: View {
    @State private var offset: CGFloat = -100
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            CyberpunkThemeEnhanced.neonCyan.opacity(0.5),
                            CyberpunkThemeEnhanced.neonMagenta.opacity(0.3),
                            CyberpunkThemeEnhanced.neonBlue.opacity(0.5),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 100)
                .offset(x: offset)
                .onAppear {
                    withAnimation(
                        .linear(duration: 3)
                            .repeatForever(autoreverses: false)
                    ) {
                        offset = geometry.size.width
                    }
                }
        }
    }
}