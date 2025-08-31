import SwiftUI

struct QuickSettingsView: View {
    @State private var isDarkMode = true
    @State private var fontSize: Double = 16
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Quick Settings")
                .font(Theme.Fonts.title)
                .foregroundColor(Theme.foreground)
            
            Toggle("Dark Mode", isOn: $isDarkMode)
                .foregroundColor(Theme.foreground)
            
            VStack(alignment: .leading) {
                Text("Font Size: \(Int(fontSize))")
                    .foregroundColor(Theme.foreground)
                Slider(value: $fontSize, in: 12...24)
            }
            
            Spacer()
        }
        .padding()
        .background(Theme.background)
    }
}