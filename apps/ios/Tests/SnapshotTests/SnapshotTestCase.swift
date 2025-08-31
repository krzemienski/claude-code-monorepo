import XCTest
import SwiftUI
import SnapshotTesting

/// Base class for snapshot testing SwiftUI views
open class SnapshotTestCase: XCTestCase {
    
    // MARK: - Properties
    
    /// Determines if snapshots should be recorded
    public var isRecording = false
    
    /// Default timeout for async snapshot operations
    public let snapshotTimeout: TimeInterval = 5.0
    
    /// Available test devices
    public enum TestDevice {
        case iPhone15Pro
        case iPhone15ProMax
        case iPhone14
        case iPhoneSE
        case iPadPro11
        case iPadPro13
        case iPadMini
        
        var config: ViewImageConfig {
            switch self {
            case .iPhone15Pro:
                return .iPhone15Pro
            case .iPhone15ProMax:
                return .iPhone15ProMax
            case .iPhone14:
                return .iPhone13Pro
            case .iPhoneSE:
                return .iPhoneSe
            case .iPadPro11:
                return .iPadPro11
            case .iPadPro13:
                return .iPadPro12_9
            case .iPadMini:
                return .iPadMini
            }
        }
        
        var name: String {
            switch self {
            case .iPhone15Pro: return "iPhone15Pro"
            case .iPhone15ProMax: return "iPhone15ProMax"
            case .iPhone14: return "iPhone14"
            case .iPhoneSE: return "iPhoneSE"
            case .iPadPro11: return "iPadPro11"
            case .iPadPro13: return "iPadPro13"
            case .iPadMini: return "iPadMini"
            }
        }
    }
    
    /// Test configurations
    public struct TestConfiguration {
        let colorScheme: ColorScheme
        let dynamicTypeSize: DynamicTypeSize
        let layoutDirection: LayoutDirection
        let device: TestDevice
        
        public init(
            colorScheme: ColorScheme = .light,
            dynamicTypeSize: DynamicTypeSize = .medium,
            layoutDirection: LayoutDirection = .leftToRight,
            device: TestDevice = .iPhone15Pro
        ) {
            self.colorScheme = colorScheme
            self.dynamicTypeSize = dynamicTypeSize
            self.layoutDirection = layoutDirection
            self.device = device
        }
        
        var name: String {
            var components: [String] = []
            
            if colorScheme == .dark {
                components.append("dark")
            }
            
            if dynamicTypeSize != .medium {
                components.append("a11y-\(dynamicTypeSize)")
            }
            
            if layoutDirection == .rightToLeft {
                components.append("rtl")
            }
            
            components.append(device.name)
            
            return components.joined(separator: "-")
        }
    }
    
    // MARK: - Setup
    
    open override func setUp() {
        super.setUp()
        
        // Set snapshot directory
        let fileUrl = URL(fileURLWithPath: #file)
        let sourceRoot = fileUrl
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        SnapshotTesting.diffTool = "ksdiff"
    }
    
    // MARK: - Snapshot Methods
    
    /// Assert snapshot for a SwiftUI view with default configuration
    public func assertSnapshot<Content: View>(
        of view: Content,
        named name: String? = nil,
        record: Bool? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let config = TestConfiguration()
        assertSnapshot(
            of: view,
            config: config,
            named: name,
            record: record ?? isRecording,
            file: file,
            testName: testName,
            line: line
        )
    }
    
    /// Assert snapshot for a SwiftUI view with specific configuration
    public func assertSnapshot<Content: View>(
        of view: Content,
        config: TestConfiguration,
        named name: String? = nil,
        record: Bool? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let wrappedView = view
            .environment(\.colorScheme, config.colorScheme)
            .environment(\.dynamicTypeSize, config.dynamicTypeSize)
            .environment(\.layoutDirection, config.layoutDirection)
        
        let snapshotName = [name, config.name]
            .compactMap { $0 }
            .joined(separator: "-")
        
        assertSnapshot(
            matching: wrappedView,
            as: .image(on: config.device.config),
            named: snapshotName,
            record: record ?? isRecording,
            file: file,
            testName: testName,
            line: line
        )
    }
    
    /// Assert snapshots for multiple configurations
    public func assertSnapshots<Content: View>(
        of view: Content,
        configs: [TestConfiguration],
        named name: String? = nil,
        record: Bool? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        for config in configs {
            assertSnapshot(
                of: view,
                config: config,
                named: name,
                record: record,
                file: file,
                testName: testName,
                line: line
            )
        }
    }
    
    /// Assert standard accessibility snapshots
    public func assertAccessibilitySnapshots<Content: View>(
        of view: Content,
        named name: String? = nil,
        record: Bool? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let configs = [
            // Large text
            TestConfiguration(dynamicTypeSize: .xxxLarge),
            // Extra large text with dark mode
            TestConfiguration(colorScheme: .dark, dynamicTypeSize: .xxxLarge),
            // Right-to-left
            TestConfiguration(layoutDirection: .rightToLeft)
        ]
        
        assertSnapshots(
            of: view,
            configs: configs,
            named: name,
            record: record,
            file: file,
            testName: testName,
            line: line
        )
    }
    
    /// Assert responsive design snapshots
    public func assertResponsiveSnapshots<Content: View>(
        of view: Content,
        named name: String? = nil,
        record: Bool? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let configs = [
            // iPhones
            TestConfiguration(device: .iPhoneSE),
            TestConfiguration(device: .iPhone14),
            TestConfiguration(device: .iPhone15Pro),
            TestConfiguration(device: .iPhone15ProMax),
            // iPads
            TestConfiguration(device: .iPadMini),
            TestConfiguration(device: .iPadPro11),
            TestConfiguration(device: .iPadPro13)
        ]
        
        assertSnapshots(
            of: view,
            configs: configs,
            named: name,
            record: record,
            file: file,
            testName: testName,
            line: line
        )
    }
    
    /// Assert theme snapshots (light and dark)
    public func assertThemeSnapshots<Content: View>(
        of view: Content,
        named name: String? = nil,
        record: Bool? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let configs = [
            TestConfiguration(colorScheme: .light),
            TestConfiguration(colorScheme: .dark)
        ]
        
        assertSnapshots(
            of: view,
            configs: configs,
            named: name,
            record: record,
            file: file,
            testName: testName,
            line: line
        )
    }
    
    /// Assert component states snapshots
    public func assertStateSnapshots<Content: View>(
        states: [(name: String, view: Content)],
        record: Bool? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        for state in states {
            assertThemeSnapshots(
                of: state.view,
                named: state.name,
                record: record,
                file: file,
                testName: testName,
                line: line
            )
        }
    }
}

// MARK: - View Image Config Extensions

extension ViewImageConfig {
    static let iPhone15Pro = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 393, height: 852),
        traits: UITraitCollection(
            traitsFrom: [
                UITraitCollection(displayScale: 3),
                UITraitCollection(userInterfaceStyle: .light)
            ]
        )
    )
    
    static let iPhone15ProMax = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 430, height: 932),
        traits: UITraitCollection(
            traitsFrom: [
                UITraitCollection(displayScale: 3),
                UITraitCollection(userInterfaceStyle: .light)
            ]
        )
    )
}

// MARK: - Helper Methods

extension SnapshotTestCase {
    /// Create a host view for testing with proper environment
    public func hostView<Content: View>(
        _ view: Content,
        colorScheme: ColorScheme = .light,
        dynamicTypeSize: DynamicTypeSize = .medium
    ) -> some View {
        view
            .environment(\.colorScheme, colorScheme)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
    }
    
    /// Wait for async operations in views
    public func waitForAsync(
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = XCTestExpectation(description: "Async operation")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout + 1)
    }
}