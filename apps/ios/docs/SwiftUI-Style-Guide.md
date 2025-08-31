# SwiftUI Style Guide - Claude Code iOS

## Table of Contents
1. [View Composition](#view-composition)
2. [State Management](#state-management)
3. [Styling & Theming](#styling--theming)
4. [Accessibility](#accessibility)
5. [Performance](#performance)
6. [Testing](#testing)
7. [Best Practices](#best-practices)
8. [Anti-Patterns](#anti-patterns)

---

## View Composition

### File Organization
```swift
// ✅ Correct: Well-organized view file
struct FeatureView: View {
    // MARK: - Properties
    @StateObject private var viewModel = FeatureViewModel()
    @State private var localState = false
    
    // MARK: - Environment
    @Environment(\.dismiss) var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    // MARK: - Body
    var body: some View {
        mainContent
            .navigationTitle("Feature")
            .toolbar { toolbarContent }
    }
    
    // MARK: - View Components
    private var mainContent: some View { ... }
    private var toolbarContent: some ToolbarContent { ... }
}
```

### View Size Guidelines
- **Maximum Lines**: 500 lines per view file
- **Extract When**: View exceeds 200 lines of body content
- **Component Threshold**: Extract reusable components when used 3+ times

### Component Extraction Pattern
```swift
// ✅ Correct: Extracted components
struct ParentView: View {
    var body: some View {
        VStack {
            HeaderComponent(title: "Title")
            ContentList(items: items)
            FooterActions(onAction: handleAction)
        }
    }
}

// Separate files for each component
struct HeaderComponent: View { ... }
struct ContentList: View { ... }
struct FooterActions: View { ... }
```

---

## State Management

### Property Wrapper Usage
```swift
// ✅ Correct usage of property wrappers
struct ExampleView: View {
    // View model lifecycle
    @StateObject private var viewModel = ViewModel()
    
    // Local UI state
    @State private var isShowingSheet = false
    
    // Parent-provided state
    @Binding var selectedItem: Item
    
    // Observable from parent
    @ObservedObject var sharedModel: SharedModel
    
    // App-wide state
    @EnvironmentObject var appState: AppState
    
    // Environment values
    @Environment(\.colorScheme) var colorScheme
    
    // Scene storage for restoration
    @SceneStorage("selection") var selection = 0
    
    // App storage for persistence
    @AppStorage("userTheme") var userTheme = "auto"
}
```

### State Management Rules
1. **@StateObject**: Use for view-owned reference types
2. **@State**: Use for view-local value types
3. **@Binding**: Use for two-way data flow with parent
4. **@ObservedObject**: Use for externally-owned observable objects
5. **@EnvironmentObject**: Use for dependency injection
6. **@SceneStorage**: Use for state restoration
7. **@AppStorage**: Use for user preferences

---

## Styling & Theming

### Theme Usage
```swift
// ✅ Correct: Always use Theme constants
Text("Title")
    .foregroundStyle(Theme.foreground)
    .font(.system(size: Theme.FontSize.lg))
    .padding(Theme.Spacing.md)

// ❌ Wrong: Hardcoded values
Text("Title")
    .foregroundColor(.black)  // Never hardcode colors
    .padding(16)               // Never hardcode spacing
```

### Custom Modifiers
```swift
// ✅ Correct: Reusable view modifiers
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.md)
            .background(Theme.card)
            .cornerRadius(Theme.CornerRadius.lg)
            .shadow(color: Theme.shadow, radius: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
```

### Adaptive Layouts
```swift
// ✅ Correct: Responsive design
struct AdaptiveView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad/landscape layout
            HStack { content }
        } else {
            // iPhone/portrait layout
            VStack { content }
        }
    }
}
```

---

## Accessibility

### Required Accessibility Modifiers
```swift
// ✅ Correct: Comprehensive accessibility
Button(action: performAction) {
    Image(systemName: "star")
}
.accessibilityLabel("Favorite")
.accessibilityHint("Add to favorites")
.accessibilityValue(isFavorite ? "Selected" : "Not selected")
.accessibilityAddTraits(isFavorite ? [.isSelected] : [])
```

### Dynamic Type Support
```swift
// ✅ Correct: Scalable fonts
Text("Content")
    .font(.system(size: Theme.FontSize.scalable(16, for: dynamicTypeSize)))
    .lineLimit(nil)  // Allow text to wrap
    .minimumScaleFactor(0.8)  // But set minimum size
```

### VoiceOver Announcements
```swift
// ✅ Correct: Screen change announcements
.onAppear {
    UIAccessibility.post(
        notification: .screenChanged,
        argument: "New screen loaded"
    )
}
```

### Touch Targets
```swift
// ✅ Correct: Minimum 44pt touch targets
Button("Tap") { ... }
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(Rectangle())  // Expand hit area
```

---

## Performance

### Lazy Loading
```swift
// ✅ Correct: Use lazy containers for lists
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
}
```

### View Identity
```swift
// ✅ Correct: Stable identifiers
ForEach(items, id: \.id) { item in
    ItemView(item: item)
}

// ❌ Wrong: Unstable identifiers
ForEach(0..<items.count) { index in
    ItemView(item: items[index])
}
```

### Task Cancellation
```swift
// ✅ Correct: Proper async task management
struct DataView: View {
    @State private var loadTask: Task<Void, Never>?
    
    var body: some View {
        content
            .task {
                loadTask = Task {
                    await loadData()
                }
            }
            .onDisappear {
                loadTask?.cancel()
            }
    }
}
```

### Animation Performance
```swift
// ✅ Correct: Respect reduce motion
@Environment(\.accessibilityReduceMotion) var reduceMotion

.animation(reduceMotion ? nil : .spring(), value: state)
```

---

## Testing

### View Testing Structure
```swift
// ✅ Correct: Testable view with dependency injection
struct FeatureView: View {
    let viewModel: FeatureViewModelProtocol
    
    init(viewModel: FeatureViewModelProtocol = FeatureViewModel()) {
        self.viewModel = viewModel
    }
}

// Test
func testFeatureView() {
    let mockViewModel = MockFeatureViewModel()
    let view = FeatureView(viewModel: mockViewModel)
    // Test view behavior
}
```

### Preview Providers
```swift
// ✅ Correct: Comprehensive previews
struct FeatureView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode
            FeatureView()
                .previewDisplayName("Light Mode")
            
            // Dark mode
            FeatureView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // Dynamic Type
            FeatureView()
                .environment(\.dynamicTypeSize, .xxxLarge)
                .previewDisplayName("Large Text")
            
            // iPad
            FeatureView()
                .previewDevice("iPad Pro (11-inch)")
                .previewDisplayName("iPad")
        }
    }
}
```

---

## Best Practices

### 1. Prefer Composition Over Inheritance
```swift
// ✅ Correct: Composition
struct ContentView: View {
    var body: some View {
        VStack {
            HeaderView()
            MainContent()
            FooterView()
        }
    }
}
```

### 2. Use ViewBuilder for Conditional Content
```swift
// ✅ Correct: ViewBuilder
@ViewBuilder
private var content: some View {
    if isLoading {
        ProgressView()
    } else {
        DataView(data: data)
    }
}
```

### 3. Minimize @State Usage
```swift
// ✅ Correct: Computed properties when possible
private var isValid: Bool {
    !text.isEmpty && text.count >= 3
}

// ❌ Wrong: Unnecessary state
@State private var isValid = false
// Then updating it manually
```

### 4. Use Environment for Cross-View Data
```swift
// ✅ Correct: Environment for theme
struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.default
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
```

---

## Anti-Patterns

### ❌ Massive Views
```swift
// Wrong: 1000+ line view file
struct MassiveView: View {
    // Hundreds of lines of properties
    // Hundreds of lines of body
    // Hundreds of lines of helper methods
}
```

### ❌ Hardcoded Values
```swift
// Wrong: Hardcoded colors and dimensions
Text("Title")
    .foregroundColor(.blue)  // Use Theme.primary
    .padding(20)             // Use Theme.Spacing.md
```

### ❌ Missing Accessibility
```swift
// Wrong: No accessibility support
Image(systemName: "star")
// Missing .accessibilityLabel()
```

### ❌ Synchronous Heavy Operations
```swift
// Wrong: Blocking the main thread
var body: some View {
    Text(expensiveComputation())  // Blocks UI
}
```

### ❌ Force Unwrapping
```swift
// Wrong: Force unwrapping optionals
Text(optionalString!)  // Crash risk
```

### ❌ Ignoring Safe Areas
```swift
// Wrong: Content under system UI
content
    .edgesIgnoringSafeArea(.all)  // Usually wrong
```

---

## Component Library Usage

Always prefer using the ComponentLibrary over creating custom implementations:

```swift
// ✅ Correct: Use ComponentLibrary
ComponentLibrary.PrimaryButton("Save") {
    saveAction()
}

ComponentLibrary.Card {
    content
}

// ❌ Wrong: Custom implementation
Button("Save") {
    saveAction()
}
.padding()
.background(Color.blue)  // Inconsistent styling
```

---

## Summary

This style guide ensures:
- **Consistent** code structure across the team
- **Accessible** interfaces for all users
- **Performant** applications with smooth interactions
- **Maintainable** code that scales with the project
- **Testable** components with clear boundaries

Follow these guidelines to create high-quality SwiftUI applications that align with the Claude Code iOS project standards.