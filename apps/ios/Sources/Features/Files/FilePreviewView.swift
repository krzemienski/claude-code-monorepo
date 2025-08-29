import SwiftUI

struct FilePreviewView: View, Identifiable {
    var id: String { filePath }
    let host: String
    let user: String
    let pass: String
    let filePath: String

    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var errorMsg: String?

    var body: some View {
        NavigationView {
            ScrollView {
                Text(content.isEmpty ? "No content" : content)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(filePath)
            .toolbar { Button("Close") { dismiss() } }
            .onAppear { Task { await load() } }
            .alert("Error", isPresented: .constant(errorMsg != nil), presenting: errorMsg) { _ in
                Button("OK", role: .cancel) { errorMsg = nil }
            } message: { e in Text(e) }
        }
    }

    private func load() async {
        do {
            let ssh = SSHClient()
            let hostObj = SSHHost(hostname: host, username: user, password: pass)
            let (status, output) = try ssh.runCaptureAll("cat \(shellEscape(filePath))", on: hostObj)
            guard status == 0 else { throw NSError(domain: "ssh", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output]) }
            content = output
        } catch { errorMsg = "\(error)" }
    }

    private func shellEscape(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
}
