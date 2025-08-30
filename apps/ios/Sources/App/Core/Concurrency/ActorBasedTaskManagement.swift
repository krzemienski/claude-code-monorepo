import Foundation
import Combine
import OSLog

// MARK: - Actor-Based Cancellation Token

/// Actor-based cancellation token for managing task lifecycle
actor ActorCancellationToken {
    private let cancellationSubject = PassthroughSubject<Void, Never>()
    private var isCancelledValue = false
    private var cancellationHandlers: [() -> Void] = []
    
    var isCancelled: Bool {
        return isCancelledValue
    }
    
    nonisolated var cancellationPublisher: AnyPublisher<Void, Never> {
        cancellationSubject.eraseToAnyPublisher()
    }
    
    func cancel() {
        guard !isCancelledValue else { return }
        isCancelledValue = true
        
        // Send cancellation signal
        cancellationSubject.send()
        cancellationSubject.send(completion: .finished)
        
        // Execute all registered handlers
        for handler in cancellationHandlers {
            handler()
        }
        cancellationHandlers.removeAll()
    }
    
    func register(onCancel: @escaping () -> Void) {
        if isCancelledValue {
            // Already cancelled, execute immediately
            onCancel()
        } else {
            cancellationHandlers.append(onCancel)
        }
    }
}

/// Sendable wrapper for the actor-based cancellation token
final class SendableCancellationToken: @unchecked Sendable {
    private let actor: ActorCancellationToken
    
    init() {
        self.actor = ActorCancellationToken()
    }
    
    var isCancelled: Bool {
        get async {
            await actor.isCancelled
        }
    }
    
    var cancellationPublisher: AnyPublisher<Void, Never> {
        actor.cancellationPublisher
    }
    
    func cancel() async {
        await actor.cancel()
    }
    
    func register(onCancel: @escaping @Sendable () -> Void) async {
        await actor.register(onCancel: onCancel)
    }
}

/// Actor-based linked cancellation tokens for hierarchical cancellation
actor ActorLinkedCancellationToken {
    private let cancellationSubject = PassthroughSubject<Void, Never>()
    private var isCancelledValue = false
    private var cancellationHandlers: [() -> Void] = []
    private var linkedTokens: [SendableCancellationToken] = []
    
    var isCancelled: Bool {
        return isCancelledValue
    }
    
    nonisolated var cancellationPublisher: AnyPublisher<Void, Never> {
        cancellationSubject.eraseToAnyPublisher()
    }
    
    func link(to token: SendableCancellationToken) async {
        linkedTokens.append(token)
        
        // If this token is already cancelled, cancel the linked token
        if isCancelledValue {
            await token.cancel()
        }
    }
    
    func cancel() async {
        guard !isCancelledValue else { return }
        isCancelledValue = true
        
        // Send cancellation signal
        cancellationSubject.send()
        cancellationSubject.send(completion: .finished)
        
        // Execute all registered handlers
        for handler in cancellationHandlers {
            handler()
        }
        cancellationHandlers.removeAll()
        
        // Cancel all linked tokens
        for token in linkedTokens {
            await token.cancel()
        }
    }
    
    func register(onCancel: @escaping () -> Void) {
        if isCancelledValue {
            // Already cancelled, execute immediately
            onCancel()
        } else {
            cancellationHandlers.append(onCancel)
        }
    }
}

/// Sendable wrapper for linked cancellation token
final class SendableLinkedCancellationToken: @unchecked Sendable {
    private let actor: ActorLinkedCancellationToken
    
    init() {
        self.actor = ActorLinkedCancellationToken()
    }
    
    var isCancelled: Bool {
        get async {
            await actor.isCancelled
        }
    }
    
    var cancellationPublisher: AnyPublisher<Void, Never> {
        actor.cancellationPublisher
    }
    
    func link(to token: SendableCancellationToken) async {
        await actor.link(to: token)
    }
    
    func cancel() async {
        await actor.cancel()
    }
    
    func register(onCancel: @escaping @Sendable () -> Void) async {
        await actor.register(onCancel: onCancel)
    }
}

// MARK: - Migration Helper

/// Bridge class to help migration from NSLock-based tokens to actor-based tokens
/// This can be used as a drop-in replacement during migration
final class MigrationCancellationToken: CancellationToken {
    private let actorToken = SendableCancellationToken()
    
    override var isCancelled: Bool {
        // For synchronous compatibility, we'll use a cached value
        // In production, you should refactor to use async/await
        var cached = false
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            cached = await actorToken.isCancelled
            semaphore.signal()
        }
        semaphore.wait()
        return cached
    }
    
    override func cancel() {
        Task {
            await actorToken.cancel()
        }
        super.cancel()
    }
    
    override func register(onCancel: @escaping () -> Void) {
        Task {
            await actorToken.register(onCancel: onCancel)
        }
        super.register(onCancel: onCancel)
    }
}