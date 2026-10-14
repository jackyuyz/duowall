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
    
    /// Default spec with assumed values (used if bundled JSON fails to load)
    public static func defaultSpec() -> DisplaySpec {
        DisplaySpec(
            inner: CGSize(width: 2670, height: 1878),
            outer: CGSize(width: 1398, height: 2034),
            singleImage: SingleImageMapping(
                outerCrop: calculateDefaultOuterCrop(),
                systemZoom: 1.0,
                notes: "ASSUMPTION: Centered crop at ~48% width. Verify on device."
            ),
            safeAreas: defaultSafeAreas(),
            creaseBand: ClosedRangeDouble(0.49...0.51),
            version: 1
        )
    }
    
    /// Calculate the default outer crop based on aspect ratio assumptions.
    ///
    /// **ASSUMPTION:** The outer display shows a centered crop of the inner canvas,
    /// maintaining the outer's aspect ratio.
    private static func calculateDefaultOuterCrop() -> NormalizedRect {
        let innerWidth: CGFloat = 2670
        let innerHeight: CGFloat = 1878
        let outerWidth: CGFloat = 1398
        let outerHeight: CGFloat = 2034
        
        let outerAspect = outerWidth / outerHeight
        
        let cropHeight = innerHeight
        let cropWidth = cropHeight * outerAspect
        
        let normalizedWidth = cropWidth / innerWidth
        let normalizedHeight: CGFloat = 1.0
        let normalizedX = (1 - normalizedWidth) / 2
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
