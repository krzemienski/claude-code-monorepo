import SwiftUI

struct FileBrowserView: View {
    @State private var host = "localhost"
    @State private var user = "user"
    @State private var pass = ""
    @State private var path = "."
    @State private var listing: [String] = []
    @State private var previewPath: String? = nil
    @State private var errorMsg: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                formBar
                List {
                    ForEach(listing, id: \.self) { line in
                        HStack {
                            Text(line).font(.caption)
                            Spacer()
                            if line.contains("<dir>") == false {
                                Button("Preview") { previewPath = resolvedPath(from: line) }.buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Files")
            .sheet(item: $previewPath) { p in FilePreviewView(host: host, user: user, pass: pass, filePath: p) }
            .alert("Error", isPresented: .constant(errorMsg != nil), presenting: errorMsg) { _ in
                Button("OK", role: .cancel) { errorMsg = nil }
            } message: { e in Text(e) }
        }
    }

    private var formBar: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Host", text: $host).textInputAutocapitalization(.never).disableAutocorrection(true)
                TextField("User", text: $user).textInputAutocapitalization(.never).disableAutocorrection(true)
                SecureField("Pass", text: $pass)
            }
            HStack {
                TextField("Path", text: $path).textInputAutocapitalization(.never).disableAutocorrection(true)
                Button("List") { Task { await list() } }.buttonStyle(.borderedProminent)
            }
        }.padding(.horizontal)
    }

    private func list() async {
        do {
            let ssh = SSHClient()
            let hostObj = SSHHost(hostname: host, username: user, password: pass)
            let (status, output) = try ssh.runCaptureAll("ls -l \(shellEscape(path))", on: hostObj)
            guard status == 0 else { throw NSError(domain: "ssh", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output]) }
            listing = output.components(separatedBy: .newlines).compactMap { line in
                guard !line.isEmpty else { return nil }
                if line.hasPrefix("total") { return nil }
                let isDir = line.first == "d"
                let name = line.split(separator: " ", omittingEmptySubsequences: true).dropFirst(8).joined(separator: " ")
                return isDir ? "<dir> \(name)" : "\(name)"
            }
        } catch { errorMsg = "\(error)" }
    }

    private func shellEscape(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    private func resolvedPath(from line: String) -> String {
        let name = line.replacingOccurrences(of: "<dir> ", with: "")
        if path == "." { return name }; if path.hasSuffix("/") { return path + name }; return path + "/" + name
    }
}
