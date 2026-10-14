import Foundation

/// Converts noisy absolute hinge angles into a stable 0…1 control value.
///
/// The hinge angle range is not documented by Apple. This tracker uses a relative
/// approach: it anchors on the first angle received when an interaction starts,
/// then maps subsequent angles to a normalized progress value.
///
/// Use this for reveal animations and other angle-driven UI that should work
/// regardless of the device's absolute angle range.
public struct RelativeAngleTracker: Sendable, Codable, Equatable {
    /// The angle (in degrees) when the interaction started. `nil` until `begin()` is called.
    public var anchorDegrees: Double?
    
    /// The minimum angle observed during calibration/use
    public var observedMin: Double
    
    /// The maximum angle observed during calibration/use
    public var observedMax: Double
    
    /// EMA (exponential moving average) smoothing factor.
    /// Higher values = more responsive but more jittery.
    /// Lower values = smoother but more laggy.
    public var smoothing: Double
    
    /// Last computed smoothed progress value
    private var lastSmoothedProgress: Double = 0
    
    /// Default range span when no observations exist (degrees from anchor to fully open)
    public static let defaultRangeSpan: Double = 60.0
    
    public init(
        anchorDegrees: Double? = nil,
        observedMin: Double = .infinity,
        observedMax: Double = -.infinity,
        smoothing: Double = 0.25
    ) {
        self.anchorDegrees = anchorDegrees
        self.observedMin = observedMin
        self.observedMax = observedMax
        self.smoothing = smoothing
    }
    
    /// Begin tracking from a new anchor angle.
    /// Call this when the user starts an angle-driven interaction.
    public mutating func begin(at degrees: Double) {
        anchorDegrees = degrees
        observedMin = degrees
        observedMax = degrees
        lastSmoothedProgress = 0
    }
    
    /// Update with a new angle reading and get normalized progress (0…1).
    ///
    /// - Parameter degrees: Current hinge angle in degrees
    /// - Returns: Smoothed progress from 0 (closed/anchor) to 1 (fully open)
    public mutating func update(_ degrees: Double) -> Double {
        guard let anchor = anchorDegrees else {
            begin(at: degrees)
            return 0
        }
        
        observedMin = min(observedMin, degrees)
        observedMax = max(observedMax, degrees)
        
        let rangeSpan = max(observedMax - observedMin, Self.defaultRangeSpan)
        
        let rawProgress: Double
        if degrees >= anchor {
            rawProgress = min(1.0, (degrees - anchor) / rangeSpan)
        } else {
            rawProgress = max(0.0, (degrees - anchor) / rangeSpan)
        }
        
        let clampedProgress = max(0, min(1, rawProgress))
        
        lastSmoothedProgress = lastSmoothedProgress + smoothing * (clampedProgress - lastSmoothedProgress)
        
        return lastSmoothedProgress
    }
    
    /// Get the signed delta in degrees since the anchor.
    ///
    /// - Parameter degrees: Current hinge angle in degrees
    /// - Returns: Signed degrees difference from anchor (positive = more open)
    public mutating func delta(_ degrees: Double) -> Double {
        guard let anchor = anchorDegrees else {
            begin(at: degrees)
            return 0
        }
        return degrees - anchor
    }
    
    /// Reset the tracker to its initial state.
    public mutating func reset() {
        anchorDegrees = nil
        observedMin = .infinity
        observedMax = -.infinity
        lastSmoothedProgress = 0
    }
    
    /// Get the current observed range span (max - min), or the default if not enough data.
    public var currentRangeSpan: Double {
        let span = observedMax - observedMin
        return span > 0 ? span : Self.defaultRangeSpan
    }
    
    /// Whether the tracker has been anchored (begin() was called)
    public var isAnchored: Bool {
        anchorDegrees != nil
    }
}
