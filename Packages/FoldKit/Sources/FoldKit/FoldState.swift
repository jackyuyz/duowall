import Foundation

/// Represents the physical posture of a foldable device.
///
/// Based on iPhone Duo's hinge states as documented in Apple's tech talks.
/// On non-foldable devices or when hinge context is unavailable, use `.noHinge`.
public enum FoldPosture: String, Codable, Sendable, CaseIterable, Equatable {
    /// Non-foldable device (any iPhone, iPad, Mac) or hinge context unavailable
    case noHinge
    /// Device is fully folded; app is on the outer display
    case closed
    /// Device is partially open (laptop, book, tent postures)
    case partiallyOpen
    /// Device is fully flat; app on inner display
    case fullyOpen
    /// Transient or unknown state (UIKit's `.unknown` status)
    case unknown
}

/// Snapshot of the device's fold state at a point in time.
///
/// Use `angleDegrees` only for relative calculations (e.g., reveal progress),
/// never for absolute thresholds. Apple does not document the exact range.
public struct FoldState: Equatable, Sendable, Codable {
    /// Current posture classification
    public var posture: FoldPosture
    
    /// Hinge angle in degrees, if available.
    /// `nil` when there is no hinge or the system doesn't report it.
    /// The valid range is NOT documented by Apple—do not hardcode thresholds.
    public var angleDegrees: Double?
    
    /// When this state was captured
    public var timestamp: Date
    
    public init(posture: FoldPosture, angleDegrees: Double? = nil, timestamp: Date = .now) {
        self.posture = posture
        self.angleDegrees = angleDegrees
        self.timestamp = timestamp
    }
    
    /// A default state for non-foldable devices
    public static let noHinge = FoldState(posture: .noHinge, angleDegrees: nil, timestamp: .distantPast)
    
    /// Whether this device has a hinge (is a foldable)
    public var hasHinge: Bool { posture != .noHinge }
    
    /// Whether the device is currently in a folded state suitable for inner display use
    public var isUnfolded: Bool {
        switch posture {
        case .partiallyOpen, .fullyOpen:
            return true
        case .closed, .noHinge, .unknown:
            return false
        }
    }
}
