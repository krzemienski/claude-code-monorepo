import SwiftUI
import Combine
import PhotosUI
import os.log

// MARK: - Profile View Model
@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var displayName: String = ""
    @Published var bio: String = ""
    @Published var avatarData: Data?
    @Published var apiKey: String = ""
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var showingImagePicker: Bool = false
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var isSaving: Bool = false
    @Published var connectionStatus: String = "Not Connected"
    @Published var hasUnsavedChanges: Bool = false
    
    // Settings
    @Published var enableStreaming: Bool = true
    @Published var darkModeEnabled: Bool = true
    @Published var reduceMotion: Bool = false
    @Published var notificationsEnabled: Bool = true
    @Published var soundEnabled: Bool = true
    
    // MARK: - Private Properties
    @Injected(APIClientProtocol.self) private var apiClient: APIClientProtocol
    @Injected(AppSettings.self) private var settings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode", category: "ProfileViewModel")
    
    // MARK: - User Profile Model
    struct UserProfile: Codable {
        let id: String
        var username: String
        var email: String
        var displayName: String?
        var bio: String?
        var avatarUrl: String?
        var preferences: UserPreferences?
        let createdAt: String
        let updatedAt: String
        
        struct UserPreferences: Codable {
            var enableStreaming: Bool
            var darkMode: Bool
            var reduceMotion: Bool
            var notifications: Bool
            var sounds: Bool
        }
    }
    
    // MARK: - Initialization
    init() {
        setupBindings()
        Task { await loadProfile() }
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor changes
        Publishers.CombineLatest4($username, $email, $displayName, $bio)
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
        
        // Photo selection
        $selectedPhoto
            .compactMap { $0 }
            .sink { [weak self] item in
                Task {
                    await self?.loadPhoto(from: item)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func loadProfile() async {
        isLoading = true
        error = nil
        
        do {
            // Load from API if available
            let profile = try await fetchProfileFromAPI()
            await updateUI(with: profile)
        } catch {
            // Fallback to local settings
            loadFromLocalSettings()
            logger.error("Failed to load profile: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    func saveProfile() async {
        isSaving = true
        error = nil
        
        do {
            let profile = createProfileFromUI()
            try await saveProfileToAPI(profile)
            saveToLocalSettings()
            hasUnsavedChanges = false
            logger.info("Profile saved successfully")
        } catch {
            logger.error("Failed to save profile: \(error)")
            self.error = error
        }
        
        isSaving = false
    }
    
    func testAPIConnection() async {
        connectionStatus = "Testing..."
        error = nil
        
        do {
            // Test with saved API key
            settings.apiKeyPlaintext = apiKey
            let health = try await apiClient.health()
            connectionStatus = health.ok ? "Connected ✅" : "Connection Failed ❌"
            logger.info("API connection test: \(health.ok)")
        } catch {
            connectionStatus = "Connection Failed ❌"
            self.error = error
            logger.error("API connection test failed: \(error)")
        }
    }
    
    func uploadAvatar() async {
        showingImagePicker = true
    }
    
    func deleteAvatar() async {
        avatarData = nil
        hasUnsavedChanges = true
    }
    
    // MARK: - Private Methods
    private func fetchProfileFromAPI() async throws -> UserProfile {
        // Mock implementation - replace with actual API call
        // let response = try await apiClient.getJSON("/v1/user/profile", as: UserProfile.self)
        throw URLError(.notConnectedToInternet) // Temporary fallback
    }
    
    private func saveProfileToAPI(_ profile: UserProfile) async throws {
        // Mock implementation - replace with actual API call
        // try await apiClient.postJSON("/v1/user/profile", body: profile, as: UserProfile.self)
    }
    
    private func updateUI(with profile: UserProfile) async {
        username = profile.username
        email = profile.email
        displayName = profile.displayName ?? ""
        bio = profile.bio ?? ""
        
        if let preferences = profile.preferences {
            enableStreaming = preferences.enableStreaming
            darkModeEnabled = preferences.darkMode
            reduceMotion = preferences.reduceMotion
            notificationsEnabled = preferences.notifications
            soundEnabled = preferences.sounds
        }
        
        // Load avatar if available
        if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
            await loadAvatar(from: url)
        }
    }
    
    private func createProfileFromUI() -> UserProfile {
        UserProfile(
            id: UUID().uuidString,
            username: username,
            email: email,
            displayName: displayName.isEmpty ? nil : displayName,
            bio: bio.isEmpty ? nil : bio,
            avatarUrl: nil,
            preferences: UserProfile.UserPreferences(
                enableStreaming: enableStreaming,
                darkMode: darkModeEnabled,
                reduceMotion: reduceMotion,
                notifications: notificationsEnabled,
                sounds: soundEnabled
            ),
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    private func loadFromLocalSettings() {
        username = settings.username ?? "User"
        email = settings.email ?? "user@example.com"
        apiKey = settings.apiKeyPlaintext
        
        // Load preferences from UserDefaults
        let defaults = UserDefaults.standard
        enableStreaming = defaults.bool(forKey: "enableStreaming")
        darkModeEnabled = defaults.bool(forKey: "darkMode")
        reduceMotion = defaults.bool(forKey: "reduceMotion")
        notificationsEnabled = defaults.bool(forKey: "notifications")
        soundEnabled = defaults.bool(forKey: "sounds")
    }
    
    private func saveToLocalSettings() {
        settings.username = username
        settings.email = email
        settings.apiKeyPlaintext = apiKey
        
        // Save preferences to UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(enableStreaming, forKey: "enableStreaming")
        defaults.set(darkModeEnabled, forKey: "darkMode")
        defaults.set(reduceMotion, forKey: "reduceMotion")
        defaults.set(notificationsEnabled, forKey: "notifications")
        defaults.set(soundEnabled, forKey: "sounds")
    }
    
    private func loadPhoto(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                avatarData = data
                hasUnsavedChanges = true
                logger.info("Photo loaded successfully")
            }
        } catch {
            logger.error("Failed to load photo: \(error)")
            self.error = error
        }
    }
    
    private func loadAvatar(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            avatarData = data
        } catch {
            logger.error("Failed to load avatar: \(error)")
        }
    }
}