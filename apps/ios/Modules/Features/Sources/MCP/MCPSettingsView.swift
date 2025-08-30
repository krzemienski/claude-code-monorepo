import SwiftUI

struct MCPConfigLocal: Codable {
    var enabledServers: [String]
    var enabledTools: [String]
    var priority: [String]
    var auditLog: Bool
}

struct MCPSettingsView: View {
    @AppStorage("mcpConfigJSON") private var mcpJSON: String = ""
    @State private var enabledServers: [String] = ["fs-local", "bash"]
    @State private var enabledTools: [String] = ["fs.read", "fs.write", "grep.search", "bash.run"]
    @State private var priority: [String] = ["fs.read", "bash.run", "fs.write"]
    @State private var auditLog: Bool = true
    @State private var newServer = ""
    @State private var newTool = ""

    var body: some View {
        Form {
            Section("Servers") {
                HStack { TextField("Add server id", text: $newServer); Button("Add") { if !newServer.isEmpty { enabledServers.append(newServer); newServer = "" } } }
                ForEach(enabledServers, id: \.self) { s in
                    HStack { Text(s); Spacer(); Button(role: .destructive) { enabledServers.removeAll { $0 == s } } label: { Image(systemName: "trash") } }
                }
            }
            Section("Tools") {
                HStack { TextField("Add tool name", text: $newTool); Button("Add") { if !newTool.isEmpty { enabledTools.append(newTool); newTool = "" } } }
                ForEach(enabledTools, id: \.self) { t in
                    HStack { Text(t); Spacer(); Button(role: .destructive) { enabledTools.removeAll { $0 == t } } label: { Image(systemName: "trash") } }
                }
            }
            Section("Priority (drag to reorder)") { ReorderableList(items: $priority) }
            Section { Toggle("Audit Log", isOn: $auditLog) }
            Section { Button("Save as Default") { save() }.buttonStyle(.borderedProminent) }
        }
        .navigationTitle("MCP Settings")
        .onAppear { load() }
    }

    private func load() {
        guard !mcpJSON.isEmpty, let data = mcpJSON.data(using: .utf8) else { return }
        if let c = try? JSONDecoder().decode(MCPConfigLocal.self, from: data) {
            enabledServers = c.enabledServers; enabledTools = c.enabledTools; priority = c.priority; auditLog = c.auditLog
        }
    }

    private func save() {
        let c = MCPConfigLocal(enabledServers: enabledServers, enabledTools: enabledTools, priority: priority, auditLog: auditLog)
        if let data = try? JSONEncoder().encode(c), let s = String(data: data, encoding: .utf8) { mcpJSON = s }
    }
}

private struct ReorderableList: View {
    @Binding var items: [String]
    @State private var edit = EditMode.inactive
    var body: some View {
        List { ForEach(items, id: \.self) { t in Text(t) }.onMove { src, dst in items.move(fromOffsets: src, toOffset: dst) } }
            .environment(\.editMode, $edit)
            .onAppear { edit = .active }
            .frame(height: min(240, CGFloat(max(1, items.count)) * 44))
    }
}
