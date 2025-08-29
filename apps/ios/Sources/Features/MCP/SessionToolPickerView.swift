import SwiftUI

struct SessionToolPickerView: View {
    let sessionId: String
    @AppStorage("mcpConfigJSON") private var defaultJSON: String = ""
    @AppStorage var sessionJSON: String

    @State private var enabledServers: [String] = []
    @State private var enabledTools: [String] = []
    @State private var priority: [String] = []
    @State private var auditLog: Bool = true
    @Environment(\.dismiss) private var dismiss

    init(sessionId: String) {
        self.sessionId = sessionId
        _sessionJSON = AppStorage(wrappedValue: "", "mcpSession.\(sessionId)")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Enabled Servers") { TokenEditor(tokens: $enabledServers, placeholder: "server id") }
                Section("Enabled Tools") { TokenEditor(tokens: $enabledTools, placeholder: "tool name") }
                Section("Priority (drag)") { ReorderableList(items: $priority) }
                Section { Toggle("Audit Log", isOn: $auditLog) }
            }
            .navigationTitle("Session Tools")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); dismiss() } }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        if let d = sessionJSON.data(using: .utf8),
           let c = try? JSONDecoder().decode(MCPConfigLocal.self, from: d) {
            enabledServers = c.enabledServers; enabledTools = c.enabledTools; priority = c.priority; auditLog = c.auditLog; return
        }
        if let d = defaultJSON.data(using: .utf8),
           let c = try? JSONDecoder().decode(MCPConfigLocal.self, from: d) {
            enabledServers = c.enabledServers; enabledTools = c.enabledTools; priority = c.priority; auditLog = c.auditLog
        }
    }

    private func save() {
        let c = MCPConfigLocal(enabledServers: enabledServers, enabledTools: enabledTools, priority: priority, auditLog: auditLog)
        if let data = try? JSONEncoder().encode(c), let s = String(data: data, encoding: .utf8) { sessionJSON = s }
    }
}

private struct TokenEditor: View {
    @Binding var tokens: [String]
    @State private var new = ""
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(placeholder, text: $new).textInputAutocapitalization(.never).disableAutocorrection(true)
                Button("Add") { if !new.isEmpty { tokens.append(new); new = "" } }.buttonStyle(.bordered)
            }
            Wrap(tokens) { t in
                HStack(spacing: 4) {
                    Text(t).font(.caption)
                    Button(role: .destructive) { tokens.removeAll { $0 == t } } label: { Image(systemName: "xmark.circle.fill") }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct Wrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data; let content: (Data.Element) -> Content
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) { self.data = data; self.content = content }
    @State private var totalHeight = CGFloat.zero
    var body: some View { GeometryReader { geo in self.generate(in: geo) }.frame(height: totalHeight) }
    private func generate(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero; var height = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading, computeValue: { d in if width + d.width > g.size.width { width = 0; height -= d.height }; defer { width += d.width }; return width })
                    .alignmentGuide(.top, computeValue: { _ in let res = height; if item == data.last { DispatchQueue.main.async { self.totalHeight = -height } }; return res })
            }
        }
    }
}
