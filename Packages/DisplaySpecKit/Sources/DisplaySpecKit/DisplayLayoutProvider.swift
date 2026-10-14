import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Display Layout Provider Protocol

/// Protocol for obtaining runtime display layout information.
/// The crease comes from reservedRegions(kind: .division) at runtime:
/// it exists only when half-folded and is 0 when fully unfolded.
///
/// Implementations should read bounds, displayScale, and safe areas at runtime.
/// The mock defaults use third-party pt values as placeholders only.
@MainActor
public protocol DisplayLayoutProvider: AnyObject {
    /// Current display bounds in points
    var bounds: CGRect { get }
    
    /// Current display scale factor (e.g. 3.0 for @3x)
    var displayScale: CGFloat { get }
    
    /// Current safe area insets (top, left, bottom, right)
    var safeAreaInsets: EdgeInsets { get }
    
    /// Whether we're on the inner (unfolded) or outer (cover) display
    var isInnerDisplay: Bool { get }
}

/// Protocol for obtaining reserved regions (crease, occlusion).
/// The crease width is NOT hardcoded - it comes from reservedRegions(kind: .division).
@MainActor
public protocol ReservedRegionsProvider: AnyObject {
    /// Reserved region for the fold/crease (kind: .division).
    /// Returns CGRect.zero when fully unfolded or on non-Duo devices.
    var divisionRegion: CGRect { get }
    
    /// Reserved regions for cameras/sensors (kind: .occlusion)
    var occlusionRegions: [CGRect] { get }
}

// MARK: - Edge Insets (Platform-Independent)

public struct EdgeInsets: Equatable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat
    
    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
    
    public static let zero = EdgeInsets()
}

// MARK: - Mock Display Layout Provider

/// Mock display layout provider with third-party researched pt values.
/// These are MOCK DEFAULTS ONLY - real values must come from runtime.
///
/// Third-party pt values (unconfirmed):
/// - Inner: 951×669pt landscape, renders at 2007×2853 @3x downsampled to 2670×1878
/// - Outer: 466×678pt portrait
@MainActor
public final class MockDisplayLayoutProvider: DisplayLayoutProvider {
    
    // MARK: - Mock Default Constants (Third-Party Values)
    
    /// Inner display size in points (landscape, third-party estimate)
    public nonisolated(unsafe) static let mockInnerBoundsPt = CGRect(x: 0, y: 0, width: 951, height: 669)
    
    /// Outer display size in points (portrait, third-party estimate)
    public nonisolated(unsafe) static let mockOuterBoundsPt = CGRect(x: 0, y: 0, width: 466, height: 678)
    
    /// Assumed scale factor
    public nonisolated(unsafe) static let mockScaleFactor: CGFloat = 3.0
    
    // MARK: - Instance Properties
    
    private var _bounds: CGRect
    private var _displayScale: CGFloat
    private var _safeAreaInsets: EdgeInsets
    private var _isInnerDisplay: Bool
    
    public var bounds: CGRect { _bounds }
    public var displayScale: CGFloat { _displayScale }
    public var safeAreaInsets: EdgeInsets { _safeAreaInsets }
    public var isInnerDisplay: Bool { _isInnerDisplay }
    
    public init(
        bounds: CGRect? = nil,
        displayScale: CGFloat = 3.0,
        safeAreaInsets: EdgeInsets = .zero,
        isInnerDisplay: Bool = true
    ) {
        self._bounds = bounds ?? (isInnerDisplay ? Self.mockInnerBoundsPt : Self.mockOuterBoundsPt)
        self._displayScale = displayScale
        self._safeAreaInsets = safeAreaInsets
        self._isInnerDisplay = isInnerDisplay
    }
    
    /// Update bounds (for testing state changes)
    public func setBounds(_ bounds: CGRect) {
        _bounds = bounds
    }
    
    /// Update scale factor
    public func setDisplayScale(_ scale: CGFloat) {
        _displayScale = scale
    }
    
    /// Update safe area insets
    public func setSafeAreaInsets(_ insets: EdgeInsets) {
        _safeAreaInsets = insets
    }
    
    /// Switch between inner and outer display
    public func setIsInnerDisplay(_ value: Bool) {
        _isInnerDisplay = value
        if _bounds == Self.mockInnerBoundsPt || _bounds == Self.mockOuterBoundsPt {
            _bounds = value ? Self.mockInnerBoundsPt : Self.mockOuterBoundsPt
        }
    }
}

// MARK: - Mock Reserved Regions Provider

/// Mock reserved regions provider with configurable crease width.
/// The real crease comes from reservedRegions(kind: .division) at runtime.
///
/// Default mock crease: ~40pt width (centered in inner display).
@MainActor
public final class MockReservedRegionsProvider: ReservedRegionsProvider {
    
    // MARK: - Mock Default Constants
    
    /// Default mock crease width in points (~40pt)
    public nonisolated(unsafe) static let mockCreaseWidthPt: CGFloat = 40
    
    // MARK: - Instance Properties
    
    private var _divisionRegion: CGRect
    private var _occlusionRegions: [CGRect]
    
    public var divisionRegion: CGRect { _divisionRegion }
    public var occlusionRegions: [CGRect] { _occlusionRegions }
    
    /// Create with a crease width centered in the given bounds.
    /// Pass CGRect.zero for divisionRegion when fully unfolded or on non-Duo.
    public init(
        divisionRegion: CGRect? = nil,
        occlusionRegions: [CGRect] = [],
        bounds: CGRect = CGRect(x: 0, y: 0, width: 951, height: 669)
    ) {
        if let region = divisionRegion {
            self._divisionRegion = region
        } else {
            let creaseX = (bounds.width - Self.mockCreaseWidthPt) / 2
            self._divisionRegion = CGRect(
                x: creaseX,
                y: 0,
                width: Self.mockCreaseWidthPt,
                height: bounds.height
            )
        }
        self._occlusionRegions = occlusionRegions
    }
    
    /// Create with no crease (fully unfolded or non-Duo)
    public static func noCrease() -> MockReservedRegionsProvider {
        MockReservedRegionsProvider(divisionRegion: .zero, occlusionRegions: [])
    }
    
    /// Update division region (for testing fold state changes)
    public func setDivisionRegion(_ region: CGRect) {
        _divisionRegion = region
    }
    
    /// Update occlusion regions
    public func setOcclusionRegions(_ regions: [CGRect]) {
        _occlusionRegions = regions
    }
}

// MARK: - Debug Logging

/// Utility for logging runtime display values (for debugging/verification)
public struct DisplayDebugLogger {
    
    /// Log current runtime values from providers
    @MainActor
    public static func logRuntimeValues(
        layout: DisplayLayoutProvider,
        regions: ReservedRegionsProvider,
        label: String = "DisplayDebugLogger"
    ) {
        print("[\(label)] Runtime Display Values:")
        print("  bounds: \(layout.bounds) (pt)")
        print("  displayScale: \(layout.displayScale)x")
        print("  pixel size: \(layout.bounds.width * layout.displayScale) × \(layout.bounds.height * layout.displayScale) px")
        print("  safeAreaInsets: top=\(layout.safeAreaInsets.top), leading=\(layout.safeAreaInsets.leading), bottom=\(layout.safeAreaInsets.bottom), trailing=\(layout.safeAreaInsets.trailing)")
        print("  isInnerDisplay: \(layout.isInnerDisplay)")
        print("  divisionRegion (crease): \(regions.divisionRegion)")
        if regions.divisionRegion != .zero {
            print("    crease width: \(regions.divisionRegion.width) pt")
        } else {
            print("    (no crease - fully unfolded or non-Duo)")
        }
        print("  occlusionRegions: \(regions.occlusionRegions.count) region(s)")
        for (i, region) in regions.occlusionRegions.enumerated() {
            print("    [\(i)]: \(region)")
        }
    }
}

// MARK: - Display Spec Extensions

public extension DisplaySpec {
    /// Get crease band from a reserved regions provider.
    /// Returns nil if there's no crease (fully unfolded or non-Duo).
    @MainActor
    func creaseBand(from regions: ReservedRegionsProvider, layout: DisplayLayoutProvider) -> ClosedRangeDouble? {
        let region = regions.divisionRegion
        guard region != .zero, region.width > 0 else {
            return nil
        }
        
        let boundsWidth = layout.bounds.width
        guard boundsWidth > 0 else { return nil }
        
        let normalizedStart = region.minX / boundsWidth
        let normalizedEnd = region.maxX / boundsWidth
        
        return ClosedRangeDouble(lowerBound: normalizedStart, upperBound: normalizedEnd)
    }
}
