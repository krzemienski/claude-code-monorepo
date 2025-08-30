import SwiftUI
import UIKit

struct TraceEntry: Identifiable {
    let id = UUID()
    let ts: Date
    let level: String
    let scope: String
    let message: String
    let meta: String?
}

final class TraceStore: ObservableObject {
    @Published var entries: [TraceEntry] = []
    func append(level: String, scope: String, message: String, meta: String? = nil) {
        entries.insert(.init(ts: .init(), level: level, scope: scope, message: message, meta: meta), at: 0)
    }
}

struct TracingView: View {
    @StateObject private var store = TraceStore()
    @State private var filterLevel: String = "all"
    @State private var filterScope: String = "all"

    var filtered: [TraceEntry] {
        store.entries.filter {
            (filterLevel == "all" || $0.level == filterLevel) &&
            (filterScope == "all" || $0.scope == filterScope)
        }
    }

    var body: some View {
        VStack {
            HStack {
                Picker("Level", selection: $filterLevel) {
                    Text("All").tag("all"); Text("info").tag("info"); Text("warn").tag("warn"); Text("error").tag("error")
                }.pickerStyle(.segmented)
                Picker("Scope", selection: $filterScope) {
                    Text("All").tag("all"); Text("chat").tag("chat"); Text("sse").tag("sse"); Text("ssh").tag("ssh")
                }.pickerStyle(.segmented)
            }.padding(.horizontal)

            List {
                ForEach(filtered) { e in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(e.ts.formatted(date: .omitted, time: .standard)).font(.caption).foregroundStyle(Theme.mutedFg)
                            Spacer(); Text(e.level).font(.caption2)
                        }
                        Text(e.message).font(.footnote)
                        if let m = e.meta { Text(m).font(.caption2).foregroundStyle(Theme.mutedFg) }
                    }
                }
            }

            HStack {
                Button("Add Sample Trace") { store.append(level: "info", scope: "chat", message: "POST /v1/chat streaming OK", meta: "200 • 56ms") }
                .buttonStyle(.bordered)
                Spacer()
                Button("Export NDJSON") {
                    let ndjson = store.entries.map { e in
                        #"{\"ts\":\"\(ISO8601DateFormatter().string(from: e.ts))\",\"level\":\"\(e.level)\",\"scope\":\"\(e.scope)\",\"message\":\(String(reflecting: e.message)),\"meta\":\(String(reflecting: e.meta ?? ""))}"#
                    }.joined(separator: "\n")
                    UIPasteboard.general.string = ndjson
                }
                .buttonStyle(.borderedProminent)
            }.padding()
        }
        .navigationTitle("Tracing")
    }
}
