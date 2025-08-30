import SwiftUI

struct MonitoringView: View {
    @State private var snapshot: MockHostSnapshot?
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var showMockData = false
    
    // Environment values for adaptive layout
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

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
                HStack {
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
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
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
        VStack(spacing: Theme.Spacing.xs) { 
            Text(value)
                .font(.headline)
                .foregroundStyle(Theme.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.mutedFg)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadMockData() {
        isLoading = true
        
        // Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            // Generate mock monitoring data
            let usedMB = Int.random(in: 4000...12000)
            let totalMB = 16384
            
            snapshot = MockHostSnapshot(
                cpu: CPUSnapshot(
                    usagePercent: Double.random(in: 15...85),
                    cores: ProcessInfo.processInfo.processorCount
                ),
                mem: MemorySnapshot(
                    totalMB: totalMB,
                    usedMB: usedMB,
                    freeMB: totalMB - usedMB
                ),
                disks: [
                    DiskSnapshot(
                        mount: "/",
                        totalGB: 256,
                        usedGB: Int.random(in: 50...180),
                        usedPercent: Double.random(in: 30...70)
                    ),
                    DiskSnapshot(
                        mount: "/data",
                        totalGB: 512,
                        usedGB: Int.random(in: 100...400),
                        usedPercent: Double.random(in: 10...90)
                    )
                ],
                net: NetworkSnapshot(
                    rxMBs: Double.random(in: 0.1...5.0),
                    txMBs: Double.random(in: 0.1...3.0)
                ),
                top: [
                    "PID    CPU%  MEM%  COMMAND",
                    "1234   12.5  3.2   ClaudeCode",
                    "5678   8.3   2.1   springboard",
                    "9012   5.7   1.5   kernel_task",
                    "3456   3.2   0.8   mDNSResponder"
                ]
            )
            isLoading = false
        }
    }
    
    private var hostSection: some View {
        Section("System Monitoring") {
            Toggle("Simulate System Data", isOn: $showMockData)
                .onChange(of: showMockData) { newValue in
                    if newValue {
                        loadMockData()
                    } else {
                        snapshot = nil
                    }
                }
            
            if showMockData {
                HStack {
                    Button("Refresh") {
                        loadMockData()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            
            // Removed SSH reference - iOS doesn't support direct system monitoring
            // Using simulated data for demonstration purposes
        }
    }
}
