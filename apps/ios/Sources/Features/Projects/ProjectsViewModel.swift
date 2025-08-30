import SwiftUI
import Combine
import Foundation
import os.log

// MARK: - Projects View Model
@MainActor
final class ProjectsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var projects: [APIClient.Project] = []
    @Published var filteredProjects: [APIClient.Project] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var showCreateSheet: Bool = false
    @Published var sortOrder: SortOrder = .name
    
    // MARK: - Sort Order
    enum SortOrder {
        case name
        case createdDate
        case modifiedDate
        case path
        
        var displayName: String {
            switch self {
            case .name: return "Name"
            case .createdDate: return "Created"
            case .modifiedDate: return "Modified"
            case .path: return "Path"
            }
        }
    }
    
    // MARK: - Private Properties (using Property Wrappers)
    @Injected(APIClientProtocol.self) private var apiClient: APIClientProtocol
    @Injected(AppSettings.self) private var settings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode", category: "ProjectsViewModel")
    
    // MARK: - Combine Publishers
    var projectsPublisher: AnyPublisher<[APIClient.Project], Never> {
        $projects.eraseToAnyPublisher()
    }
    
    var loadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }
    
    // MARK: - Computed Properties
    var hasProjects: Bool {
        !projects.isEmpty
    }
    
    var hasError: Bool {
        error != nil
    }
    
    var errorMessage: String? {
        error?.localizedDescription
    }
    
    // MARK: - Initialization
    init() {
        // Dependencies are automatically injected via property wrappers
        setupSubscriptions()
    }
    
    // MARK: - Setup Methods
    private func setupSubscriptions() {
        // Filter projects when search text changes
        Publishers.CombineLatest($searchText, $projects)
            .map { searchText, projects in
                guard !searchText.isEmpty else { return projects }
                return projects.filter { project in
                    project.name.localizedCaseInsensitiveContains(searchText) ||
                    (project.path ?? "").localizedCaseInsensitiveContains(searchText) ||
                    (project.description ?? "").localizedCaseInsensitiveContains(searchText)
                }
            }
            .assign(to: &$filteredProjects)
        
        // Sort projects when sort order changes
        $sortOrder
            .combineLatest($filteredProjects)
            .map { [weak self] sortOrder, projects in
                self?.sortProjects(projects, by: sortOrder) ?? projects
            }
            .assign(to: &$filteredProjects)
    }
    
    // MARK: - Public Methods
    func loadProjects() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let loadedProjects = try await apiClient.listProjects()
            
            await MainActor.run {
                self.projects = loadedProjects
                self.logger.info("Loaded \(loadedProjects.count) projects")
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.logger.error("Failed to load projects: \(error)")
            }
        }
        
        isLoading = false
    }
    
    func createProject(name: String, description: String, path: String?) async {
        guard !name.isEmpty else {
            error = NSError(domain: "ProjectsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Project name cannot be empty"])
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let project = try await apiClient.createProject(
                name: name,
                description: description,
                path: path
            )
            
            // Reload projects to ensure consistency
            await loadProjects()
            
            showCreateSheet = false
            logger.info("Created project: \(project.id) - \(project.name)")
            
        } catch {
            self.error = error
            logger.error("Failed to create project: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteProject(_ project: APIClient.Project) async {
        error = nil
        
        // Optimistically remove from list
        await MainActor.run {
            self.projects.removeAll { $0.id == project.id }
        }
        
        // Note: API doesn't currently support deletion, but the pattern is here
        logger.info("Project deletion requested for: \(project.id)")
        
        // Reload to ensure consistency
        await loadProjects()
    }
    
    func refresh() async {
        await loadProjects()
    }
    
    func clearError() {
        error = nil
    }
    
    func toggleCreateSheet() {
        showCreateSheet.toggle()
    }
    
    // MARK: - Private Methods
    private func sortProjects(_ projects: [APIClient.Project], by order: SortOrder) -> [APIClient.Project] {
        switch order {
        case .name:
            return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .createdDate:
            // Sort by createdAt string (ISO 8601 format sorts correctly as strings)
            return projects.sorted { $0.createdAt > $1.createdAt }
        case .modifiedDate:
            // Sort by updatedAt string (ISO 8601 format sorts correctly as strings)
            return projects.sorted { $0.updatedAt > $1.updatedAt }
        case .path:
            return projects.sorted { 
                ($0.path ?? "").localizedCaseInsensitiveCompare($1.path ?? "") == .orderedAscending 
            }
        }
    }
}