import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Display Dimension Assumptions
// These dimensions are based on available information about iPhone Duo.
// Marked clearly as assumptions per spec §11.
//
// ASSUMPTION: Inner display is 2670×1878 (landscape orientation)
// ASSUMPTION: Outer display is 1398×2034 (portrait orientation)
// ASSUMPTION: Outer crop from single wallpaper is ~48% of inner width, centered
//
// These MUST be verified on real hardware in M0/M9 and updated accordingly.

/// Complete display specification for iPhone Duo.
///
/// This struct contains all geometry needed for wallpaper composition:
/// - Inner and outer display dimensions
/// - Single-image mode crop mapping
/// - Safe area shapes (clock, dock, dynamic island, camera)
/// - Crease band position
///
/// **Important:** Many values are assumptions pending real device verification.
/// See `DisplaySpecAssumptions` for documentation.
public struct DisplaySpec: Codable, Equatable, Sendable {
    /// Inner (unfolded) display size in pixels, landscape orientation
    public var inner: CGSize
    
    /// Outer (cover) display size in pixels, portrait orientation
    public var outer: CGSize
    
    /// Mapping for single-image wallpaper mode (Mode S)
    public var singleImage: SingleImageMapping
    
    /// Safe area shapes for overlay rendering
    public var safeAreas: [SafeAreaShape]
    
    /// Crease band position as normalized X range on inner display
    /// Example: 0.49...0.51 means crease is centered with 2% width
    public var creaseBand: ClosedRangeDouble
    
    /// Spec version for future updates
    public var version: Int
    
    public init(
        inner: CGSize,
        outer: CGSize,
        singleImage: SingleImageMapping,
        safeAreas: [SafeAreaShape],
        creaseBand: ClosedRangeDouble,
        version: Int
    ) {
        self.inner = inner
        self.outer = outer
        self.singleImage = singleImage
        self.safeAreas = safeAreas
        self.creaseBand = creaseBand
        self.version = version
    }
}

/// Mapping for how iOS crops a single wallpaper image for the outer display.
///
/// **ASSUMPTION:** iOS takes a centered crop of the inner-size wallpaper
/// to display on the outer screen. The exact crop ratio needs verification.
public struct SingleImageMapping: Codable, Equatable, Sendable {
    /// Normalized rect (0-1 in each dimension) of the outer crop within the inner canvas.
    /// Origin (0,0) is top-left of inner canvas.
    public var outerCrop: NormalizedRect
    
    /// Any zoom/scale factor applied by the system (1.0 = no zoom)
    public var systemZoom: CGFloat
    
    /// Notes about this mapping for debugging/documentation
    public var notes: String?
    
    public init(outerCrop: NormalizedRect, systemZoom: CGFloat = 1.0, notes: String? = nil) {
        self.outerCrop = outerCrop
        self.systemZoom = systemZoom
        self.notes = notes
    }
}

/// A normalized rectangle (all values 0-1 relative to container size)
public struct NormalizedRect: Codable, Equatable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    
    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    /// Convert to CGRect in a given container size
    public func rect(in containerSize: CGSize) -> CGRect {
        CGRect(
            x: x * containerSize.width,
            y: y * containerSize.height,
            width: width * containerSize.width,
            height: height * containerSize.height
        )
    }
    
    /// Create from a CGRect and container size
    public static func from(rect: CGRect, in containerSize: CGSize) -> NormalizedRect {
        NormalizedRect(
            x: rect.origin.x / containerSize.width,
            y: rect.origin.y / containerSize.height,
            width: rect.width / containerSize.width,
            height: rect.height / containerSize.height
        )
    }
    
    /// Center point of the rect
    public var center: CGPoint {
        CGPoint(x: x + width / 2, y: y + height / 2)
    }
    
    /// Centered rect with given size (all normalized)
    public static func centered(width: CGFloat, height: CGFloat) -> NormalizedRect {
        NormalizedRect(
            x: (1 - width) / 2,
            y: (1 - height) / 2,
            width: width,
            height: height
        )
    }
}

/// Codable wrapper for ClosedRange<Double> since Swift ranges aren't directly Codable
public struct ClosedRangeDouble: Codable, Equatable, Sendable {
    public var lowerBound: Double
    public var upperBound: Double
    
    public init(_ range: ClosedRange<Double>) {
        self.lowerBound = range.lowerBound
        self.upperBound = range.upperBound
    }
    
    public init(lowerBound: Double, upperBound: Double) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
    
    public var range: ClosedRange<Double> {
        lowerBound...upperBound
    }
    
    public func contains(_ value: Double) -> Bool {
        range.contains(value)
    }
    
    public var width: Double {
        upperBound - lowerBound
    }
    
    public var center: Double {
        (lowerBound + upperBound) / 2
    }
}

/// Safe area shapes for overlay rendering (clock, dock, dynamic island, camera)
public struct SafeAreaShape: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: SafeAreaKind
    public var display: DisplayTarget
    public var normalizedFrame: NormalizedRect
    public var cornerRadius: CGFloat
    public var label: String
    
    public init(
        id: String,
        kind: SafeAreaKind,
        display: DisplayTarget,
        normalizedFrame: NormalizedRect,
        cornerRadius: CGFloat = 0,
        label: String
    ) {
        self.id = id
        self.kind = kind
        self.display = display
        self.normalizedFrame = normalizedFrame
        self.cornerRadius = cornerRadius
        self.label = label
    }
}

/// Types of safe areas on iPhone Duo displays
public enum SafeAreaKind: String, Codable, Sendable, CaseIterable {
    case clock              // Lock screen clock position
    case dock               // Side dock on lock screen
    case dynamicIsland      // Vertical Dynamic Island
    case camera             // Camera cutout
    case statusBar          // Status bar region
}

/// Which display a safe area applies to
public enum DisplayTarget: String, Codable, Sendable {
    case inner      // Unfolded display
    case outer      // Cover display
    case both       // Applies to both
}
