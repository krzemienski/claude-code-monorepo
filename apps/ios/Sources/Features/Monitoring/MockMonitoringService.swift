import Foundation

// MARK: - Mock Monitoring Types
// Note: SSH functionality has been removed from the iOS app
// Using mock types for monitoring demonstration

struct MockHostSnapshot {
    let cpu: CPUSnapshot
    let mem: MemorySnapshot
    let disks: [DiskSnapshot]
    let net: NetworkSnapshot
    let top: [String]
    let timestamp = Date()
}

struct CPUSnapshot {
    let usagePercent: Double
    let cores: Int
    
    static var mock: CPUSnapshot {
        CPUSnapshot(
            usagePercent: Double.random(in: 10...90),
            cores: ProcessInfo.processInfo.processorCount
        )
    }
}

struct MemorySnapshot {
    let totalMB: Int
    let usedMB: Int
    let freeMB: Int
    
    static var mock: MemorySnapshot {
        let total = 16384 // 16GB
        let used = Int.random(in: 4096...12288)
        return MemorySnapshot(
            totalMB: total,
            usedMB: used,
            freeMB: total - used
        )
    }
}

struct DiskSnapshot {
    let mount: String
    let totalGB: Int
    let usedGB: Int
    let usedPercent: Double
    
    static var mock: DiskSnapshot {
        let total = 512
        let used = Int.random(in: 100...400)
        return DiskSnapshot(
            mount: "/",
            totalGB: total,
            usedGB: used,
            usedPercent: Double(used) / Double(total) * 100
        )
    }
}

struct NetworkSnapshot {
    let rxMBs: Double
    let txMBs: Double
    
    static var mock: NetworkSnapshot {
        NetworkSnapshot(
            rxMBs: Double.random(in: 0.1...10.0),
            txMBs: Double.random(in: 0.1...5.0)
        )
    }
}

// MARK: - Mock Service
class MockHostStatsService {
    // Mock service - doesn't use real SSH client
    
    func snapshotLinux(hostname: String, username: String, password: String) throws -> MockHostSnapshot {
        // Return mock data for Linux
        return createMockSnapshot()
    }
    
    func snapshotMacOS(hostname: String, username: String, password: String) throws -> MockHostSnapshot {
        // Return mock data for macOS
        return createMockSnapshot()
    }
    
    private func createMockSnapshot() -> MockHostSnapshot {
        MockHostSnapshot(
            cpu: .mock,
            mem: .mock,
            disks: [.mock],
            net: .mock,
            top: [
                "PID    %CPU  COMMAND",
                "12345  45.2  Safari",
                "23456  22.1  Xcode",
                "34567  15.8  Terminal",
                "45678  8.3   Mail",
                "56789  5.2   Finder"
            ]
        )
    }
}