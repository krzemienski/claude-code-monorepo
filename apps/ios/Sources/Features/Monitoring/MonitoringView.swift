import SwiftUI

struct MonitoringView: View {
    @State private var host = "localhost"
    @State private var user = "user"
    @State private var pass = ""
    @State private var snapshot: HostSnapshot?
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        Form {
            Section("Host") {
                TextField("Host", text: $host).textInputAutocapitalization(.never).disableAutocorrection(true)
                TextField("User", text: $user).textInputAutocapitalization(.never).disableAutocorrection(true)
                SecureField("Pass", text: $pass)
                HStack {
                    Button("Snapshot (Linux)") { Task { await snapLinux() } }.buttonStyle(.borderedProminent)
                    Button("Snapshot (macOS)") { Task { await snapMac() } }.buttonStyle(.bordered)
                }
            }

            Section("Summary") {
                if isLoading { ProgressView() }
                if let s = snapshot {
                    HStack {
                        metric("CPU", String(format: "%.0f%%", s.cpu.usagePercent))
                        metric("Mem", "\(s.mem.usedMB)/\(s.mem.totalMB) MB")
                        metric("Net", String(format: "↑%.1f ↓%.1f MB/s", s.net.txMBs, s.net.rxMBs))
                    }
                } else { Text("No data").foregroundStyle(Theme.mutedFg) }
            }

            if let s = snapshot {
                Section("Disks") {
                    ForEach(s.disks.indices, id: \.self) { i in
                        let d = s.disks[i]
                        HStack {
                            Text(d.mount); Spacer()
                            Text("\(Int(d.usedPercent))%").font(.caption).foregroundStyle(Theme.mutedFg)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Theme.input).frame(height: 6)
                                Rectangle().fill(Theme.primary).frame(width: geo.size.width * CGFloat(d.usedPercent/100.0), height: 6)
                            }
                        }.frame(height: 6)
                    }
                }

                Section("Top Processes") {
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(s.top, id: \.self) { line in Text(line).font(.system(.footnote, design: .monospaced)) }
                        }
                    }.frame(maxHeight: 200)
                }
            }
        }
        .navigationTitle("Monitor")
        .alert("Error", isPresented: .constant(errorMsg != nil), presenting: errorMsg) { _ in
            Button("OK", role: .cancel) { errorMsg = nil }
        } message: { e in Text(e) }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack { Text(value).font(.headline).foregroundStyle(Theme.primary); Text(label).font(.caption).foregroundStyle(Theme.mutedFg) }
            .frame(maxWidth: .infinity)
    }

    private func snapLinux() async {
        isLoading = true; defer { isLoading = false }
        do {
            let s = try HostStatsService(ssh: SSHClient()).snapshotLinux(host: .init(hostname: host, username: user, password: pass))
            snapshot = s
        } catch { errorMsg = "\(error)" }
    }

    private func snapMac() async {
        isLoading = true; defer { isLoading = false }
        do {
            let s = try HostStatsService(ssh: SSHClient()).snapshotMac(host: .init(hostname: host, username: user, password: pass))
            snapshot = s
        } catch { errorMsg = "\(error)" }
    }
}
