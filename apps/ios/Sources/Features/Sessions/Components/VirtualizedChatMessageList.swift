import SwiftUI
import Combine

/// Virtualized chat message list with lazy loading and efficient scrolling
/// Addresses performance issues identified with >100 messages
public struct VirtualizedChatMessageList: View {
    // MARK: - Properties
    let messages: [ChatMessage]
    @Binding var scrollToBottom: Bool
    let onToolTapped: (ToolExecution) -> Void
    
    // Performance configuration
    private let visibleMessageBuffer = 20 // Messages to keep in memory above/below viewport
    private let batchSize = 50 // Messages to load at once
    private let scrollThreshold: CGFloat = 100 // Distance from edge to trigger loading
    
    // State management
    @State private var visibleMessages: [ChatMessage] = []
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var isLoadingMore = false
    @State private var currentRange: Range<Int> = 0..<0
    
    // Memory management
    @StateObject private var memoryMonitor = ChatMemoryMonitor()
    
    // Namespace for scroll anchor
    @Namespace private var bottomAnchor
    
    // Environment
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // MARK: - Body
    public var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Top spacer for virtualization
                        if currentRange.lowerBound > 0 {
                            Color.clear
                                .frame(height: calculateTopSpacerHeight())
                                .id("top_spacer")
                        }
                        
                        // Visible messages with lazy loading
                        LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            ForEach(visibleMessages) { message in
                                VirtualizedMessageRow(
                                    message: message,
                                    onToolTapped: onToolTapped,
                                    onAppear: {
                                        checkLoadMoreIfNeeded(for: message)
                                    }
                                )
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        
                        // Bottom spacer for virtualization
                        if currentRange.upperBound < messages.count {
                            Color.clear
                                .frame(height: calculateBottomSpacerHeight())
                                .id("bottom_spacer")
                        }
                        
                        // Bottom anchor for scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .background(
                        GeometryReader { scrollGeometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: scrollGeometry.frame(in: .global).minY
                                )
                        }
                    )
                }
                .background(Theme.background)
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    handleScrollChange(offset: value, in: geometry)
                }
                .onChange(of: messages.count) { _ in
                    updateVisibleMessages(in: geometry)
                    
                    if scrollToBottom {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: scrollToBottom) { shouldScroll in
                    if shouldScroll {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    initializeVirtualization(in: geometry)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            performanceOverlay
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message list")
        .accessibilityHint("\(messages.count) messages, showing \(visibleMessages.count)")
    }
    
    // MARK: - Virtualization Logic
    
    private func initializeVirtualization(in geometry: GeometryProxy) {
        viewportHeight = geometry.size.height
        
        // Calculate initial visible range
        let initialCount = min(batchSize, messages.count)
        currentRange = max(0, messages.count - initialCount)..<messages.count
        visibleMessages = Array(messages[currentRange])
    }
    
    private func updateVisibleMessages(in geometry: GeometryProxy) {
        // Calculate which messages should be visible based on scroll position
        let estimatedMessageHeight: CGFloat = 100 // Average message height
        let viewportTop = -scrollOffset
        let viewportBottom = viewportTop + viewportHeight
        
        // Calculate index range
        let startIndex = max(0, Int(viewportTop / estimatedMessageHeight) - visibleMessageBuffer)
        let endIndex = min(messages.count, Int(viewportBottom / estimatedMessageHeight) + visibleMessageBuffer)
        
        let newRange = startIndex..<endIndex
        
        // Only update if range changed significantly
        if abs(newRange.lowerBound - currentRange.lowerBound) > 5 ||
           abs(newRange.upperBound - currentRange.upperBound) > 5 {
            
            withAnimation(.easeInOut(duration: 0.2)) {
                currentRange = newRange
                visibleMessages = Array(messages[currentRange])
            }
            
            // Check memory pressure
            if memoryMonitor.isUnderPressure {
                reduceVisibleRange()
            }
        }
    }
    
    private func handleScrollChange(offset: CGFloat, in geometry: GeometryProxy) {
        scrollOffset = offset
        
        // Check if we need to load more messages
        if !isLoadingMore {
            let distanceFromTop = -offset
            let distanceFromBottom = contentHeight - (-offset + viewportHeight)
            
            if distanceFromTop < scrollThreshold && currentRange.lowerBound > 0 {
                loadMoreMessages(direction: .up)
            } else if distanceFromBottom < scrollThreshold && currentRange.upperBound < messages.count {
                loadMoreMessages(direction: .down)
            }
        }
        
        // Update visible messages based on scroll position
        updateVisibleMessages(in: geometry)
    }
    
    private func loadMoreMessages(direction: ScrollDirection) {
        isLoadingMore = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                switch direction {
                case .up:
                    let newStart = max(0, currentRange.lowerBound - batchSize)
                    currentRange = newStart..<currentRange.upperBound
                    
                case .down:
                    let newEnd = min(messages.count, currentRange.upperBound + batchSize)
                    currentRange = currentRange.lowerBound..<newEnd
                }
                
                visibleMessages = Array(messages[currentRange])
                isLoadingMore = false
            }
        }
    }
    
    private func checkLoadMoreIfNeeded(for message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        
        // Load more if approaching edges
        if index <= currentRange.lowerBound + 5 && currentRange.lowerBound > 0 {
            loadMoreMessages(direction: .up)
        } else if index >= currentRange.upperBound - 5 && currentRange.upperBound < messages.count {
            loadMoreMessages(direction: .down)
        }
    }
    
    private func reduceVisibleRange() {
        // Reduce visible range when under memory pressure
        let reducedBuffer = visibleMessageBuffer / 2
        let center = currentRange.lowerBound + (currentRange.count / 2)
        
        let newStart = max(0, center - reducedBuffer)
        let newEnd = min(messages.count, center + reducedBuffer)
        
        currentRange = newStart..<newEnd
        visibleMessages = Array(messages[currentRange])
    }
    
    // MARK: - Spacer Calculations
    
    private func calculateTopSpacerHeight() -> CGFloat {
        // Estimate height of messages above visible range
        let hiddenMessages = currentRange.lowerBound
        return CGFloat(hiddenMessages) * 100 // Estimated message height
    }
    
    private func calculateBottomSpacerHeight() -> CGFloat {
        // Estimate height of messages below visible range
        let hiddenMessages = messages.count - currentRange.upperBound
        return CGFloat(hiddenMessages) * 100 // Estimated message height
    }
    
    // MARK: - Performance Overlay
    
    @ViewBuilder
    private var performanceOverlay: some View {
        if ProcessInfo.processInfo.environment["SHOW_PERFORMANCE"] != nil {
            VStack(alignment: .trailing, spacing: 4) {
                Text("Total: \(messages.count)")
                Text("Visible: \(visibleMessages.count)")
                Text("Range: \(currentRange.lowerBound)-\(currentRange.upperBound)")
                Text("Memory: \(String(format: "%.1f", memoryMonitor.currentUsageMB))MB")
            }
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .padding()
        }
    }
    
    // MARK: - Types
    
    private enum ScrollDirection {
        case up, down
    }
}

// MARK: - Virtualized Message Row
private struct VirtualizedMessageRow: View {
    let message: ChatMessage
    let onToolTapped: (ToolExecution) -> Void
    let onAppear: () -> Void
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State private var isVisible = false
    
    var body: some View {
        ChatMessageRow(
            message: message,
            onToolTapped: onToolTapped
        )
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                isVisible = true
            }
            onAppear()
        }
        .onDisappear {
            isVisible = false
        }
    }
}

// MARK: - Scroll Offset Preference Key
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Memory Monitor
private class ChatMemoryMonitor: ObservableObject {
    @Published var currentUsageMB: Double = 0
    @Published var isUnderPressure = false
    
    private var timer: Timer?
    private let pressureThresholdMB: Double = 200
    
    init() {
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateMemoryUsage()
        }
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                        task_flavor_t(MACH_TASK_BASIC_INFO),
                        $0,
                        &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usageMB = Double(info.resident_size) / 1024 / 1024
            
            DispatchQueue.main.async {
                self.currentUsageMB = usageMB
                self.isUnderPressure = usageMB > self.pressureThresholdMB
            }
        }
    }
}

// MARK: - Preview
struct VirtualizedChatMessageList_Previews: PreviewProvider {
    static var previews: some View {
        VirtualizedChatMessageList(
            messages: (0..<1000).map { index in
                ChatMessage(
                    id: "\(index)",
                    role: index % 2 == 0 ? .user : .assistant,
                    content: "Message \(index): This is a test message with some content to simulate real chat.",
                    timestamp: Date()
                )
            },
            scrollToBottom: .constant(false),
            onToolTapped: { _ in }
        )
        .previewDisplayName("Virtualized Chat (1000 messages)")
    }
}