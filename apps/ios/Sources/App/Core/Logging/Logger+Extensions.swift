import Foundation
import OSLog
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Logger Extensions

extension Logger {
    // Subsystem for all app logs
    private static let subsystem = "com.claudecode.ios"
    
    // Standard loggers for different components
    static let app = Logger(subsystem: subsystem, category: "App")
    static let api = Logger(subsystem: subsystem, category: "API")
    static let sse = Logger(subsystem: subsystem, category: "SSE")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let debug = Logger(subsystem: subsystem, category: "Debug")
    
    // Log network requests
    func logRequest(_ request: URLRequest) {
        guard let url = request.url else { return }
        
        self.info("""
        🌐 REQUEST
        └─ Method: \(request.httpMethod ?? "GET")
        └─ URL: \(url.absoluteString)
        └─ Headers: \(request.allHTTPHeaderFields?.count ?? 0)
        └─ Body: \(request.httpBody?.count ?? 0) bytes
        """)
    }
    
    // Log network responses
    func logResponse(_ response: HTTPURLResponse, data: Data?, error: Error?) {
        if let error = error {
            self.error("""
            ❌ RESPONSE ERROR
            └─ URL: \(response.url?.absoluteString ?? "unknown")
            └─ Error: \(error.localizedDescription)
            """)
        } else {
            let emoji = (200..<300).contains(response.statusCode) ? "✅" : "⚠️"
            self.info("""
            \(emoji) RESPONSE
            └─ Status: \(response.statusCode)
            └─ URL: \(response.url?.absoluteString ?? "unknown")
            └─ Data: \(data?.count ?? 0) bytes
            """)
        }
    }
    
    // Log app lifecycle events
    func logLifecycle(_ event: String) {
        self.info("🔄 LIFECYCLE: \(event)")
    }
    
    // Log performance metrics
    func logPerformance(_ operation: String, duration: TimeInterval) {
        self.info("⚡ PERFORMANCE: \(operation) took \(String(format: "%.3f", duration))s")
    }
    
    // Log debug information with context
    func debugContext(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        self.debug("🔍 [\(fileName):\(line)] \(function) - \(message)")
    }
}

// MARK: - Debug Helpers

#if DEBUG
struct DebugLogger {
    static func setup() {
        // Enable verbose logging in debug builds
        Logger.app.info("🚀 Debug logging enabled")
        #if canImport(UIKit)
        Logger.app.info("📱 Device: \(UIDevice.current.name)")
        Logger.app.info("🍎 iOS: \(UIDevice.current.systemVersion)")
        #endif
        Logger.app.info("📦 Bundle: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        // Log app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            Logger.app.info("📝 Version: \(version) (\(build))")
        }
    }
    
    static func logMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            Logger.debug.info("💾 Memory usage: \(String(format: "%.1f", memoryMB)) MB")
        }
    }
}
#endif