# SwiftUI Component Catalog - Claude Code iOS

## Overview
This document catalogs all SwiftUI components in the Claude Code iOS application, their patterns, and usage guidelines.

## Component Architecture

### View Organization
The app follows a feature-based modular architecture:
```
Features/
├── Home/          # Command center dashboard
├── Projects/      # Project management views
├── Sessions/      # Chat and session management
├── MCP/          # Model Context Protocol configuration
├── Monitoring/   # System monitoring and analytics
├── Files/        # File browser and preview
├── Settings/     # Configuration and onboarding
└── Tracing/      # Debug and diagnostics
```

## Core Components

### 1. HomeView - Command Center Dashboard
**Location**: `Features/Home/HomeView.swift`
**Purpose**: Central hub for quick access to projects, sessions, and usage stats

#### Key Features:
- Quick action pills for navigation
- Recent projects list (max 3 items)
- Active sessions list (max 3 items)
- Usage highlights with metrics
- Pull-to-refresh capability

#### Custom Components:
```swift
pill(_ title: String, system: String) -> some View
// Creates navigation pills with cyberpunk theme styling

sectionCard<Content>(_ title: String, content: () -> Content) -> some View  
// Reusable card component for dashboard sections

metric(_ label: String, _ value: String) -> some View
// Displays KPI metrics in consistent format
```

#### State Management:
- `@StateObject` for AppSettings
- `@State` for local UI state (projects, sessions, stats)
- Async/await for data loading
- Error handling with alerts

### 2. SessionsView - Session Management
**Location**: `Features/Sessions/SessionsView.swift`
**Purpose**: List and manage all chat sessions

#### Key Features:
- Searchable session list
- Scope filtering (Active/All)
- Swipe actions for stopping sessions
- Live status indicators
- Token and cost display

#### State Patterns:
- Enum-based scope filtering
- Computed property for filtered results
- Refresh capability with `.refreshable`

### 3. ChatConsoleView - Real-time Chat Interface
**Location**: `Features/Sessions/ChatConsoleView.swift`
**Purpose**: Core chat experience with streaming and tool execution

#### Complex Features:
- **Dual-pane layout**: Chat transcript + Tool timeline
- **SSE streaming**: Real-time message updates
- **Tool execution tracking**: Visual status indicators
- **Dynamic composer**: Expandable text input

#### Custom Data Models:
```swift
struct ChatBubble: Identifiable, Equatable {
    enum Role: String { case user, assistant, system }
    let id = UUID()
    let role: Role
    var text: String
    let ts: Date
}

struct ToolRow: Identifiable, Equatable {
    enum State { case running, ok, error }
    let id: String
    var name: String
    var state: State
    var inputJSON: String
    var output: String
    var durationMs: Int?
    var exitCode: Int?
}
```

#### SSE Event Handling:
- Message chunks for incremental updates
- Tool use/result events
- Usage statistics updates
- Session ID establishment

### 4. ProjectsListView - Project Browser
**Location**: `Features/Projects/ProjectsListView.swift`
**Purpose**: Browse and create projects

#### Features:
- Searchable project list
- Sheet-based creation flow
- Navigation to project details
- Error handling with alerts

#### Nested Components:
- `CreateProjectSheet`: Modal form for new projects
- Uses `@Environment(\.dismiss)` for sheet control

### 5. SettingsView - Configuration Hub
**Location**: `Features/Settings/SettingsView.swift`
**Purpose**: Configure server connection and preferences

#### Key Features:
- Base URL configuration
- API key management with Keychain
- Show/Hide toggle for sensitive data
- Connection validation
- Streaming preferences
- SSE buffer configuration

#### Security Patterns:
- SecureField for API key entry
- Keychain integration for persistence
- Validation before saving

### 6. MCPSettingsView - Tool Configuration
**Location**: `Features/MCP/MCPSettingsView.swift`
**Purpose**: Configure MCP servers and tools

#### Features:
- Dynamic server list management
- Tool priority reordering
- Drag-and-drop interface
- Local persistence with @AppStorage

#### Custom Components:
- `ReorderableList`: Draggable list implementation
- Uses `EditMode` for reordering

### 7. MonitoringView - System Metrics
**Location**: `Features/Monitoring/MonitoringView.swift`
**Purpose**: Remote system monitoring via SSH

#### Features:
- SSH connection configuration
- Real-time system snapshots
- CPU/Memory/Network metrics
- Disk usage visualization
- Process list display

#### Visualization Components:
- Progress bars for disk usage
- Metric cards for KPIs
- Monospace text for process list

## Reusable UI Patterns

### 1. Card Components
```swift
// Standard card pattern used throughout
.padding()
.background(Theme.card)
.overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
.clipShape(RoundedRectangle(cornerRadius: 12))
```

### 2. Loading States
```swift
// Consistent loading indicator pattern
if isLoading { 
    ProgressView()
        .frame(maxWidth: .infinity, alignment: .center) 
}
```

### 3. Error Handling
```swift
// Standard alert presentation
.alert("Error", isPresented: .constant(err != nil), presenting: err) { _ in
    Button("OK", role: .cancel) { err = nil }
} message: { e in Text(e) }
```

### 4. Navigation Patterns
- NavigationLink for push navigation
- Sheet presentation for modals
- Toolbar items for actions

### 5. List Patterns
- Searchable modifier for filtering
- Swipe actions for quick operations
- Pull-to-refresh with .refreshable

## Theme Integration

All components use the centralized Theme enum:
- `Theme.background` - Pure black background
- `Theme.foreground` - Primary text color
- `Theme.card` - Card backgrounds
- `Theme.border` - Border strokes
- `Theme.primary/secondary` - Action colors
- `Theme.accent` - Highlights
- `Theme.destructive` - Errors/warnings
- `Theme.mutedFg` - Secondary text

## Responsive Design Patterns

### Adaptive Layouts
- GeometryReader for dynamic sizing
- Frame modifiers with min/max constraints
- Flexible spacing with Spacer()

### Text Handling
- `.lineLimit()` for controlled truncation
- Dynamic font sizes with `.font()`
- Accessibility support with semantic styles

### Performance Optimizations
- LazyVStack/LazyHStack for large lists
- ForEach with Identifiable models
- Computed properties for filtered data
- Task-based async operations

## Component Best Practices

### State Management
1. Use `@StateObject` for owned objects
2. Use `@State` for local UI state
3. Use `@Binding` for parent-child communication
4. Use `@Environment` for system features

### Async Operations
1. Use `.task` for view lifecycle loading
2. Use Task blocks for user actions
3. Defer cleanup in async functions
4. Handle errors consistently

### Navigation
1. Use NavigationView/NavigationStack
2. Pass minimal data through navigation
3. Load details in destination views
4. Use environment dismiss for modals

## Component Testing Considerations

### Unit Testing
- Test view models separately
- Mock API responses
- Test state transitions
- Verify computed properties

### UI Testing
- Test navigation flows
- Verify text input
- Test swipe actions
- Validate error states

### Accessibility Testing
- VoiceOver support
- Dynamic Type scaling
- Color contrast ratios
- Semantic labeling

## Future Enhancement Opportunities

1. **Animation Enhancements**
   - View transitions
   - Loading skeletons
   - Gesture feedback

2. **Component Library**
   - Extract reusable components
   - Create component previews
   - Document component APIs

3. **Performance Monitoring**
   - View render tracking
   - Memory usage profiling
   - Network request optimization

4. **Accessibility Improvements**
   - Custom accessibility actions
   - Improved VoiceOver hints
   - Keyboard navigation support