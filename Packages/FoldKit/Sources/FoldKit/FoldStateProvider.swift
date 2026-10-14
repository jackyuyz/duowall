import Foundation

/// Protocol for observing device fold state changes.
///
/// Feature code depends on this protocol, never on concrete implementations.
/// This allows testing with `MockFoldStateProvider` and production use with
/// `SystemFoldStateProvider` (which uses `onHingeChange` on iOS 27.1+).
public protocol FoldStateProvider: AnyObject, Sendable {
    /// Current fold state
    var state: FoldState { get }
    
    /// Async stream of fold state changes.
    /// Yields the current value immediately, then every subsequent change.
    func states() -> AsyncStream<FoldState>
}

/// A step in a fold animation script for testing
public struct FoldScriptStep: Codable, Sendable, Equatable {
    public var posture: FoldPosture
    public var angleDegrees: Double?
    public var durationSeconds: Double
    
    public init(posture: FoldPosture, angleDegrees: Double? = nil, durationSeconds: Double = 0) {
        self.posture = posture
        self.angleDegrees = angleDegrees
        self.durationSeconds = durationSeconds
    }
    
    /// Shorthand for a sweep from one angle to another
    public static func sweep(from: Double, to: Double, duration: Double, steps: Int = 30) -> [FoldScriptStep] {
        guard steps > 0 else { return [] }
        let stepDuration = duration / Double(steps)
        let angleDelta = (to - from) / Double(steps)
        
        return (0...steps).map { i in
            let angle = from + angleDelta * Double(i)
            let posture: FoldPosture
            if angle <= 10 {
                posture = .closed
            } else if angle >= 170 {
                posture = .fullyOpen
            } else {
                posture = .partiallyOpen
            }
            return FoldScriptStep(posture: posture, angleDegrees: angle, durationSeconds: stepDuration)
        }
    }
}

/// Mock provider for testing and previews.
///
/// Driven by code or by launch arguments. Use `-FoldMock <value>` where value is:
/// - `nohinge`: Non-foldable device
/// - `closed`: Folded state
/// - `open`: Fully open state  
/// - `half:<degrees>`: Partially open at specified angle
/// - `sweep:<from>-<to>:<seconds>`: Animated sweep between angles
/// - `script:<bundled-json-name>`: Run a scripted sequence
public final class MockFoldStateProvider: FoldStateProvider, @unchecked Sendable {
    private var _state: FoldState
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<FoldState>.Continuation] = [:]
    
    public var state: FoldState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }
    
    public init(initialState: FoldState = .noHinge) {
        self._state = initialState
    }
    
    /// Convenience initializers for common states
    public static func noHinge() -> MockFoldStateProvider {
        MockFoldStateProvider(initialState: .noHinge)
    }
    
    public static func closed() -> MockFoldStateProvider {
        MockFoldStateProvider(initialState: FoldState(posture: .closed, angleDegrees: 0))
    }
    
    public static func fullyOpen() -> MockFoldStateProvider {
        MockFoldStateProvider(initialState: FoldState(posture: .fullyOpen, angleDegrees: 180))
    }
    
    public static func partiallyOpen(angle: Double = 90) -> MockFoldStateProvider {
        MockFoldStateProvider(initialState: FoldState(posture: .partiallyOpen, angleDegrees: angle))
    }
    
    /// Update the mock state
    public func set(_ posture: FoldPosture, angle: Double? = nil) {
        let newState = FoldState(posture: posture, angleDegrees: angle, timestamp: .now)
        lock.lock()
        _state = newState
        let conts = continuations.values
        lock.unlock()
        
        for continuation in conts {
            continuation.yield(newState)
        }
    }
    
    /// Play a scripted sequence of fold states
    public func play(_ script: [FoldScriptStep]) async {
        for step in script {
            set(step.posture, angle: step.angleDegrees)
            if step.durationSeconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(step.durationSeconds * 1_000_000_000))
            }
        }
    }
    
    public func states() -> AsyncStream<FoldState> {
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.lock()
            self.continuations[id] = continuation
            let current = self._state
            self.lock.unlock()
            
            continuation.yield(current)
            
            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.continuations.removeValue(forKey: id)
                self?.lock.unlock()
            }
        }
    }
    
    /// Parse a mock value from launch arguments
    public static func from(launchArgument value: String) -> MockFoldStateProvider {
        let lowered = value.lowercased()
        
        if lowered == "nohinge" {
            return .noHinge()
        } else if lowered == "closed" {
            return .closed()
        } else if lowered == "open" {
            return .fullyOpen()
        } else if lowered.hasPrefix("half:") {
            let angleStr = String(lowered.dropFirst(5))
            let angle = Double(angleStr) ?? 90
            return .partiallyOpen(angle: angle)
        }
        
        return .noHinge()
    }
}

/// Production provider fed by the system's hinge APIs.
///
/// On iOS 27.1+, attach `HingeBridge` to the root view to receive updates.
/// On older systems or non-foldable devices, remains in `.noHinge` state.
public final class SystemFoldStateProvider: FoldStateProvider, @unchecked Sendable {
    private var _state: FoldState = .noHinge
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<FoldState>.Continuation] = [:]
    
    public var state: FoldState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }
    
    public init() {}
    
    /// Called by HingeBridge when no hinge is available
    public func ingestNoHinge() {
        update(to: .noHinge)
    }
    
    /// Called by HingeBridge with system hinge data.
    /// Maps DeviceHinge.status to FoldPosture.
    ///
    /// - Parameter hingeAngleDegrees: Angle in degrees from DeviceHinge.angle
    /// - Parameter status: String representation of DeviceHinge.status
    public func ingest(angleDegrees: Double?, statusRaw: String) {
        let posture: FoldPosture
        switch statusRaw {
        case "closed":
            posture = .closed
        case "partiallyOpen":
            posture = .partiallyOpen
        case "fullyOpen":
            posture = .fullyOpen
        default:
            posture = .unknown
        }
        
        let newState = FoldState(posture: posture, angleDegrees: angleDegrees, timestamp: .now)
        update(to: newState)
    }
    
    private func update(to newState: FoldState) {
        lock.lock()
        let oldState = _state
        _state = newState
        let conts = continuations.values
        lock.unlock()
        
        guard newState != oldState else { return }
        
        for continuation in conts {
            continuation.yield(newState)
        }
    }
    
    public func states() -> AsyncStream<FoldState> {
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.lock()
            self.continuations[id] = continuation
            let current = self._state
            self.lock.unlock()
            
            continuation.yield(current)
            
            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.continuations.removeValue(forKey: id)
                self?.lock.unlock()
            }
        }
    }
}
