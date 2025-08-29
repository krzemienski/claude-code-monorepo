import SwiftUI
import Foundation
import os.log

struct ChatBubble: Identifiable, Equatable {
    enum Role: String { case user, assistant, system }
    let id = UUID()
    let role: Role
    var text: String
    let ts: Date = .init()
}

struct ToolRow: Identifiable, Equatable {
    enum State { case running, ok, error }
    let id: String
    var name: String
    var state: State
    var inputJSON: String
    var output: String = ""
    var durationMs: Int? = nil
    var exitCode: Int? = nil
    let ts: Date = .init()
}

struct ChatConsoleView: View {
    @StateObject private var settings = AppSettings()
    let sessionId: String?
    let projectId: String

    @State private var currentSessionId: String?
    @State private var modelId: String = "claude-3-5-haiku-20241022"

    @State private var transcript: [ChatBubble] = []
    @State private var timeline: [ToolRow] = []
    @State private var composing: String = ""
    @State private var isStreaming: Bool = false
    @State private var useStream: Bool = true
    @State private var statusLine: String = ""
    @State private var errorMsg: String?

    private let log = Logger(subsystem: "com.yourorg.claudecode", category: "Chat")

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            HStack(spacing: 12) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(transcript) { b in
                            bubbleView(b)
                                .frame(maxWidth: .infinity, alignment: b.role == .user ? .trailing : .leading)
                                .padding(.horizontal)
                        }
                    }.padding(.vertical, 8)
                }
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Tool Timeline").font(.headline)
                            Spacer()
                            Text(statusLine).font(.footnote).foregroundStyle(Theme.mutedFg)
                        }
                        ForEach(timeline) { row in
                            toolRowView(row)
                                .padding(8)
                                .background(Theme.card)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }.padding()
                }
                .frame(width: 300)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            composerBar
        }
        .navigationTitle("Chat Console")
        .onAppear { self.currentSessionId = sessionId; self.useStream = settings.streamingDefault }
        .alert("Error", isPresented: .constant(errorMsg != nil), presenting: errorMsg) { _ in
            Button("OK", role: .cancel) { errorMsg = nil }
        } message: { e in Text(e) }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Text("Session: \(currentSessionId ?? "—")").font(.subheadline).foregroundStyle(Theme.mutedFg)
            Spacer()
            Picker("Model", selection: $modelId) {
                Text("Claude 3.5 Haiku").tag("claude-3-5-haiku-20241022")
            }.pickerStyle(.menu)
            Toggle(isOn: $useStream) { Text("Stream").font(.subheadline) }.toggleStyle(.switch).tint(Theme.primary)
            Button { Task { await stopIfRunning() } } label: { Label("Stop", systemImage: "stop.circle.fill") }
                .buttonStyle(.bordered).tint(Theme.secondary).disabled(!isStreaming)
        }
        .padding(.horizontal).padding(.vertical, 6)
        .background(Theme.card.opacity(0.4))
    }

    private var composerBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $composing)
                    .frame(minHeight: 44, maxHeight: 120)
                    .padding(8)
                    .background(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                Button {
                    let text = composing.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    Task { await send(text) }
                } label: { HStack { Image(systemName: "paperplane.fill"); Text("Send") } }
                .buttonStyle(.borderedProminent)
                .disabled(isStreaming)
            }.padding(.horizontal).padding(.bottom, 8)
        }
        .background(Theme.card.opacity(0.4))
    }

    private func bubbleView(_ b: ChatBubble) -> some View {
        let bg = b.role == .user ? Theme.secondary : Theme.card
        let fg = b.role == .user ? Theme.secondaryFg : Theme.foreground
        return VStack(alignment: .leading, spacing: 4) {
            Text(b.role.rawValue.capitalized).font(.caption).foregroundStyle(Theme.mutedFg)
            Text(b.text).font(.body).foregroundStyle(fg)
        }
        .padding(10)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toolRowView(_ row: ToolRow) -> some View {
        HStack(alignment: .top) {
            Circle().fill(color(for: row.state)).frame(width: 10, height: 10).padding(.top, 5)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(row.name).font(.subheadline)
                    Spacer()
                    if let ms = row.durationMs { Text("\(ms) ms").font(.caption).foregroundStyle(Theme.mutedFg) }
                    if let ec = row.exitCode { Text("exit \(ec)").font(.caption).foregroundStyle(Theme.mutedFg) }
                }
                if !row.inputJSON.isEmpty {
                    Text("input: \(row.inputJSON)").font(.caption).foregroundStyle(Theme.mutedFg).lineLimit(3)
                }
                if !row.output.isEmpty {
                    Text(row.output).font(.caption).foregroundStyle(row.state == .error ? Theme.destructiveFg : Theme.foreground).lineLimit(6)
                }
            }
        }
    }

    private func color(for state: ToolRow.State) -> Color {
        switch state {
        case .running: return Theme.ring
        case .ok:      return Theme.accent
        case .error:   return Theme.destructive
        }
    }

    private func send(_ text: String) async {
        composing = ""
        transcript.append(.init(role: .user, text: text))
        if useStream { await streamOnce(text) } else { await nonStreamOnce(text) }
    }

    private func nonStreamOnce(_ text: String) async {
        guard let client = APIClient(settings: settings) else { errorMsg = "Invalid Base URL"; return }
        do {
            let body: [String: Any] = [
                "model": modelId,
                "project_id": projectId,
                "session_id": currentSessionId as Any,
                "messages": [[ "role": "user", "content": text ]],
                "stream": false
            ].compactMapValues { $0 }
            let data = try JSONSerialization.data(withJSONObject: body, options: [])
            var req = URLRequest(url: client.baseURL.appendingPathComponent("/v1/chat/completions"))
            req.httpMethod = "POST"; req.httpBody = data; req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let key = client.apiKey { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }

            let (respData, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let bodyS = String(data: respData, encoding: .utf8) ?? ""
                throw NSError(domain: "HTTP", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: bodyS])
            }

            if let obj = try JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let choices = obj["choices"] as? [[String: Any]],
               let msg = choices.first?["message"] as? [String: Any],
               let content = msg["content"] as? String {
                transcript.append(.init(role: .assistant, text: content))
            } else { transcript.append(.init(role: .assistant, text: "(no content)")) }

            if currentSessionId == nil, let sid = (try? JSONSerialization.jsonObject(with: respData)) as? [String: Any] {
                if let s = sid["session_id"] as? String { currentSessionId = s }
            }
            await fetchStatus()
        } catch { errorMsg = "\(error)" }
    }

    private func streamOnce(_ text: String) async {
        guard let client = APIClient(settings: settings) else { errorMsg = "Invalid Base URL"; return }
        isStreaming = true; defer { isStreaming = false }

        let sse = SSEClient()
        var assistantIndex: Int?
        var pendingAssistant = ChatBubble(role: .assistant, text: "")

        sse.onEvent = { event in
            handleSSELine(event.raw,
                          transcriptAppend: { addition in
                              if let idx = assistantIndex { transcript[idx].text += addition }
                              else { pendingAssistant.text += addition; transcript.append(pendingAssistant); assistantIndex = transcript.count - 1 }
                          },
                          setSession: { sid in if currentSessionId == nil { currentSessionId = sid } })
        }
        sse.onDone = { Task { await fetchStatus() } }
        sse.onError = { err in errorMsg = err.localizedDescription }

        let body: [String: Any] = [
            "model": modelId,
            "project_id": projectId,
            "session_id": currentSessionId as Any,
            "messages": [[ "role": "user", "content": text ]],
            "stream": true
        ].compactMapValues { $0 }

        do {
            let data = try JSONSerialization.data(withJSONObject: body)
            sse.connect(url: client.baseURL.appendingPathComponent("/v1/chat/completions"),
                        body: data,
                        headers: client.apiKey.map { ["Authorization": "Bearer \($0)"] } ?? [:])
        } catch { errorMsg = "\(error)" }
    }

    private func handleSSELine(_ jsonLine: String, transcriptAppend: (String) -> Void, setSession: (String) -> Void) {
        guard let data = jsonLine.data(using: .utf8) else { return }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let kind = (obj["object"] as? String) ?? (obj["type"] as? String) ?? ""
        switch kind {
        case "chat.completion.chunk":
            if let choices = obj["choices"] as? [[String: Any]],
               let delta = choices.first?["delta"] as? [String: Any],
               let piece = delta["content"] as? String, !piece.isEmpty { transcriptAppend(piece) }
            if let sid = obj["session_id"] as? String { setSession(sid) }
        case "tool_use":
            let toolId = (obj["id"] as? String) ?? UUID().uuidString
            let name = (obj["name"] as? String) ?? "tool"
            let inputAny = obj["input"]
            let inputJSON = (try? JSONSerialization.data(withJSONObject: inputAny ?? [:], options: [.sortedKeys, .withoutEscapingSlashes]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            timeline.insert(.init(id: toolId, name: name, state: .running, inputJSON: inputJSON), at: 0)
        case "tool_result":
            let toolId = (obj["tool_id"] as? String) ?? UUID().uuidString
            let name = (obj["name"] as? String) ?? "tool"
            let isError = (obj["is_error"] as? Bool) ?? false
            let out = (obj["content"] as? String) ?? ""
            let dur = obj["duration_ms"] as? Int
            let exit = obj["exit_code"] as? Int
            if let idx = timeline.firstIndex(where: { $0.id == toolId }) {
                timeline[idx].state = isError ? .error : .ok
                timeline[idx].name = name
                timeline[idx].output = out
                timeline[idx].durationMs = dur
                timeline[idx].exitCode = exit
            } else {
                timeline.insert(.init(id: toolId, name: name, state: isError ? .error : .ok, inputJSON: "{}", output: out, durationMs: dur, exitCode: exit), at: 0)
            }
        case "usage":
            let inTok = obj["input_tokens"] as? Int ?? 0
            let outTok = obj["output_tokens"] as? Int ?? 0
            let cost = obj["total_cost"] as? Double ?? 0
            statusLine = "tokens \(inTok + outTok) • cost $\(String(format: "%.4f", cost))"
        default: break
        }
    }

    private func fetchStatus() async {
        guard let client = APIClient(settings: settings), let sid = currentSessionId else { return }
        do {
            let req = URLRequest(url: client.baseURL.appendingPathComponent("/v1/chat/completions/\(sid)/status"))
            let (data, _) = try await URLSession.shared.data(for: req)
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let tokens = obj["total_tokens"] as? Int ?? 0
                let cost = obj["total_cost"] as? Double ?? 0
                statusLine = "tokens \(tokens) • cost $\(String(format: "%.4f", cost))"
            }
        } catch { }
    }

    private func stopIfRunning() async {
        guard let client = APIClient(settings: settings), let sid = currentSessionId else { return }
        do { try await client.delete("/v1/chat/completions/\(sid)"); isStreaming = false } catch { errorMsg = "\(error)" }
    }
}
