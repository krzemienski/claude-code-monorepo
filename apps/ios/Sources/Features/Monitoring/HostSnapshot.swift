import Foundation

// MARK: - Host Monitoring Models
// Placeholder models for monitoring functionality
// Will need to be reimplemented with backend API integration

struct HostSnapshot: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let hostname: String
    let platform: String
    let uptime: String
    let loadAverage: [Double]
    let cpu: CPUInfo
    let mem: MemoryInfo
    let disks: [DiskInfo]
    let net: NetworkInfo
    let top: [String]
    
    init() {
        self.timestamp = Date()
        self.hostname = "localhost"
        self.platform = "iOS"
        self.uptime = "N/A"
        self.loadAverage = [0.0, 0.0, 0.0]
        self.cpu = CPUInfo()
        self.mem = MemoryInfo()
        self.disks = []
        self.net = NetworkInfo()
        self.top = []
    }
}

struct CPUInfo: Codable {
    let usagePercent: Double
    let cores: Int
    let model: String
    
    init() {
        self.usagePercent = 0.0
        self.cores = 1
        self.model = "Unknown"
    }
}

struct MemoryInfo: Codable {
    let totalMB: Int
    let usedMB: Int
    let freeMB: Int
    let usedPercent: Double
    
    init() {
        self.totalMB = 0
        self.usedMB = 0
        self.freeMB = 0
        self.usedPercent = 0.0
    }
}

struct DiskInfo: Codable {
    let device: String
    let mount: String
    let filesystem: String
    let totalGB: Double
    let usedGB: Double
    let freeGB: Double
    let usedPercent: Double
    
    init() {
        self.device = ""
        self.mount = "/"
        self.filesystem = ""
        self.totalGB = 0.0
        self.usedGB = 0.0
        self.freeGB = 0.0
        self.usedPercent = 0.0
    }
}

struct NetworkInfo: Codable {
    let rxMBs: Double
    let txMBs: Double
    let interfaces: [NetworkInterface]
    
    init() {
        self.rxMBs = 0.0
        self.txMBs = 0.0
        self.interfaces = []
    }
}

struct NetworkInterface: Identifiable, Codable {
    let id = UUID()
    let name: String
    let ipAddress: String
    let macAddress: String
    let bytesReceived: Int64
    let bytesSent: Int64
    
    init() {
        self.name = ""
        self.ipAddress = ""
        self.macAddress = ""
        self.bytesReceived = 0
        self.bytesSent = 0
    }
}