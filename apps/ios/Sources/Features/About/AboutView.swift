import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Claude Code iOS")
                .font(Theme.Fonts.title)
                .foregroundColor(Theme.foreground)
            
            Text("Version 1.0.0")
                .font(Theme.Fonts.subtitle)
                .foregroundColor(Theme.mutedFg)
            
            Spacer()
        }
        .padding()
        .background(Theme.background)
    }
}