import SwiftUI

struct FileDetailView: View {
    let filePath: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("File Details")
                .font(Theme.Fonts.title)
                .foregroundColor(Theme.foreground)
            
            Text(filePath)
                .font(.system(size: Theme.FontSize.sm, design: .monospaced))
                .foregroundColor(Theme.mutedFg)
            
            ScrollView {
                Text("File content will appear here...")
                    .font(.system(size: Theme.FontSize.sm, design: .monospaced))
                    .foregroundColor(Theme.foreground)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.backgroundSecondary)
                    .cornerRadius(Theme.CornerRadius.md)
            }
            
            Spacer()
        }
        .padding()
        .background(Theme.background)
    }
}