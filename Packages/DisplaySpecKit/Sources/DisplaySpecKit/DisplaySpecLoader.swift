import Foundation

/// Loads and provides access to the bundled DisplaySpec configuration.
public final class DisplaySpecLoader: @unchecked Sendable {
    
    /// Shared instance with the bundled spec
    public static let shared = DisplaySpecLoader()
    
    /// The loaded display specification
    public let spec: DisplaySpec
    
    private init() {
        self.spec = Self.loadBundledSpec() ?? Self.defaultSpec()
    }
    
    /// Initialize with a custom spec (for testing)
    public init(spec: DisplaySpec) {
        self.spec = spec
    }
    
    /// Load the bundled DisplaySpec.json
    private static func loadBundledSpec() -> DisplaySpec? {
        guard let url = Bundle.module.url(forResource: "DisplaySpec", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(DisplaySpec.self, from: data)
    }
    
    /// Default spec using DuoDisplayConstants (PM-researched values)
    ///
    /// NOTE: The creaseBand here is a MOCK DEFAULT for bundled spec only.
    /// At runtime, the crease must come from reservedRegions(kind: .division).
    /// It exists only when half-folded and is 0 when fully unfolded.
    public static func defaultSpec() -> DisplaySpec {
        let outerCrop = calculateDefaultOuterCrop()
        
        // Mock crease band: convert mock ~40pt to normalized fraction
        // Based on mock inner width of 951pt, 40pt = ~4.2% = 0.021 of each side
        // This is for BUNDLED SPEC ONLY - runtime uses reservedRegions
        let mockCreaseNormalized = DuoDisplayConstants.mockCreaseWidthPt / DuoDisplayConstants.mockInnerWidthPt
        let creaseHalfWidth = mockCreaseNormalized / 2
        
        return DisplaySpec(
            inner: CGSize(
                width: DuoDisplayConstants.innerWidthPx,
                height: DuoDisplayConstants.innerHeightPx
            ),
            outer: CGSize(
                width: DuoDisplayConstants.outerWidthPx,
                height: DuoDisplayConstants.outerHeightPx
            ),
            singleImage: SingleImageMapping(
                outerCrop: outerCrop,
                systemZoom: 1.0,
                notes: "Computed from outer aspect ratio (1:\(String(format: "%.3f", DuoDisplayConstants.outerHeightPx / DuoDisplayConstants.outerWidthPx))). Crop width: \(String(format: "%.2f", outerCrop.width * 100))% of inner. Verify on device."
            ),
            safeAreas: defaultSafeAreas(),
            creaseBand: ClosedRangeDouble((0.5 - creaseHalfWidth)...(0.5 + creaseHalfWidth)),
            version: 2
        )
    }
    
    /// Calculate the outer crop based on outer display aspect ratio.
    ///
    /// Uses PM-researched dimensions: outer 1398×2034 (1:1.455 aspect).
    /// The crop uses full inner height and computes width to match outer aspect ratio.
    private static func calculateDefaultOuterCrop() -> NormalizedRect {
        // Use constants from DuoDisplayConstants
        let innerWidth = DuoDisplayConstants.innerWidthPx
        let innerHeight = DuoDisplayConstants.innerHeightPx
        let outerWidth = DuoDisplayConstants.outerWidthPx
        let outerHeight = DuoDisplayConstants.outerHeightPx
        
        // Outer aspect ratio: 1398/2034 ≈ 0.6873
        let outerAspect = outerWidth / outerHeight
        
        // Use full inner height, compute width from outer aspect
        let cropHeight = innerHeight
        let cropWidth = cropHeight * outerAspect
        
        // Normalize to inner canvas
        let normalizedWidth = cropWidth / innerWidth  // ≈ 0.4839
        let normalizedHeight: CGFloat = 1.0
        let normalizedX = (1 - normalizedWidth) / 2   // Center horizontally
        let normalizedY: CGFloat = 0
        
        return NormalizedRect(
            x: normalizedX,
            y: normalizedY,
            width: normalizedWidth,
            height: normalizedHeight
        )
    }
    
    /// Default safe area shapes (assumptions, to be verified)
    private static func defaultSafeAreas() -> [SafeAreaShape] {
        [
            SafeAreaShape(
                id: "outer-clock",
                kind: .clock,
                display: .outer,
                normalizedFrame: NormalizedRect(x: 0.05, y: 0.08, width: 0.5, height: 0.15),
                cornerRadius: 0,
                label: "Clock"
            ),
            SafeAreaShape(
                id: "outer-dock",
                kind: .dock,
                display: .outer,
                normalizedFrame: NormalizedRect(x: 0.85, y: 0.3, width: 0.12, height: 0.4),
                cornerRadius: 16,
                label: "Dock"
            ),
            SafeAreaShape(
                id: "outer-dynamic-island",
                kind: .dynamicIsland,
                display: .outer,
                normalizedFrame: NormalizedRect(x: 0.88, y: 0.02, width: 0.08, height: 0.12),
                cornerRadius: 12,
                label: "Dynamic Island"
            ),
            SafeAreaShape(
                id: "inner-camera",
                kind: .camera,
                display: .inner,
                normalizedFrame: NormalizedRect(x: 0.485, y: 0.02, width: 0.03, height: 0.05),
                cornerRadius: 8,
                label: "Camera"
            ),
            SafeAreaShape(
                id: "inner-status-right",
                kind: .statusBar,
                display: .inner,
                normalizedFrame: NormalizedRect(x: 0.92, y: 0.01, width: 0.07, height: 0.04),
                cornerRadius: 0,
                label: "Status Bar"
            )
        ]
    }
}

// MARK: - Geometry Helpers

public extension DisplaySpecLoader {
    
    /// Get the outer crop rect in pixels for the inner canvas
    var outerCropRect: CGRect {
        spec.singleImage.outerCrop.rect(in: spec.inner)
    }
    
    /// Get the crease band rect in pixels for the inner canvas
    var creaseBandRect: CGRect {
        let band = spec.creaseBand
        return CGRect(
            x: band.lowerBound * spec.inner.width,
            y: 0,
            width: band.width * spec.inner.width,
            height: spec.inner.height
        )
    }
    
    /// Get safe areas for a specific display
    func safeAreas(for display: DisplayTarget) -> [SafeAreaShape] {
        spec.safeAreas.filter { $0.display == display || $0.display == .both }
    }
    
    /// Convert a point from inner canvas to outer canvas coordinates
    func innerToOuterPoint(_ point: CGPoint) -> CGPoint? {
        let cropRect = outerCropRect
        guard cropRect.contains(point) else { return nil }
        
        let relativeX = (point.x - cropRect.minX) / cropRect.width
        let relativeY = (point.y - cropRect.minY) / cropRect.height
        
        return CGPoint(
            x: relativeX * spec.outer.width,
            y: relativeY * spec.outer.height
        )
    }
    
    /// Convert a point from outer canvas to inner canvas coordinates
    func outerToInnerPoint(_ point: CGPoint) -> CGPoint {
        let cropRect = outerCropRect
        
        let relativeX = point.x / spec.outer.width
        let relativeY = point.y / spec.outer.height
        
        return CGPoint(
            x: cropRect.minX + relativeX * cropRect.width,
            y: cropRect.minY + relativeY * cropRect.height
        )
    }
    
    /// Check if a point on the inner canvas is within the outer crop
    func isPointInOuterCrop(_ point: CGPoint) -> Bool {
        outerCropRect.contains(point)
    }
    
    /// Check if a point on the inner canvas is in the crease band
    func isPointInCreaseBand(_ point: CGPoint) -> Bool {
        creaseBandRect.contains(point)
    }
    
    /// Get the outer crop as a percentage of inner width
    var outerCropWidthPercentage: CGFloat {
        spec.singleImage.outerCrop.width * 100
    }
}

// MARK: - Rotation Support

public extension DisplaySpecLoader {
    
    /// Inner canvas size for landscape orientation (default)
    var innerLandscape: CGSize {
        spec.inner
    }
    
    /// Inner canvas size for portrait orientation
    var innerPortrait: CGSize {
        CGSize(width: spec.inner.height, height: spec.inner.width)
    }
    
    /// Outer canvas size for portrait orientation (default)
    var outerPortrait: CGSize {
        spec.outer
    }
    
    /// Outer canvas size for landscape orientation
    var outerLandscape: CGSize {
        CGSize(width: spec.outer.height, height: spec.outer.width)
    }
    
    /// Get the outer crop rect adjusted for inner canvas rotation
    func outerCropRect(innerRotation: DisplayRotation) -> CGRect {
        switch innerRotation {
        case .landscape:
            return outerCropRect
        case .portrait:
            let normalizedCrop = spec.singleImage.outerCrop
            return CGRect(
                x: normalizedCrop.y * spec.inner.height,
                y: (1 - normalizedCrop.x - normalizedCrop.width) * spec.inner.width,
                width: normalizedCrop.height * spec.inner.height,
                height: normalizedCrop.width * spec.inner.width
            )
        }
    }
}

/// Display rotation orientation
public enum DisplayRotation: String, Codable, Sendable {
    case landscape  // Default for inner display
    case portrait   // Rotated inner display
}
