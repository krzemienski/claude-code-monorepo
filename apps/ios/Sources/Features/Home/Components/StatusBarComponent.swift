import SwiftUI
import Charts

/// StatusBarComponent - Displays system status and metrics
public struct StatusBarComponent: View {
    let metrics: SystemMetrics
    let isConnected: Bool
    let syncStatus: SyncStatus
    
    @State private var animateProgress = false
    @Environment(\.colorScheme) private var colorScheme
    
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
        HStack(spacing: 20) {
            // Connection Status
            ConnectionIndicator(isConnected: isConnected)
            
            Divider()
                .frame(height: 20)
            
            // Token Usage
            TokenUsageIndicator(usage: metrics.tokenUsage)
            
            Divider()
                .frame(height: 20)
            
            // Memory Usage
            MemoryUsageIndicator(usage: metrics.memoryUsage)
            
            Divider()
                .frame(height: 20)
            
            // Sync Status
            SyncStatusIndicator(status: syncStatus)
            
            Spacer()
            
            // Performance Score
            PerformanceScore(score: metrics.performanceScore)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - System Metrics Model
public struct SystemMetrics {
    public let tokenUsage: TokenUsage
    public let memoryUsage: MemoryUsage
    public let performanceScore: Double
    
    public init(
        tokenUsage: TokenUsage = TokenUsage(),
        memoryUsage: MemoryUsage = MemoryUsage(),
        performanceScore: Double = 95.0
    ) {
        self.tokenUsage = tokenUsage
        self.memoryUsage = memoryUsage
        self.performanceScore = performanceScore
    }
}

public struct TokenUsage {
    public let used: Int
    public let limit: Int
    
    public init(used: Int = 45000, limit: Int = 100000) {
        self.used = used
        self.limit = limit
    }
    
    var percentage: Double {
        Double(used) / Double(limit) * 100
    }
}

public struct MemoryUsage {
    public let used: Double
    public let total: Double
    
    public init(used: Double = 256, total: Double = 512) {
        self.used = used
        self.total = total
    }
    
    var percentage: Double {
        used / total * 100
    }
}

public enum SyncStatus {
    case idle
    case syncing
    case error(String)
    case success
}

// MARK: - Sub Components
private struct ConnectionIndicator: View {
    let isConnected: Bool
    @State private var pulseAnimation = false
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(isConnected ? Color.green : Color.red, lineWidth: 2)
                        .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.0)
                                .repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                )
            
            Text(isConnected ? "Connected" : "Offline")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isConnected ? .primary : .secondary)
        }
        .onAppear {
            if isConnected {
                pulseAnimation = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isConnected ? "Connected to server" : "Offline")
    }
}

private struct TokenUsageIndicator: View {
    let usage: TokenUsage
    
    var color: Color {
        switch usage.percentage {
        case 0..<50: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.caption)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Tokens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Text("\(usage.used.formatted())")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("/ \(usage.limit.formatted())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Mini Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(
                            width: geometry.size.width * (usage.percentage / 100),
                            height: 4
                        )
                }
            }
            .frame(width: 40, height: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Token usage: \(Int(usage.percentage))%")
    }
}

private struct MemoryUsageIndicator: View {
    let usage: MemoryUsage
    
    var color: Color {
        switch usage.percentage {
        case 0..<60: return .blue
        case 60..<85: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "memorychip")
                .font(.caption)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Memory")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("\(Int(usage.percentage))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Memory usage: \(Int(usage.percentage))%")
    }
}

private struct SyncStatusIndicator: View {
    let status: SyncStatus
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        HStack(spacing: 6) {
            switch status {
            case .idle:
                Image(systemName: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
                
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
                
            case .error(let message):
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .help(message)
                
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sync status: \(statusText)")
    }
    
    private var statusText: String {
        switch status {
        case .idle: return "Synced"
        case .syncing: return "Syncing..."
        case .error: return "Error"
        case .success: return "Updated"
        }
    }
}

private struct PerformanceScore: View {
    let score: Double
    
    var color: Color {
        switch score {
        case 90...100: return .green
        case 70..<90: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speedometer")
                .font(.caption)
                .foregroundStyle(color)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Performance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("\(Int(score))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Performance score: \(Int(score))%")
    }
}

// MARK: - Preview Provider
struct StatusBarComponent_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StatusBarComponent(
                metrics: SystemMetrics(),
                isConnected: true,
                syncStatus: .idle
            )
            .previewDisplayName("Connected - Idle")
            
            StatusBarComponent(
                metrics: SystemMetrics(
                    tokenUsage: TokenUsage(used: 85000, limit: 100000),
                    memoryUsage: MemoryUsage(used: 450, total: 512)
                ),
                isConnected: true,
                syncStatus: .syncing
            )
            .previewDisplayName("High Usage - Syncing")
            
            StatusBarComponent(
                metrics: SystemMetrics(performanceScore: 65),
                isConnected: false,
                syncStatus: .error("Network timeout")
            )
            .previewDisplayName("Offline - Error")
        }
        .padding()
        .background(Color(.systemBackground))
    }
}