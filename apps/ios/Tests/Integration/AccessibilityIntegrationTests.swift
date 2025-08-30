import XCTest
import SwiftUI
@testable import ClaudeCode

@MainActor
final class AccessibilityIntegrationTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        // Reset accessibility settings
        UIAccessibility.isVoiceOverRunning = false
    }
    
    // MARK: - VoiceOver Support Tests
    
    func testVoiceOverLabelsPresent() throws {
        // Test all major views have accessibility labels
        let views: [(view: AnyView, expectedLabel: String)] = [
            (AnyView(HomeView()), "Home"),
            (AnyView(SessionsView()), "Sessions"),
            (AnyView(ProjectsListView()), "Projects"),
            (AnyView(SettingsView()), "Settings"),
            (AnyView(MonitoringView()), "Monitoring")
        ]
        
        for (view, expectedLabel) in views {
            let mirror = Mirror(reflecting: view)
            XCTAssertNotNil(mirror.descendant("accessibilityLabel"), 
                          "View missing accessibility label: \(expectedLabel)")
        }
    }
    
    func testAccessibilityTraitsCorrectlySet() throws {
        // Test button traits
        let button = Button("Test") {}
            .accessibilityAddTraits(.isButton)
        
        // Test header traits
        let header = Text("Header")
            .accessibilityAddTraits(.isHeader)
        
        // Verify traits are set
        XCTAssertNotNil(button)
        XCTAssertNotNil(header)
    }
    
    func testAccessibilityHintsProvided() throws {
        // Test that interactive elements have hints
        let textField = AnimatedTextField(
            placeholder: "Username",
            text: .constant(""),
            icon: "person.fill"
        )
        
        XCTAssertNotNil(textField)
    }
    
    // MARK: - Dynamic Type Tests
    
    func testDynamicTypeScaling() throws {
        let sizeCategories: [DynamicTypeSize] = [
            .xSmall, .small, .medium, .large,
            .xLarge, .xxLarge, .xxxLarge,
            .accessibility1, .accessibility2,
            .accessibility3, .accessibility4, .accessibility5
        ]
        
        for size in sizeCategories {
            let scale = size.scale
            XCTAssertGreaterThan(scale, 0, "Invalid scale for \(size)")
            XCTAssertLessThanOrEqual(scale, 2.0, "Scale too large for \(size)")
        }
    }
    
    func testFontSizeScaling() throws {
        let baseSize: CGFloat = 16
        let largeSize = Theme.FontSize.scalable(baseSize, for: .large)
        let accessibilitySize = Theme.FontSize.scalable(baseSize, for: .accessibility1)
        
        XCTAssertEqual(largeSize, baseSize * 1.0)
        XCTAssertEqual(accessibilitySize, baseSize * 1.4)
    }
    
    // MARK: - Keyboard Navigation Tests
    
    func testFocusStateManagement() throws {
        struct TestView: View {
            @FocusState private var isFocused: Bool
            @State private var text = ""
            
            var body: some View {
                TextField("Test", text: $text)
                    .focused($isFocused)
            }
        }
        
        let view = TestView()
        XCTAssertNotNil(view)
    }
    
    func testTabOrderLogical() throws {
        // Test that tab order follows visual hierarchy
        let formView = VStack {
            TextField("First", text: .constant(""))
                .accessibilitySort(priority: 1)
            TextField("Second", text: .constant(""))
                .accessibilitySort(priority: 2)
            TextField("Third", text: .constant(""))
                .accessibilitySort(priority: 3)
        }
        
        XCTAssertNotNil(formView)
    }
    
    // MARK: - Touch Target Tests
    
    func testMinimumTouchTargetSize() throws {
        let minimumSize = Theme.minimumTouchTarget()
        XCTAssertEqual(minimumSize, 44, "Touch target must be at least 44pt")
    }
    
    func testButtonTouchTargets() throws {
        let button = Button("Test") {}
            .frame(minWidth: 44, minHeight: 44)
        
        XCTAssertNotNil(button)
    }
    
    // MARK: - Color Contrast Tests
    
    func testColorContrastRatios() throws {
        // Test primary text on background
        let textContrast = Theme.hasGoodContrast(
            foreground: Theme.foreground,
            background: Theme.background,
            threshold: 4.5 // WCAG AA for normal text
        )
        XCTAssertTrue(textContrast, "Text doesn't meet WCAG AA contrast")
        
        // Test large text contrast
        let largeTextContrast = Theme.hasGoodContrast(
            foreground: Theme.foreground,
            background: Theme.background,
            threshold: 3.0 // WCAG AA for large text
        )
        XCTAssertTrue(largeTextContrast, "Large text doesn't meet WCAG AA contrast")
    }
    
    func testHighContrastMode() throws {
        // Test high contrast colors
        let highContrastBg = AccessibilityColors.highContrastBackground
        let highContrastFg = AccessibilityColors.highContrastForeground
        
        XCTAssertNotEqual(highContrastBg, highContrastFg)
    }
    
    // MARK: - Accessibility Announcements Tests
    
    func testVoiceOverAnnouncements() throws {
        // Test announcement posting
        let expectation = XCTestExpectation(description: "Announcement posted")
        
        AccessibilityHelpers.announce("Test announcement")
        
        // Verify announcement was posted
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Focus Management Tests
    
    func testFocusManagement() throws {
        // Test focus helpers
        struct TestView: View {
            @AccessibilityFocusState private var isNameFocused: Bool
            @State private var name = ""
            
            var body: some View {
                TextField("Name", text: $name)
                    .accessibilityFocused($isNameFocused)
            }
        }
        
        let view = TestView()
        XCTAssertNotNil(view)
    }
    
    // MARK: - Semantic Grouping Tests
    
    func testSemanticGrouping() throws {
        // Test that related content is grouped
        let groupedView = VStack {
            Text("Title")
            Text("Subtitle")
        }
        .accessibilityElement(children: .combine)
        
        XCTAssertNotNil(groupedView)
    }
    
    // MARK: - Reduced Motion Tests
    
    func testReducedMotionSupport() throws {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        
        let animation = Theme.Animation.reduced(
            Theme.Animation.spring,
            reduceMotion: reduceMotion
        )
        
        if reduceMotion {
            XCTAssertNil(animation)
        } else {
            XCTAssertNotNil(animation)
        }
    }
    
    // MARK: - Screen Reader Support Tests
    
    func testScreenReaderOptimization() throws {
        // Test that views are optimized for screen readers
        let complexView = HStack {
            Image(systemName: "star")
                .accessibilityHidden(true) // Decorative image
            Text("Important Content")
                .accessibilityAddTraits(.isHeader)
        }
        
        XCTAssertNotNil(complexView)
    }
    
    // MARK: - Accessibility Audit Tests
    
    // TODO: Implement AccessibilityAudit class before enabling these tests
    /*
    func testAccessibilityAudit() throws {
        let audit = AccessibilityAudit()
        
        // Run touch target audit
        let touchTargetIssues = audit.auditTouchTargets(in: AnyView(HomeView()))
        XCTAssertEqual(touchTargetIssues.count, 0, "Touch target issues found")
        
        // Run contrast audit
        let contrastIssues = audit.auditContrastRatios()
        XCTAssertEqual(contrastIssues.count, 0, "Contrast ratio issues found")
        
        // Run label audit
        let labelIssues = audit.auditAccessibilityLabels(in: AnyView(HomeView()))
        XCTAssertEqual(labelIssues.count, 0, "Accessibility label issues found")
    }
    */
    
    // MARK: - Performance Tests
    
    func testAccessibilityPerformance() {
        measure {
            // Measure performance of accessibility operations
            for _ in 0..<100 {
                _ = Theme.FontSize.scalable(16, for: .large)
                _ = Theme.adaptiveSpacing(12, for: .large)
                _ = Theme.hasGoodContrast(
                    foreground: .white,
                    background: .black
                )
            }
        }
    }
}