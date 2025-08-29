import Foundation
import Shout

public struct SSHHost {
    public let hostname: String
    public let port: Int
    public let username: String
    public let password: String
    public init(hostname: String, port: Int = 22, username: String, password: String) {
        self.hostname = hostname; self.port = port; self.username = username; self.password = password
    }
}

public final class SSHClient {
    public init() {}

    public func run(_ cmd: String, on host: SSHHost) throws -> (status: Int32, output: String) {
        let ssh = try SSH(host: host.hostname, port: host.port)
        try ssh.authenticate(username: host.username, password: host.password)
        return try ssh.execute(cmd)
    }

    public func runCaptureAll(_ cmd: String, on host: SSHHost) throws -> (status: Int32, output: String) {
        try run(cmd + " 2>&1", on: host)
    }
}
