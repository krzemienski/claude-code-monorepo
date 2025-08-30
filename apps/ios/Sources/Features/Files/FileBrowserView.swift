import SwiftUI

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
    
    init(_ value: String) {
        self.value = value
    }
}

struct FileBrowserView: View {
    @State private var host = "localhost"
    @State private var user = "user"
    @State private var pass = ""
    @State private var path = "."
    @State private var listing: [String] = []
    @State private var previewPath: IdentifiableString? = nil
    @State private var errorMsg: String?
    
    // Environment values for adaptive layout
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case host, user, pass, path
    }

    var body: some View {
        NavigationStack {
            contentView
        }
    }
    
    private var contentView: some View {
        VStack(spacing: Theme.Spacing.adaptive(Theme.Spacing.sm)) {
            formBar
            fileList
        }
        .navigationTitle("Files")
        .accessibilityElement(
            label: "File Browser",
            traits: .isHeader
        )
        .sheet(item: $previewPath) { p in 
            FilePreviewView(host: host, user: user, pass: pass, filePath: p.value) 
        }
        .alert("Error", isPresented: .constant(errorMsg != nil), presenting: errorMsg) { _ in
            Button("OK", role: .cancel) { errorMsg = nil }
        } message: { e in 
            Text(e) 
        }
    }
    
    private var fileList: some View {
        List {
            ForEach(listing, id: \.self) { line in
                fileRow(for: line)
            }
        }
    }
    
    @ViewBuilder
    private func fileRow(for line: String) -> some View {
        HStack {
            fileLabel(for: line)
            Spacer()
            if !line.contains("<dir>") {
                previewButton(for: line)
            }
        }
        .adaptivePadding(.vertical, Theme.Spacing.xs)
    }
    
    private func fileLabel(for line: String) -> some View {
        let isDirectory = line.contains("<dir>")
        let label = isDirectory ? "Directory: \(line.replacingOccurrences(of: "<dir> ", with: ""))" : "File: \(line)"
        let traits: AccessibilityTraits = isDirectory ? .isButton : .isStaticText
        
        return Text(line)
            .font(.system(size: Theme.FontSize.adaptive(Theme.FontSize.xs)))
            .applyDynamicTypeSize()
            .accessibilityElement(
                label: label,
                traits: traits
            )
    }
    
    private func previewButton(for line: String) -> some View {
        Button("Preview") { 
            previewPath = IdentifiableString(resolvedPath(from: line))
        }
        .buttonStyle(.bordered)
        .applyDynamicTypeSize()
        .accessibilityElement(
            label: "Preview \(line)",
            hint: "Opens file preview",
            traits: .isButton
        )
    }

    private var formBar: some View {
        VStack(spacing: Theme.Spacing.adaptive(Theme.Spacing.sm)) {
            AdaptiveStack {
                TextField("Host", text: $host)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .host)
                    .applyDynamicTypeSize()
                    .accessibilityElement(
                        label: "SSH Host",
                        value: host,
                        hint: "Enter the hostname or IP address"
                    )
                TextField("User", text: $user)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .user)
                    .applyDynamicTypeSize()
                    .accessibilityElement(
                        label: "Username",
                        value: user,
                        hint: "Enter SSH username"
                    )
                SecureField("Pass", text: $pass)
                    .focused($focusedField, equals: .pass)
                    .applyDynamicTypeSize()
                    .accessibilityElement(
                        label: "Password",
                        value: pass.isEmpty ? "Not set" : "Set",
                        hint: "Enter SSH password"
                    )
            }
            HStack(spacing: Theme.Spacing.adaptive(Theme.Spacing.sm)) {
                TextField("Path", text: $path)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .path)
                    .applyDynamicTypeSize()
                    .accessibilityElement(
                        label: "Directory path",
                        value: path,
                        hint: "Enter path to browse"
                    )
                Button("List") { 
                    Task { await list() } 
                }
                .buttonStyle(.borderedProminent)
                .applyDynamicTypeSize()
                .accessibilityElement(
                    label: "List files",
                    hint: "Browse files in specified directory",
                    traits: .isButton
                )
            }
        }
        .adaptivePadding(.horizontal)
    }

    private func list() async {
        // SSH functionality has been removed from the iOS app
        // This feature will need to be reimplemented using a backend API
        errorMsg = "SSH functionality not available. This feature requires backend API integration."
        listing = [] // Clear the listing
    }

    private func shellEscape(_ s: String) -> String { 
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" 
    }
    
    private func resolvedPath(from line: String) -> String {
        let name = line.replacingOccurrences(of: "<dir> ", with: "")
        if path == "." { 
            return name 
        }
        if path.hasSuffix("/") { 
            return path + name 
        }
        return path + "/" + name
    }
}