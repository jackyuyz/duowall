import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import DisplaySpecKit

/// Document model for wallpaper composition.
///
/// Contains all layers and settings needed to render a wallpaper pair.
/// All coordinates are normalized (0-1) relative to the canvas size.
public struct LayerDoc: Codable, Equatable, Sendable {
    /// Canvas size in pixels (default: inner display 2670×1878)
    public var canvas: CGSize
    
    /// Ordered list of layers (bottom to top)
    public var layers: [Layer]
    
    /// Template used for initial layout
    public var template: TemplateKind
    
    /// Custom outer crop rect (normalized). nil = use DisplaySpec default (Mode S)
    public var outerCrop: NormalizedRect?
    
    /// Document metadata
    public var createdAt: Date
    public var modifiedAt: Date
    
    public init(
        canvas: CGSize = CGSize(width: 2670, height: 1878),
        layers: [Layer] = [],
        template: TemplateKind = .reveal,
        outerCrop: NormalizedRect? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.canvas = canvas
        self.layers = layers
        self.template = template
        self.outerCrop = outerCrop
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    /// Create a new document with default fill layer
    public static func new(template: TemplateKind = .reveal) -> LayerDoc {
        var doc = LayerDoc(template: template)
        doc.layers = [
            .fill(FillLayer(kind: .auto))
        ]
        return doc
    }
    
    /// Get effective outer crop (custom or from DisplaySpec)
    public func effectiveOuterCrop(using spec: DisplaySpec) -> NormalizedRect {
        outerCrop ?? spec.singleImage.outerCrop
    }
    
    /// Find a layer by ID
    public func layer(withId id: UUID) -> Layer? {
        layers.first { $0.id == id }
    }
    
    /// Find the index of a layer by ID
    public func layerIndex(withId id: UUID) -> Int? {
        layers.firstIndex { $0.id == id }
    }
    
    /// Get all photo layers
    public var photoLayers: [PhotoLayer] {
        layers.compactMap { layer in
            if case .photo(let photoLayer) = layer {
                return photoLayer
            }
            return nil
        }
    }
    
    /// Get all fill layers
    public var fillLayers: [FillLayer] {
        layers.compactMap { layer in
            if case .fill(let fillLayer) = layer {
                return fillLayer
            }
            return nil
        }
    }
}

// MARK: - Layer Types

/// A layer in the composition
public enum Layer: Codable, Equatable, Sendable, Identifiable {
    case photo(PhotoLayer)
    case fill(FillLayer)
    case text(TextLayer)
    case gradient(GradientLayer)
    
    public var id: UUID {
        switch self {
        case .photo(let l): return l.id
        case .fill(let l): return l.id
        case .text(let l): return l.id
        case .gradient(let l): return l.id
        }
    }
    
    /// Human-readable layer type name
    public var typeName: String {
        switch self {
        case .photo: return "Photo"
        case .fill: return "Fill"
        case .text: return "Text"
        case .gradient: return "Gradient"
        }
    }
    
    /// Whether this layer is visible
    public var isVisible: Bool {
        get {
            switch self {
            case .photo(let l): return l.isVisible
            case .fill(let l): return l.isVisible
            case .text(let l): return l.isVisible
            case .gradient(let l): return l.isVisible
            }
        }
        set {
            switch self {
            case .photo(var l):
                l.isVisible = newValue
                self = .photo(l)
            case .fill(var l):
                l.isVisible = newValue
                self = .fill(l)
            case .text(var l):
                l.isVisible = newValue
                self = .text(l)
            case .gradient(var l):
                l.isVisible = newValue
                self = .gradient(l)
            }
        }
    }
}

/// Photo layer with transform
public struct PhotoLayer: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    
    /// Relative path to asset file in Application Support/Assets/
    public var assetFile: String
    
    /// Layer transform (position, scale, rotation)
    public var transform: LayerTransform
    
    /// Layer visibility
    public var isVisible: Bool
    
    /// Layer opacity (0-1)
    public var opacity: CGFloat
    
    /// Original image size in pixels (for aspect ratio calculations)
    public var originalSize: CGSize?
    
    public init(
        id: UUID = UUID(),
        assetFile: String,
        transform: LayerTransform = .identity,
        isVisible: Bool = true,
        opacity: CGFloat = 1.0,
        originalSize: CGSize? = nil
    ) {
        self.id = id
        self.assetFile = assetFile
        self.transform = transform
        self.isVisible = isVisible
        self.opacity = opacity
        self.originalSize = originalSize
    }
}

/// Fill layer for background/extend effects
public struct FillLayer: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    
    /// Type of fill
    public var kind: FillKind
    
    /// Layer visibility
    public var isVisible: Bool
    
    /// Layer opacity (0-1)
    public var opacity: CGFloat
    
    public init(
        id: UUID = UUID(),
        kind: FillKind,
        isVisible: Bool = true,
        opacity: CGFloat = 1.0
    ) {
        self.id = id
        self.kind = kind
        self.isVisible = isVisible
        self.opacity = opacity
    }
}

/// Text layer (Pro feature)
public struct TextLayer: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    
    /// Text content
    public var text: String
    
    /// Font family name
    public var fontFamily: String
    
    /// Font size in points (relative to canvas)
    public var fontSize: CGFloat
    
    /// Text color as hex string
    public var colorHex: String
    
    /// Layer transform
    public var transform: LayerTransform
    
    /// Layer visibility
    public var isVisible: Bool
    
    /// Layer opacity (0-1)
    public var opacity: CGFloat
    
    public init(
        id: UUID = UUID(),
        text: String,
        fontFamily: String = "SF Pro",
        fontSize: CGFloat = 48,
        colorHex: String = "#FFFFFF",
        transform: LayerTransform = .identity,
        isVisible: Bool = true,
        opacity: CGFloat = 1.0
    ) {
        self.id = id
        self.text = text
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.colorHex = colorHex
        self.transform = transform
        self.isVisible = isVisible
        self.opacity = opacity
    }
}

/// Gradient layer (Pro feature)
public struct GradientLayer: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    
    /// Gradient type
    public var gradientType: GradientType
    
    /// Color stops
    public var stops: [GradientStop]
    
    /// Start point (normalized 0-1)
    public var startPoint: CGPoint
    
    /// End point (normalized 0-1)
    public var endPoint: CGPoint
    
    /// Layer visibility
    public var isVisible: Bool
    
    /// Layer opacity (0-1)
    public var opacity: CGFloat
    
    public init(
        id: UUID = UUID(),
        gradientType: GradientType = .linear,
        stops: [GradientStop] = [],
        startPoint: CGPoint = CGPoint(x: 0, y: 0.5),
        endPoint: CGPoint = CGPoint(x: 1, y: 0.5),
        isVisible: Bool = true,
        opacity: CGFloat = 1.0
    ) {
        self.id = id
        self.gradientType = gradientType
        self.stops = stops
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.isVisible = isVisible
        self.opacity = opacity
    }
}

/// Gradient type
public enum GradientType: String, Codable, Sendable {
    case linear
    case radial
}

/// A color stop in a gradient
public struct GradientStop: Codable, Equatable, Sendable {
    public var colorHex: String
    public var location: CGFloat // 0-1
    
    public init(colorHex: String, location: CGFloat) {
        self.colorHex = colorHex
        self.location = location
    }
}

// MARK: - Fill Kinds

/// Types of background fill
public enum FillKind: Codable, Equatable, Sendable {
    /// Blur-extend the photo edges
    case blurExtend(BlurExtendOptions)
    
    /// Mirror-extend the photo edges
    case mirrorExtend(MirrorExtendOptions)
    
    /// Solid color (RGBA)
    case solid(SolidColorOptions)
    
    /// Auto-detect best fill (uses Vision saliency)
    case auto
    
    /// Simplified init helpers
    public static var blurExtend: FillKind { .blurExtend(BlurExtendOptions()) }
    public static var mirrorExtend: FillKind { .mirrorExtend(MirrorExtendOptions()) }
    public static func solid(hex: String) -> FillKind { .solid(SolidColorOptions(colorHex: hex)) }
}

/// Options for blur-extend fill
public struct BlurExtendOptions: Codable, Equatable, Sendable {
    /// Blur radius (points)
    public var radius: CGFloat
    
    /// Saturation adjustment (1.0 = unchanged)
    public var saturation: CGFloat
    
    public init(radius: CGFloat = 50, saturation: CGFloat = 1.2) {
        self.radius = radius
        self.saturation = saturation
    }
}

/// Options for mirror-extend fill
public struct MirrorExtendOptions: Codable, Equatable, Sendable {
    /// Whether to blend the mirror seam
    public var blendSeam: Bool
    
    /// Blend width as fraction of photo width
    public var blendWidth: CGFloat
    
    public init(blendSeam: Bool = true, blendWidth: CGFloat = 0.1) {
        self.blendSeam = blendSeam
        self.blendWidth = blendWidth
    }
}

/// Options for solid color fill
public struct SolidColorOptions: Codable, Equatable, Sendable {
    /// Color as hex string (e.g., "#FF5500")
    public var colorHex: String
    
    public init(colorHex: String = "#000000") {
        self.colorHex = colorHex
    }
}

// MARK: - Layer Transform

/// Transform for positioning layers on the canvas
public struct LayerTransform: Codable, Equatable, Sendable {
    /// Center position (normalized 0-1 relative to canvas)
    public var center: CGPoint
    
    /// Scale factor (1.0 = original size fits canvas)
    public var scale: CGFloat
    
    /// Rotation in degrees
    public var rotation: Double
    
    public init(center: CGPoint = CGPoint(x: 0.5, y: 0.5), scale: CGFloat = 1.0, rotation: Double = 0) {
        self.center = center
        self.scale = scale
        self.rotation = rotation
    }
    
    /// Identity transform (centered, no scale, no rotation)
    public static let identity = LayerTransform()
    
    /// Apply translation offset
    public func translated(by offset: CGPoint) -> LayerTransform {
        LayerTransform(
            center: CGPoint(x: center.x + offset.x, y: center.y + offset.y),
            scale: scale,
            rotation: rotation
        )
    }
    
    /// Apply scale multiplier
    public func scaled(by factor: CGFloat) -> LayerTransform {
        LayerTransform(
            center: center,
            scale: scale * factor,
            rotation: rotation
        )
    }
    
    /// Apply rotation delta
    public func rotated(by degrees: Double) -> LayerTransform {
        LayerTransform(
            center: center,
            scale: scale,
            rotation: rotation + degrees
        )
    }
}

// MARK: - Template Kinds

/// Pre-built composition templates
public enum TemplateKind: String, Codable, Sendable, CaseIterable {
    /// Subject centered in outer frame, "secret" content on sides
    case reveal
    
    /// Wide panoramic image across the inner screen
    case panorama
    
    /// Left/right halves differ; outer shows center blend
    case splitMood
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .reveal: return "Reveal"
        case .panorama: return "Panorama"
        case .splitMood: return "Split Mood"
        }
    }
    
    /// Description for UI
    public var description: String {
        switch self {
        case .reveal:
            return "Subject centered for the outer screen, with hidden content revealed when you open"
        case .panorama:
            return "Wide landscape that spans the full inner display"
        case .splitMood:
            return "Different themes on left and right, blending at the center"
        }
    }
}
