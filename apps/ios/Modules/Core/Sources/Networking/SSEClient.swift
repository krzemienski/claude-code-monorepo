import Foundation
import os.log

public final class SSEClient: NSObject, URLSessionDataDelegate {
    public struct Event { public let raw: String }

    public var onEvent: ((Event) -> Void)?
    public var onDone: (() -> Void)?
    public var onError: ((Error) -> Void)?

    private var buffer = Data()
    private var task: URLSessionDataTask?
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()
    private let log = Logger(subsystem: "com.yourorg.claudecode", category: "SSE")

    public func connect(url: URL, body: Data, headers: [String: String] = [:]) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { k, v in req.setValue(v, forHTTPHeaderField: k) }

        log.info("SSE connect %{public}@", url.absoluteString)
        task = session.dataTask(with: req)
        task?.resume()
    }

    public func stop() {
        log.info("SSE stop")
        task?.cancel()
        task = nil
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        let newline = Data("\n".utf8)

        while let r = buffer.range(of: newline) {
            let line = buffer.subdata(in: buffer.startIndex..<r.lowerBound)
            buffer.removeSubrange(buffer.startIndex...r.lowerBound)
            guard !line.isEmpty, let s = String(data: line, encoding: .utf8) else { continue }
            if s.hasPrefix("data: ") {
                let payload = String(s.dropFirst(6))
                if payload == "[DONE]" {
                    log.debug("SSE received [DONE]")
                    onDone?()
                    return
                }
                onEvent?(Event(raw: payload))
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            log.error("SSE error: %{public}@", error.localizedDescription)
            onError?(error)
        }
    }
}
