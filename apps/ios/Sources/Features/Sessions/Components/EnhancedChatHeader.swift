import SwiftUI

/// Extracted header component for EnhancedChatConsoleView
/// Manages connection status and navigation toolbar
struct EnhancedChatHeader: View {
    @Binding var connectionStatus: ChatViewModel.ConnectionStatus
    @Binding var showToolDetails: Bool
    let onSettingsPressed: () -> Void
    let onRefreshPressed: () -> Void
    
    @State private var connectionPulse = false
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        VStack(spacing: 0) {
            connectionStatusBar
            Divider()
                .background(Theme.border)
        }
    }
    
    private var connectionStatusBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Connection indicator
            Circle()
                .fill(connectionStatus.color)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(connectionStatus.color.opacity(0.5), lineWidth: connectionPulse ? 8 : 2)
                        .scaleEffect(connectionPulse ? 2 : 1)
                        .opacity(connectionPulse ? 0 : 1)
                        .animation(
                            reduceMotion ? nil :
                            Animation.easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: connectionPulse
                        )
                )
                .onAppear {
                    if connectionStatus == .connected && !reduceMotion {
                        connectionPulse = true
                    }
                }
                .accessibilityHidden(true)
            
            Text(connectionStatus.description)
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                .foregroundStyle(Theme.mutedFg)
            
            Spacer()
            
            // Tool details toggle
            Button {
                showToolDetails.toggle()
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Tools")
                }
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                .foregroundStyle(showToolDetails ? Theme.primary : Theme.mutedFg)
            }
            .accessibilityLabel("Toggle tool details")
            .accessibilityHint(showToolDetails ? "Hide tool execution panel" : "Show tool execution panel")
            
            // Settings button
            Button(action: onSettingsPressed) {
                Image(systemName: "gear")
                    .foregroundStyle(Theme.mutedFg)
            }
            .accessibilityLabel("Settings")
            
            // Refresh button
            Button(action: onRefreshPressed) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(Theme.mutedFg)
            }
            .accessibilityLabel("Refresh connection")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.card.opacity(0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection status: \(connectionStatus.description)")
    }
}

// MARK: - Preview
struct EnhancedChatHeader_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedChatHeader(
            connectionStatus: .constant(.connected),
            showToolDetails: .constant(false),
            onSettingsPressed: {},
            onRefreshPressed: {}
        )
        .background(Theme.background)
        .previewDisplayName("Enhanced Chat Header")
    }
}