import SwiftUI

struct MonitoringView: View {
    @State private var host = "localhost"
    @State private var user = "user"
    @State private var pass = ""
    @State private var snapshot: MockHostSnapshot?
    @State private var isLoading = false
    @State private var errorMsg: String?
    
    // Environment values for adaptive layout
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case host, user, pass
    }

    var body: some View {
        Form {
            hostSection
            summarySection
            diskAndProcessSections
        }
        .navigationTitle("Monitor")
        .alert("Error", isPresented: .constant(errorMsg != nil), presenting: errorMsg) { _ in
            Button("OK", role: .cancel) { errorMsg = nil }
        } message: { e in Text(e) }
    }
    
    @ViewBuilder
    private var diskAndProcessSections: some View {
        if snapshot != nil {
            disksSection
            processesSection
        }
    }
    
    private var summarySection: some View {
        Section("Summary") {
            if isLoading { 
                ProgressView()
            }
            if let s = snapshot {
                AdaptiveStack {
                    metric("CPU", String(format: "%.0f%%", s.cpu.usagePercent))
                    metric("Memory", "\(s.mem.usedMB)/\(s.mem.totalMB) MB")
                    metric("Network", String(format: "↑%.1f ↓%.1f MB/s", s.net.txMBs, s.net.rxMBs))
                }
            } else if !isLoading { 
                Text("No data")
                    .foregroundStyle(Theme.mutedFg)
            }
        }
    }
    
    @ViewBuilder
    private var disksSection: some View {
        if let s = snapshot {
            Section("Disks") {
                ForEach(s.disks.indices, id: \.self) { i in
                    diskRow(s.disks[i])
                }
            }
        }
    }
    
    private func diskRow(_ disk: DiskSnapshot) -> some View {
        VStack {
            HStack {
                Text(disk.mount)
                Spacer()
                Text("\(Int(disk.usedPercent))%")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedFg)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.input)
                        .frame(height: 4)
                    Rectangle()
                        .fill(Theme.primary)
                        .frame(width: geo.size.width * CGFloat(disk.usedPercent/100.0), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
    
    @ViewBuilder
    private var processesSection: some View {
        if let s = snapshot {
            Section("Top Processes") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(s.top, id: \.self) { line in 
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) { 
            Text(value)
                .font(.headline)
                .foregroundStyle(Theme.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
        }
        .frame(maxWidth: .infinity)
    }

    private func snapLinux() async {
        isLoading = true; defer { isLoading = false }
        do {
            // SSH functionality has been removed
            throw NSError(domain: "Monitoring", code: -1, userInfo: [NSLocalizedDescriptionKey: "SSH monitoring not available"])
        } catch { errorMsg = "\(error)" }
    }

    private func snapMac() async {
        isLoading = true; defer { isLoading = false }
        do {
            // SSH functionality has been removed
            throw NSError(domain: "Monitoring", code: -1, userInfo: [NSLocalizedDescriptionKey: "SSH monitoring not available"])
        } catch { errorMsg = "\(error)" }
    }
    
    private var hostSection: some View {
        Section("Host") {
            TextField("Host", text: $host)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            
            TextField("User", text: $user)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            
            SecureField("Pass", text: $pass)
            
            HStack {
                Button("Snapshot (Linux)") { 
                    Task { await snapLinux() } 
                }
                .buttonStyle(.borderedProminent)
                
                Button("Snapshot (macOS)") { 
                    Task { await snapMac() } 
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
