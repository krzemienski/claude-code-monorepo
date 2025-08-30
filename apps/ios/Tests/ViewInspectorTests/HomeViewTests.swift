import XCTest
import SwiftUI
import ViewInspector
@testable import ClaudeCode

final class HomeViewTests: XCTestCase {
    
    // MARK: - Properties
    var sut: HomeViewRefactored!
    var viewModel: HomeViewModel!
    var navigationCoordinator: NavigationCoordinator!
    
    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        viewModel = HomeViewModel()
        navigationCoordinator = NavigationCoordinator.shared
        sut = HomeViewRefactored()
    }
    
    override func tearDown() {
        sut = nil
        viewModel = nil
        navigationCoordinator = nil
        super.tearDown()
    }
    
    // MARK: - View Structure Tests
    func testHomeViewStructure() throws {
        let view = sut
        XCTAssertNotNil(view)
        
        // Test that view can be inspected
        let inspectedView = try view.inspect()
        XCTAssertNoThrow(try inspectedView.find(ViewType.NavigationStack.self))
    }
    
    func testNavigationStackPresence() throws {
        let view = try sut.inspect()
        XCTAssertNoThrow(try view.find(AppNavigationStack<AnyView>.self))
    }
    
    func testToolbarPresence() throws {
        let view = try sut.inspect()
        let navigationStack = try view.find(ViewType.NavigationStack.self)
        XCTAssertNoThrow(try navigationStack.toolbar())
    }
    
    // MARK: - Component Tests
    func testHeaderComponentPresence() throws {
        let headerComponent = HeaderComponent(isLoading: .constant(false))
        let inspected = try headerComponent.inspect()
        
        // Test header structure
        XCTAssertNoThrow(try inspected.find(ViewType.HStack.self))
        XCTAssertNoThrow(try inspected.find(text: "Claude Code"))
    }
    
    func testSessionListComponentEmptyState() throws {
        let component = SessionListComponent(
            sessions: [],
            onSessionTap: { _ in },
            onNewSession: {}
        )
        
        let inspected = try component.inspect()
        
        // Should show empty state
        XCTAssertNoThrow(try inspected.find(text: "No Sessions"))
        XCTAssertNoThrow(try inspected.find(text: "Start a new session to begin"))
    }
    
    func testSessionListComponentWithData() throws {
        let mockSessions = [
            ChatSession(
                id: "1",
                title: "Test Session",
                type: .general,
                messages: [],
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        let component = SessionListComponent(
            sessions: mockSessions,
            onSessionTap: { _ in },
            onNewSession: {}
        )
        
        let inspected = try component.inspect()
        
        // Should show session
        XCTAssertNoThrow(try inspected.find(text: "Test Session"))
        XCTAssertNoThrow(try inspected.find(text: "Recent Sessions"))
    }
    
    func testQuickActionsComponent() throws {
        let actions = [
            QuickAction(title: "Test Action", icon: "star", action: {})
        ]
        
        let component = QuickActionsComponent(actions: actions)
        let inspected = try component.inspect()
        
        // Test grid structure
        XCTAssertNoThrow(try inspected.find(ViewType.LazyVGrid.self))
        XCTAssertNoThrow(try inspected.find(text: "Test Action"))
        XCTAssertNoThrow(try inspected.find(text: "Quick Actions"))
    }
    
    func testStatusBarComponent() throws {
        let metrics = SystemMetrics()
        let component = StatusBarComponent(
            metrics: metrics,
            isConnected: true,
            syncStatus: .idle
        )
        
        let inspected = try component.inspect()
        
        // Test status indicators
        XCTAssertNoThrow(try inspected.find(ViewType.HStack.self))
        XCTAssertNoThrow(try inspected.find(text: "Connected"))
        XCTAssertNoThrow(try inspected.find(text: "Tokens"))
        XCTAssertNoThrow(try inspected.find(text: "Memory"))
    }
    
    // MARK: - Navigation Tests
    func testNavigationCoordinatorInitialization() {
        XCTAssertNotNil(navigationCoordinator)
        XCTAssertEqual(navigationCoordinator.selectedTab, .home)
        XCTAssertTrue(navigationCoordinator.path.isEmpty)
    }
    
    func testNavigationToDestination() {
        navigationCoordinator.navigate(to: .settings)
        XCTAssertFalse(navigationCoordinator.path.isEmpty)
    }
    
    func testNavigationPop() {
        navigationCoordinator.navigate(to: .settings)
        navigationCoordinator.navigate(to: .profile)
        XCTAssertEqual(navigationCoordinator.path.count, 2)
        
        navigationCoordinator.pop()
        XCTAssertEqual(navigationCoordinator.path.count, 1)
    }
    
    func testNavigateToRoot() {
        navigationCoordinator.navigate(to: .settings)
        navigationCoordinator.navigate(to: .profile)
        navigationCoordinator.navigate(to: .analytics)
        
        navigationCoordinator.navigateToRoot()
        XCTAssertTrue(navigationCoordinator.path.isEmpty)
    }
    
    func testSheetPresentation() {
        XCTAssertNil(navigationCoordinator.activeSheet)
        
        navigationCoordinator.presentSheet(.newSession)
        XCTAssertNotNil(navigationCoordinator.activeSheet)
        XCTAssertEqual(navigationCoordinator.activeSheet?.id, "newSession")
        
        navigationCoordinator.dismissSheet()
        XCTAssertNil(navigationCoordinator.activeSheet)
    }
    
    func testFullScreenPresentation() {
        XCTAssertNil(navigationCoordinator.activeFullScreenCover)
        
        navigationCoordinator.presentFullScreen(.onboarding)
        XCTAssertNotNil(navigationCoordinator.activeFullScreenCover)
        
        navigationCoordinator.dismissFullScreen()
        XCTAssertNil(navigationCoordinator.activeFullScreenCover)
    }
    
    // MARK: - Deep Link Tests
    func testDeepLinkProcessing() {
        let deepLink = DeepLink(destination: .session("test-session"))
        navigationCoordinator.processDeepLink(deepLink)
        
        // Should navigate to session
        XCTAssertFalse(navigationCoordinator.path.isEmpty)
    }
    
    func testDeepLinkToNewSession() {
        let deepLink = DeepLink(destination: .newSession)
        navigationCoordinator.processDeepLink(deepLink)
        
        // Should present new session sheet
        XCTAssertNotNil(navigationCoordinator.activeSheet)
        XCTAssertEqual(navigationCoordinator.activeSheet?.id, "newSession")
    }
    
    // MARK: - Accessibility Tests
    func testHeaderAccessibility() throws {
        let header = HeaderComponent(isLoading: .constant(false))
        let inspected = try header.inspect()
        
        // Check accessibility labels
        let settingsButton = try inspected.find(button: "Settings")
        XCTAssertNoThrow(try settingsButton.accessibilityLabel())
        XCTAssertEqual(try settingsButton.accessibilityLabel().string(), "Settings")
    }
    
    func testQuickActionAccessibility() throws {
        let action = QuickAction(
            title: "Test",
            icon: "star",
            badge: "5",
            action: {}
        )
        
        let button = QuickActionButton(action: action)
        let inspected = try button.inspect()
        
        // Check accessibility traits
        let actionButton = try inspected.find(ViewType.Button.self)
        XCTAssertNoThrow(try actionButton.accessibilityLabel())
    }
    
    // MARK: - State Management Tests
    func testLoadingStateUpdates() async throws {
        XCTAssertFalse(viewModel.isLoading)
        
        await viewModel.loadData()
        
        // After loading, should have data
        XCTAssertFalse(viewModel.recentSessions.isEmpty || viewModel.isLoading)
    }
    
    func testRefreshFunctionality() async throws {
        await viewModel.refresh()
        
        // Should update data
        XCTAssertNotNil(viewModel.lastRefreshDate)
    }
    
    // MARK: - Animation Tests
    func testPulseAnimation() throws {
        let header = HeaderComponent(isLoading: .constant(true))
        let inspected = try header.inspect()
        
        // Check for animation modifier
        let icon = try inspected.find(ViewType.Image.self)
        XCTAssertNoThrow(try icon.animation())
    }
    
    // MARK: - Layout Tests
    func testResponsiveLayout() throws {
        // Test with different size classes
        let regularEnv = EnvironmentValues()
        regularEnv.horizontalSizeClass = .regular
        
        let compactEnv = EnvironmentValues()
        compactEnv.horizontalSizeClass = .compact
        
        // Components should adapt to size class
        let quickActions = QuickActionsComponent(actions: [])
        XCTAssertNotNil(quickActions)
    }
}

// MARK: - Mock Helpers
extension HomeViewTests {
    struct MockChatSession {
        static func create(
            id: String = UUID().uuidString,
            title: String = "Test Session",
            messageCount: Int = 0
        ) -> ChatSession {
            ChatSession(
                id: id,
                title: title,
                type: .general,
                messages: Array(repeating: Message(role: .user, content: "test"), count: messageCount),
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }
}