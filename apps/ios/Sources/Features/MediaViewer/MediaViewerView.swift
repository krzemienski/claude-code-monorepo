import SwiftUI

struct MediaViewerView: View {
    let url: URL
    
    var body: some View {
        VStack {
            Text("Media Viewer")
                .font(Theme.Fonts.title)
                .foregroundColor(Theme.foreground)
            
            Text(url.absoluteString)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.mutedFg)
            
            Spacer()
            
            // Placeholder for media content
            Rectangle()
                .fill(Theme.backgroundSecondary)
                .frame(height: 300)
                .overlay(
                    Text("Media content here")
                        .foregroundColor(Theme.mutedFg)
                )
            
            Spacer()
        }
        .padding()
        .background(Theme.background)
    }
}