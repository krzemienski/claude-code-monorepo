import SwiftUI

// MARK: - SessionsDetailView stub
public struct SessionsDetailView: View {
    public var body: some View {
        VStack {
            Text("Sessions Detail")
                .font(.largeTitle)
                .padding()
            
            Text("Session management interface")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

// MARK: - ProjectsDetailView stub
public struct ProjectsDetailView: View {
    public var body: some View {
        VStack {
            Text("Projects Detail")
                .font(.largeTitle)
                .padding()
            
            Text("Project management interface")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}