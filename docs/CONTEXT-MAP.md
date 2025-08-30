# Claude Code iOS - Comprehensive Context Map

## System Overview

### Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                         │
│  iOS SwiftUI App (iOS 17.0+) - MVVM Architecture             │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ 11 Screens (WF-01 to WF-11) with Cyberpunk Theme    │     │
│  │ Features: Home, Projects, Sessions, Chat, MCP, etc. │     │
│  └─────────────────────────────────────────────────────┘     │
└───────────────────────────┬─────────────────────────────────┘
                           │
                    HTTP/HTTPS + SSE
                           │
┌───────────────────────────┴─────────────────────────────────┐
│                       API LAYER                              │
│  FastAPI Backend (Python 3.11) - OpenAI-Compatible           │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ Endpoints: Chat, Models, Projects, Sessions, MCP    │     │
│  │ Features: SSE Streaming, Usage Tracking, Auth       │     │
│  └─────────────────────────────────────────────────────┘     │
└───────────────────────────┬─────────────────────────────────┘
                           │
                      Docker Network
                           │
┌───────────────────────────┴─────────────────────────────────┐
│                  INFRASTRUCTURE LAYER                         │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐         │
│  │ Docker       │ │ MCP Servers  │ │ Anthropic    │         │
│  │ Container    │ │ (fs, bash)   │ │ Claude API   │         │
│  └──────────────┘ └──────────────┘ └──────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## Document Relationships & Dependencies

### Core Specifications (Requirements)
- **00-Project-Overview.md**: Master index and navigation guide
- **01-Backend-API.md**: Complete API contracts and endpoints
- **02-Swift-Data-Models.md**: Swift Codable models matching API
- **03-Screens-API-Mapping.md**: UI screens to API endpoint mapping
- **04-Theming-Typography.md**: Cyberpunk design system specification
- **05-Wireframes.md**: ASCII wireframes for all 11 screens
- **06-MCP-Configuration-Tools.md**: MCP server and tool integration

### Implementation Analysis (Current State)
- **Backend-Architecture-Analysis.md**: FastAPI implementation details
- **iOS-Architecture-Analysis.md**: SwiftUI app structure and patterns
- **SwiftUI-Architecture-Analysis.md**: Performance and optimization analysis

### Validation & Compliance Reports
- **API-Contract-Validation.md**: API implementation verification
- **SwiftUI-Design-System-Compliance.md**: Theme implementation status
- **iOS-Dependency-Validation-Report.md**: Package dependency analysis

## Traceability Matrix

### Requirements to Implementation Mapping

| Requirement | Specification | Implementation | Status |
|------------|---------------|----------------|--------|
| **API Endpoints** | 01-Backend-API.md | Backend FastAPI | ✅ Implemented |
| **Data Models** | 02-Swift-Data-Models.md | APIClient.swift models | ✅ Implemented |
| **UI Screens** | 05-Wireframes.md | SwiftUI Views | ✅ Implemented |
| **Theme Colors** | 04-Theming.md | Theme.swift | ⚠️ Partial (colors need update) |
| **SSE Streaming** | 01-Backend-API.md | SSEClient.swift | ✅ Implemented |
| **MCP Tools** | 06-MCP-Configuration.md | MCPSettingsView.swift | ✅ Implemented |
| **Authentication** | 01-Backend-API.md | KeychainService.swift | ✅ Implemented |
| **Session Management** | 01-Backend-API.md | Session endpoints | ✅ Implemented |
| **Project Management** | 01-Backend-API.md | Project endpoints | ✅ Implemented |
| **Analytics** | 03-Screens-API.md | MonitoringView.swift | ✅ Implemented |

## Screen to API Endpoint Mapping

| Screen | Wireframe | Primary Endpoints | Implementation |
|--------|-----------|------------------|----------------|
| Settings | WF-01 | GET /health | SettingsView.swift |
| Home | WF-02 | GET /v1/projects, /v1/sessions | HomeView.swift |
| Projects List | WF-03 | GET/POST /v1/projects | ProjectsListView.swift |
| Project Detail | WF-04 | GET /v1/projects/{id} | ProjectDetailView.swift |
| New Session | WF-05 | POST /v1/sessions | NewSessionView.swift |
| Chat Console | WF-06 | POST /v1/chat/completions | ChatConsoleView.swift |
| Models | WF-07 | GET /v1/models | ModelsView.swift |
| Analytics | WF-08 | GET /v1/sessions/stats | MonitoringView.swift |
| Diagnostics | WF-09 | POST /v1/chat/completions/debug | TracingView.swift |
| MCP Settings | WF-10 | GET /v1/mcp/servers | MCPSettingsView.swift |
| Tool Picker | WF-11 | POST /v1/sessions/{id}/tools | SessionToolPickerView.swift |

## Key Technical Decisions

### iOS Application
- **Platform**: iOS 17.0+ (latest features, SwiftUI 5)
- **Architecture**: MVVM-lite with direct API integration
- **State Management**: @StateObject, @State, @Published
- **Networking**: URLSession with async/await
- **Security**: Keychain for API keys
- **UI Framework**: 100% SwiftUI (no UIKit)

### Backend API
- **Framework**: FastAPI (high performance, async)
- **Protocol**: RESTful + SSE for streaming
- **Container**: Docker with multi-stage builds
- **Authentication**: Bearer token or API key
- **External Services**: Anthropic Claude API, MCP servers

### Design System
- **Theme**: Cyberpunk dark mode
- **Colors**: Neon cyan (#00FFE1) and magenta (#FF2A6D) accents
- **Typography**: SF Pro Text (UI), JetBrains Mono (code)
- **Animation**: Springy transitions (180-240ms)

## Critical Dependencies

### iOS Dependencies (via SPM)
- swift-log: Structured logging
- swift-metrics: Performance tracking
- eventsource: SSE client
- KeychainAccess: Secure storage
- Charts/DGCharts: Data visualization
- Shout: SSH capabilities

### Backend Dependencies
- FastAPI: Web framework
- Anthropic SDK: Claude API integration
- Claude Code CLI: MCP integration
- uvicorn: ASGI server

## Known Issues & Improvements Needed

### High Priority
1. **Theme Colors**: Update to match specification (#00FFE1, #FF2A6D)
2. **Code Font**: Install JetBrains Mono
3. **Testing**: No test targets defined
4. **Performance**: Implement view memoization and stream buffering

### Medium Priority
1. **Accessibility**: Add VoiceOver support and Dynamic Type
2. **Error Handling**: Implement retry logic and better messages
3. **Caching**: Add response caching layer
4. **Component Library**: Extract reusable UI components

### Low Priority
1. **Animations**: Add shimmer effect for streaming
2. **Haptics**: Implement feedback for interactions
3. **Offline Mode**: Add local storage and sync

## Integration Points

### iOS → Backend
- APIClient.swift → FastAPI endpoints
- SSEClient.swift → SSE streaming endpoint
- KeychainService → Bearer token auth

### Backend → External
- FastAPI → Anthropic Claude API
- FastAPI → MCP servers (fs, bash, etc.)
- Docker → Host filesystem (/workspace mount)

## Configuration Requirements

### iOS App
- Base URL: http://localhost:8000 (configurable)
- API Key: Stored in Keychain
- ATS Exception: Required for local HTTP

### Backend
- ANTHROPIC_API_KEY: Required environment variable
- PORT: 8000 (default)
- Workspace: ./files/workspace → /workspace

## Development Workflow

### iOS Development
1. Generate project: `cd apps/ios && ./Scripts/bootstrap.sh`
2. Open in Xcode: ClaudeCode.xcodeproj
3. Build & Run: Cmd+R (iOS Simulator)

### Backend Development
1. Setup: `cp .env.example .env` and add API key
2. Start: `make up` or `docker-compose up`
3. Verify: `curl http://localhost:8000/health`
4. Logs: `make logs`

## System Capabilities

### Core Features
- Real-time chat with Claude via streaming
- Project and session management
- Model selection and capabilities
- MCP tool integration (file ops, bash, etc.)
- Usage tracking and cost monitoring
- Analytics and diagnostics

### Advanced Features
- SSH remote system monitoring
- File browser with preview
- Tool execution timeline
- Session-specific tool configuration
- Priority ordering for tools
- Audit logging for security

## Future Enhancements

### Phase 1 (Immediate)
- Fix theme color compliance
- Add comprehensive testing
- Implement performance optimizations

### Phase 2 (Short-term)
- Add accessibility features
- Implement caching strategy
- Create component library

### Phase 3 (Long-term)
- Offline mode support
- Widget extensions
- Push notifications
- Siri shortcuts

## Conclusion

This comprehensive context map provides a complete understanding of the Claude Code iOS system, including:
- Full system architecture across all layers
- Complete requirements traceability
- Implementation status and gaps
- Integration points and dependencies
- Development workflows and configuration

The system is well-architected with clear separation of concerns, modern technology choices, and a solid foundation for future enhancements. Key areas for improvement include theme compliance, testing infrastructure, and performance optimizations.