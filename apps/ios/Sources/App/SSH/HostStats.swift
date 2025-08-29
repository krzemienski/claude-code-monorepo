import Foundation

public struct CPU: Codable { public let usagePercent: Double }
public struct Memory: Codable { public let totalMB: Int; public let usedMB: Int; public let freeMB: Int }
public struct Disk: Codable { public let fs: String; public let usedPercent: Double; public let size: String; public let used: String; public let avail: String; public let mount: String }
public struct Net: Codable { public let txMBs: Double; public let rxMBs: Double }

public struct HostSnapshot: Codable {
    public let ts: Date
    public let cpu: CPU
    public let mem: Memory
    public let disks: [Disk]
    public let net: Net
    public let top: [String]
}

public final class HostStatsParser {
    public init() {}

    public func parseCPU(_ text: String) -> CPU {
        if let line = text.components(separatedBy: .newlines).first(where: { $0.lowercased().contains("all") && $0.contains(".") }) {
            let nums = line.split { !$0.isNumber && $0 != "." }.compactMap { Double($0) }
            if let idle = nums.last, idle >= 0, idle <= 100 {
                return CPU(usagePercent: max(0, min(100, 100 - idle)))
            }
        }
        if let cpuLine = text.components(separatedBy: .newlines).first(where: { $0.lowercased().contains("cpu(s)") }) {
            if let idleMatch = cpuLine.components(separatedBy: .whitespaces).first(where: { $0.hasSuffix("%id") || $0.hasSuffix("%idle") }) {
                let digits = idleMatch.filter { ("0"..."9").contains($0) || $0 == "." }
                if let idle = Double(digits) { return CPU(usagePercent: max(0, min(100, 100 - idle))) }
            }
        }
        return CPU(usagePercent: 0.0)
    }

    public func parseMemory(linuxFreeM: String?, macVmStat: String?) -> Memory {
        if let linux = linuxFreeM {
            if let line = linux.components(separatedBy: .newlines).first(where: { $0.lowercased().starts(with: "mem:") }) {
                let nums = line.split { !$0.isNumber }.compactMap { Int($0) }
                if nums.count >= 3 { return Memory(totalMB: nums[0], usedMB: nums[1], freeMB: nums[2]) }
            }
        }
        if let mac = macVmStat {
            let pageSize = 4096.0
            var total = 0.0, free = 0.0, active = 0.0, inactive = 0.0, wired = 0.0
            for line in mac.components(separatedBy: .newlines) {
                let digits = line.split { !$0.isNumber }.compactMap { Double($0) }.first ?? 0
                if line.lowercased().contains("pages free") { free = digits }
                if line.lowercased().contains("pages active") { active = digits }
                if line.lowercased().contains("pages inactive") { inactive = digits }
                if line.lowercased().contains("pages wired") { wired = digits }
            }
            total = free + active + inactive + wired
            let totalMB = Int((total * pageSize) / 1024.0 / 1024.0)
            let freeMB  = Int((free  * pageSize) / 1024.0 / 1024.0)
            let usedMB  = max(0, totalMB - freeMB)
            return Memory(totalMB: totalMB, usedMB: usedMB, freeMB: freeMB)
        }
        return Memory(totalMB: 0, usedMB: 0, freeMB: 0)
    }

    public func parseDisks(_ text: String) -> [Disk] {
        var results: [Disk] = []
        let lines = text.components(separatedBy: .newlines)
        guard lines.count > 1 else { return results }
        for line in lines.dropFirst() {
            let cols = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard cols.count >= 6 else { continue }
            if cols[0].hasPrefix("map") || cols[0].hasPrefix("devfs") { continue }
            let fs = cols[0]
            let size = cols.count > 2 ? cols[2] : ""
            let used = cols.count > 3 ? cols[3] : ""
            let avail = cols.count > 4 ? cols[4] : ""
            let usedPctStr = cols[5].trimmingCharacters(in: CharacterSet(charactersIn: "%"))
            let usedPct = Double(usedPctStr) ?? 0
            let mount = cols.last ?? "/"
            results.append(Disk(fs: fs, usedPercent: usedPct, size: size, used: used, avail: avail, mount: mount))
        }
        return results
    }

    public func net(txMBs: Double, rxMBs: Double) -> Net { Net(txMBs: txMBs, rxMBs: rxMBs) }
}

public final class HostStatsService {
    private let ssh: SSHClient
    private let parser = HostStatsParser()

    public init(ssh: SSHClient) { self.ssh = ssh }

    public func snapshotLinux(host: SSHHost) throws -> HostSnapshot {
        let cpuOut  = try ssh.runCaptureAll("mpstat 1 1 || top -b -n 1 | head -5", on: host).output
        let memOut  = try ssh.runCaptureAll("free -m", on: host).output
        let diskOut = try ssh.runCaptureAll("df -hT", on: host).output
        let topOut  = try ssh.runCaptureAll("ps -eo pid,ppid,pcpu,pmem,args --sort=-pcpu | head -15", on: host).output

        let cpu = parser.parseCPU(cpuOut)
        let mem = parser.parseMemory(linuxFreeM: memOut, macVmStat: nil)
        let disks = parser.parseDisks(diskOut)
        let net = parser.net(txMBs: 0, rxMBs: 0)
        let top = topOut.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return HostSnapshot(ts: Date(), cpu: cpu, mem: mem, disks: disks, net: net, top: top)
    }

    public func snapshotMac(host: SSHHost) throws -> HostSnapshot {
        let cpuOut  = try ssh.runCaptureAll("top -l 1 -s 0 | head -10", on: host).output
        let memOut  = try ssh.runCaptureAll("vm_stat", on: host).output
        let diskOut = try ssh.runCaptureAll("df -h", on: host).output
        let topOut  = try ssh.runCaptureAll("ps -A -o pid,ppid,pcpu,pmem,comm -r | head -15", on: host).output

        let cpu = parser.parseCPU(cpuOut)
        let mem = parser.parseMemory(linuxFreeM: nil, macVmStat: memOut)
        let disks = parser.parseDisks(diskOut)
        let net = parser.net(txMBs: 0, rxMBs: 0)
        let top = topOut.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return HostSnapshot(ts: Date(), cpu: cpu, mem: mem, disks: disks, net: net, top: top)
    }
}
