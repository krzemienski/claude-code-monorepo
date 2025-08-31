import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Welcome to Claude Code")
                .font(Theme.Fonts.title)
                .foregroundColor(Theme.foreground)
            
            Text("Your AI-powered coding assistant")
                .font(Theme.Fonts.subtitle)
                .foregroundColor(Theme.mutedFg)
            
            Spacer()
            
            Button("Get Started") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Theme.background)
    }
}