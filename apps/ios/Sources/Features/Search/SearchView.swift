import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.mutedFg)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
            
            List {
                Text("No results")
                    .foregroundColor(Theme.mutedFg)
            }
            .listStyle(PlainListStyle())
        }
        .background(Theme.background)
    }
}