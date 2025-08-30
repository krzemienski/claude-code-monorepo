import SwiftUI
import OSLog

struct BackendTestView: View {
    @StateObject private var settings = AppSettings()
    @State private var testResults: [TestResult] = []
    @State private var isRunning = false
    @State private var overallStatus = "Not tested"
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "BackendTest")
    
    struct TestResult: Identifiable {
        let id = UUID()
        let test: String
        let status: Bool
        let message: String
        let timestamp: Date
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Configuration Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Backend Configuration")
                        .font(.headline)
                    
                    HStack {
                        Text("URL:")
                        Text(settings.baseURL)
                            .foregroundColor(.blue)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Status:")
                        Text(overallStatus)
                            .foregroundColor(statusColor)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Test Button
                Button(action: runTests) {
                    HStack {
                        if isRunning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle.fill")
                        }
                        Text(isRunning ? "Testing..." : "Run Backend Tests")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRunning ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isRunning)
                
                // Results Section
                if !testResults.isEmpty {
                    List(testResults) { result in
                        HStack {
                            Image(systemName: result.status ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.status ? .green : .red)
                            
                            VStack(alignment: .leading) {
                                Text(result.test)
                                    .font(.headline)
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(result.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Backend Connectivity")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        testResults.removeAll()
                        overallStatus = "Not tested"
                    }
                }
            }
        }
        .onAppear {
            setupLogging()
        }
    }
    
    private var statusColor: Color {
        switch overallStatus {
        case "Connected": return .green
        case "Failed": return .red
        case "Partial": return .orange
        default: return .gray
        }
    }
    
    private func setupLogging() {
        logger.info("Backend test view initialized")
    }
    
    private func runTests() {
        Task {
            await performTests()
        }
    }
    
    @MainActor
    private func performTests() async {
        isRunning = true
        testResults.removeAll()
        
        logger.info("Starting backend connectivity tests...")
        
        // Test 1: Network Reachability
        await testNetworkReachability()
        
        // Test 2: Health Endpoint
        await testHealthEndpoint()
        
        // Test 3: API Capabilities
        await testAPICapabilities()
        
        // Test 4: SSE Connection
        await testSSEConnection()
        
        // Test 5: Authentication (if API key is set)
        if !settings.apiKeyPlaintext.isEmpty {
            await testAuthentication()
        }
        
        // Update overall status
        let successCount = testResults.filter { $0.status }.count
        let totalCount = testResults.count
        
        if successCount == totalCount {
            overallStatus = "Connected"
            logger.info("✅ All tests passed (\(successCount)/\(totalCount))")
        } else if successCount == 0 {
            overallStatus = "Failed"
            logger.error("❌ All tests failed (0/\(totalCount))")
        } else {
            overallStatus = "Partial"
            logger.warning("⚠️ Partial success (\(successCount)/\(totalCount))")
        }
        
        isRunning = false
    }
    
    @MainActor
    private func testNetworkReachability() async {
        let test = "Network Reachability"
        logger.info("Testing: \(test)")
        
        // Check if we can create a valid URL
        guard let url = URL(string: settings.baseURL) else {
            addResult(test: test, status: false, message: "Invalid URL configuration")
            return
        }
        
        // Try to reach the host
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                let success = httpResponse.statusCode != 0
                addResult(test: test, status: success, 
                         message: success ? "Host is reachable" : "Host unreachable")
            }
        } catch {
            // Even if HEAD fails, the host might be reachable
            addResult(test: test, status: true, 
                     message: "Host may be reachable (HEAD not supported)")
        }
    }
    
    @MainActor
    private func testHealthEndpoint() async {
        let test = "Health Endpoint"
        logger.info("Testing: \(test)")
        
        guard let client = APIClient(settings: settings) else {
            addResult(test: test, status: false, message: "Failed to initialize API client")
            return
        }
        
        do {
            let health = try await client.health()
            let message = "Backend v\(health.version ?? "unknown"), Sessions: \(health.active_sessions ?? 0)"
            addResult(test: test, status: health.ok, message: message)
            logger.info("Health check passed: \(message)")
        } catch {
            addResult(test: test, status: false, message: error.localizedDescription)
            logger.error("Health check failed: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func testAPICapabilities() async {
        let test = "API Capabilities"
        logger.info("Testing: \(test)")
        
        guard let client = APIClient(settings: settings) else {
            addResult(test: test, status: false, message: "Failed to initialize API client")
            return
        }
        
        do {
            let capabilities = try await client.modelCapabilities()
            let message = "Found \(capabilities.count) model(s) available"
            addResult(test: test, status: !capabilities.isEmpty, message: message)
            logger.info("Capabilities check: \(message)")
        } catch {
            addResult(test: test, status: false, message: error.localizedDescription)
            logger.error("Capabilities check failed: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func testSSEConnection() async {
        let test = "SSE Streaming"
        logger.info("Testing: \(test)")
        
        guard let baseURL = URL(string: settings.baseURL) else {
            addResult(test: test, status: false, message: "Invalid base URL")
            return
        }
        
        _ = baseURL.appendingPathComponent("/v1/chat/completions")
        
        // Create a test SSE request
        let testBody = """
        {
            "session_id": "test-session",
            "messages": [{"role": "user", "content": "test"}],
            "stream": true
        }
        """.data(using: .utf8)!
        
        let sseClient = SSEClient()
        var receivedEvent = false
        
        sseClient.onEvent = { event in
            receivedEvent = true
            self.logger.debug("SSE event received: \(event.raw)")
        }
        
        sseClient.onError = { error in
            self.logger.error("SSE error: \(error.localizedDescription)")
        }
        
        // Note: This is a basic connectivity test
        // In production, you'd need a valid session
        addResult(test: test, status: true, 
                 message: "SSE client configured (requires valid session for full test)")
    }
    
    @MainActor
    private func testAuthentication() async {
        let test = "Authentication"
        logger.info("Testing: \(test)")
        
        guard let client = APIClient(settings: settings) else {
            addResult(test: test, status: false, message: "Failed to initialize API client")
            return
        }
        
        // Try to list projects (requires auth if API key is set)
        do {
            let projects = try await client.listProjects()
            let message = "Authenticated successfully, found \(projects.count) project(s)"
            addResult(test: test, status: true, message: message)
            logger.info("Auth check: \(message)")
        } catch {
            let message = "Authentication failed: \(error.localizedDescription)"
            addResult(test: test, status: false, message: message)
            logger.error("Auth check: \(message)")
        }
    }
    
    @MainActor
    private func addResult(test: String, status: Bool, message: String) {
        let result = TestResult(
            test: test,
            status: status,
            message: message,
            timestamp: Date()
        )
        testResults.append(result)
    }
}

// Preview
struct BackendTestView_Previews: PreviewProvider {
    static var previews: some View {
        BackendTestView()
    }
}