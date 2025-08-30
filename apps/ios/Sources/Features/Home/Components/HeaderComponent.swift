import SwiftUI

/// HeaderComponent - Reusable header component for navigation
public struct HeaderComponent: View {
    @Binding var isLoading: Bool
    let title: String
    let icon: String
    let settingsAction: (() -> Void)?
    
    // Animation state
    @State private var pulseAnimation = false
    
    public init(
        isLoading: Binding<Bool>,
        title: String = "Claude Code",
        icon: String = "brain.head.profile",
        settingsAction: (() -> Void)? = nil
    ) {
        self._isLoading = isLoading
        self.title = title
        self.icon = icon
        self.settingsAction = settingsAction
    }
    
    public var body: some View {
        HStack {
            // Logo and Title
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.primary)
                    .opacity(pulseAnimation ? 0.5 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.primary, Color(h: 280, s: 100, l: 50)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .accessibilityAddTraits(.isHeader)
            }
            
            Spacer()
            
            // Settings Button
            if settingsAction != nil {
                Button(action: { settingsAction?() }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(Theme.primary)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(
                            .linear(duration: 1.0)
                                .repeatForever(autoreverses: false),
                            value: isLoading
                        )
                }
                .accessibilityLabel("Settings")
                .accessibilityHint("Open application settings")
            }
        }
        .padding(.horizontal)
        .onAppear {
            pulseAnimation = true
        }
    }
}

// MARK: - Preview Provider
struct HeaderComponent_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HeaderComponent(isLoading: .constant(false))
                .previewDisplayName("Default")
            
            HeaderComponent(isLoading: .constant(true))
                .previewDisplayName("Loading")
            
            HeaderComponent(
                isLoading: .constant(false),
                title: "Custom Title",
                icon: "sparkles"
            )
            .previewDisplayName("Custom")
        }
        .padding()
        .background(Color(.systemBackground))
    }
}