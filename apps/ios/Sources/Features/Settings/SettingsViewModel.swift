import SwiftUI
import Combine
import Foundation
import os.log

// MARK: - Settings View Model
@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var baseURL: String = ""
    @Published var apiKeyPlaintext: String = ""
    @Published var streamingDefault: Bool = true
    @Published var sseBufferKiB: Int = 64
    @Published var showApiKey: Bool = false
    @Published var isValidating: Bool = false
    @Published var healthStatus: HealthStatus = .notValidated
    @Published var errorMessage: String?
    
    // MARK: - Health Status
    enum HealthStatus {
        case notValidated
        case healthy(version: String, sessions: Int)
        case unhealthy
        case error(String)
        
        var displayText: String {
            switch self {
            case .notValidated:
                return "Not validated"
            case .healthy(let version, let sessions):
                return "OK • v\(version) • sessions \(sessions)"
            case .unhealthy:
                return "Unhealthy"
            case .error(let message):
                return message
            }
        }
        
        var isHealthy: Bool {
            if case .healthy = self { return true }
            return false
        }
    }
    
    // MARK: - Private Properties (using Property Wrappers)
    @Injected(AppSettings.self) private var settings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode", category: "SettingsViewModel")
    
    // MARK: - Combine Publishers
    var healthStatusPublisher: AnyPublisher<HealthStatus, Never> {
        $healthStatus.eraseToAnyPublisher()
    }
    
    var validationStatusPublisher: AnyPublisher<Bool, Never> {
        $isValidating.eraseToAnyPublisher()
    }
    
    // MARK: - Computed Properties
    var canValidate: Bool {
        !baseURL.isEmpty && !isValidating
    }
    
    var hasError: Bool {
        errorMessage != nil
    }
    
    // MARK: - Initialization
    init() {
        // Dependencies are automatically injected via property wrappers
        loadSettings()
        setupSubscriptions()
    }
    
    // MARK: - Setup Methods
    private func loadSettings() {
        baseURL = settings.baseURL
        apiKeyPlaintext = settings.apiKeyPlaintext
        streamingDefault = settings.streamingDefault
        sseBufferKiB = settings.sseBufferKiB
    }
    
    private func setupSubscriptions() {
        // Sync changes back to AppSettings
        $baseURL
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.settings.baseURL = newValue
            }
            .store(in: &cancellables)
        
        $apiKeyPlaintext
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.settings.apiKeyPlaintext = newValue
            }
            .store(in: &cancellables)
        
        $streamingDefault
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.settings.streamingDefault = newValue
            }
            .store(in: &cancellables)
        
        $sseBufferKiB
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.settings.sseBufferKiB = newValue
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func toggleApiKeyVisibility() {
        showApiKey.toggle()
    }
    
    func validateAndSave() async {
        guard canValidate else {
            errorMessage = "Please enter a valid Base URL"
            return
        }
        
        isValidating = true
        errorMessage = nil
        
        // Save current values to settings
        settings.baseURL = baseURL
        settings.apiKeyPlaintext = apiKeyPlaintext
        settings.streamingDefault = streamingDefault
        settings.sseBufferKiB = sseBufferKiB
        
        guard let client = APIClient(settings: settings) else {
            errorMessage = "Invalid Base URL format"
            healthStatus = .error("Invalid URL")
            isValidating = false
            return
        }
        
        do {
            // Test connection
            let health = try await client.health()
            
            if health.ok {
                // Save API key securely
                try settings.saveAPIKey()
                
                healthStatus = .healthy(
                    version: health.version ?? "unknown",
                    sessions: health.active_sessions ?? 0
                )
                
                logger.info("Settings validated successfully: v\(health.version ?? "?")")
            } else {
                healthStatus = .unhealthy
                errorMessage = "Backend is not healthy"
                logger.warning("Backend reported unhealthy status")
            }
            
        } catch {
            errorMessage = error.localizedDescription
            healthStatus = .error("Connection failed")
            logger.error("Failed to validate settings: \(error)")
        }
        
        isValidating = false
    }
    
    func resetToDefaults() {
        baseURL = "http://localhost:8000"
        apiKeyPlaintext = ""
        streamingDefault = true
        sseBufferKiB = 64
        healthStatus = .notValidated
        errorMessage = nil
        
        // Apply to settings
        settings.baseURL = baseURL
        settings.apiKeyPlaintext = apiKeyPlaintext
        settings.streamingDefault = streamingDefault
        settings.sseBufferKiB = sseBufferKiB
        
        logger.info("Settings reset to defaults")
    }
    
    func clearError() {
        errorMessage = nil
    }
}