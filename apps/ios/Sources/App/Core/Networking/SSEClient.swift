import Foundation
import os.log

public final class SSEClient: NSObject, URLSessionDataDelegate {
    public struct Event { public let raw: String }

    public var onEvent: ((Event) -> Void)?
    public var onDone: (() -> Void)?
    public var onError: ((Error) -> Void)?
    public var onMessage: ((String) -> Void)?  // For simplified message handling
    public var onComplete: (() -> Void)?  // Alternative completion handler

    private var buffer = Data()
    private var task: URLSessionDataTask?
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()
    private let log = Logger(subsystem: "com.claudecode", category: "SSE")
    private let url: String
    private let headers: [String: String]
    private let body: Data?
    
    public init(url: String = "", headers: [String: String] = [:], body: Data? = nil) {
        self.url = url
        self.headers = headers
        self.body = body
        super.init()
    }

    public func connect(url: URL? = nil, body: Data? = nil, headers: [String: String] = [:]) {
        let connectURL = url ?? URL(string: self.url)!
        let connectBody = body ?? self.body
        let connectHeaders = headers.isEmpty ? self.headers : headers
        
        var req = URLRequest(url: connectURL)
        req.httpMethod = connectBody != nil ? "POST" : "GET"
        req.httpBody = connectBody
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        connectHeaders.forEach { k, v in req.setValue(v, forHTTPHeaderField: k) }

        log.info("SSE connect \(connectURL.absoluteString)")
        task = session.dataTask(with: req)
        task?.resume()
    }
    
    public func connect() {
        guard !url.isEmpty else {
            log.error("SSE URL is empty")
            return
        }
        connect(url: URL(string: url), body: body, headers: headers)
    }
    
    public func close() {
        stop()
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
                    onComplete?()
                    return
                }
                onEvent?(Event(raw: payload))
                onMessage?(payload)
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            log.error("SSE error: \(error.localizedDescription)")
            onError?(error)
        }
    }
}
