# iOS Claude Code Project Overview

## Project Structure
- **Platform**: iOS 16+ (SwiftUI)
- **Architecture**: Modular with Core, UI, Features modules
- **Dependencies**: swift-log, swift-metrics, KeychainAccess, Charts, EventSource
- **Testing**: Unit tests, UI tests, performance tests

## Key Components
1. **App Core**: ClaudeCodeApp, RootTabView navigation
2. **Features**: Sessions/Chat, Projects, MCP, Files, Monitoring, Settings
3. **Networking**: SSEClient, ActorAPIClient (actor-based)
4. **UI Theme**: Cyberpunk theme with dark mode support
5. **Memory Management**: ActorBasedMemoryManagement, MemoryProfiler

## Recent Improvements (from agents)
- Fixed memory leaks in SSEClient
- Removed force unwrapping patterns
- Implemented actor-based synchronization
- Decomposed large views
- Added protocol abstractions

## Known Issues
- Test compilation failures (API changes)
- URL scheme registration missing
- Network connection to localhost:8000
- Swift 6 compatibility warnings

## Performance Metrics
- Launch time: <2s cold, <1s warm
- Memory: ~50MB stable
- CPU: <15% active use
- Build time: Reasonable with all deps