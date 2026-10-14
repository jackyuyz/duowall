import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import DisplaySpecKit
import EditorCore

/// Configuration for wallpaper export
public struct ExportConfig: Codable, Equatable, Sendable {
    /// Output format
    public var format: ExportFormat
    
    /// Color space
    public var colorSpace: ExportColorSpace
    
    /// Whether to include watermark (free tier)
    public var includeWatermark: Bool
    
    /// Quality for HEIC (0-1, 1 = highest)
    public var quality: CGFloat
    
    public init(
        format: ExportFormat = .heic,
        colorSpace: ExportColorSpace = .srgb,
        includeWatermark: Bool = false,
        quality: CGFloat = 0.9
    ) {
        self.format = format
        self.colorSpace = colorSpace
        self.includeWatermark = includeWatermark
        self.quality = quality
    }
    
    /// Free tier config (with watermark)
    public static let free = ExportConfig(includeWatermark: true)
    
    /// Pro tier config (no watermark)
    public static let pro = ExportConfig(includeWatermark: false)
}

/// Export file format
public enum ExportFormat: String, Codable, Sendable, CaseIterable {
    case heic
    case png
    
    public var fileExtension: String {
        rawValue
    }
    
    public var mimeType: String {
        switch self {
        case .heic: return "image/heic"
        case .png: return "image/png"
        }
    }
}

/// Export color space
public enum ExportColorSpace: String, Codable, Sendable, CaseIterable {
    case srgb = "sRGB"
    case displayP3 = "Display P3"
}

/// Result of an export operation
public struct ExportResult: Sendable {
    /// Path to the exported inner (full) wallpaper
    public var innerImagePath: String
    
    /// Path to the exported outer crop preview (for sharing)
    public var outerPreviewPath: String?
    
    /// Size of the inner image in pixels
    public var innerSize: CGSize
    
    /// Size of the outer preview in pixels
    public var outerPreviewSize: CGSize?
    
    /// Export configuration used
    public var config: ExportConfig
    
    /// Timestamp of export
    public var exportedAt: Date
    
    public init(
        innerImagePath: String,
        outerPreviewPath: String? = nil,
        innerSize: CGSize,
        outerPreviewSize: CGSize? = nil,
        config: ExportConfig,
        exportedAt: Date = .now
    ) {
        self.innerImagePath = innerImagePath
        self.outerPreviewPath = outerPreviewPath
        self.innerSize = innerSize
        self.outerPreviewSize = outerPreviewSize
        self.config = config
        self.exportedAt = exportedAt
    }
}

/// Export errors
public enum ExportError: Error, Sendable {
    case noLayers
    case assetNotFound(String)
    case renderingFailed(String)
    case saveFailed(String)
    case insufficientDiskSpace
    case invalidDocument
}

// MARK: - Render Geometry Calculations (Platform-Independent)

/// Calculates render geometry for wallpaper composition.
/// These calculations can be unit tested on Linux.
public struct RenderGeometry: Sendable {
    
    /// Calculate the frame for a photo layer on the canvas
    public static func photoFrame(
        layer: PhotoLayer,
        canvasSize: CGSize,
        imageSize: CGSize
    ) -> CGRect {
        let transform = layer.transform
        
        let scaledWidth = imageSize.width * transform.scale
        let scaledHeight = imageSize.height * transform.scale
        
        let centerX = transform.center.x * canvasSize.width
        let centerY = transform.center.y * canvasSize.height
        
        return CGRect(
            x: centerX - scaledWidth / 2,
            y: centerY - scaledHeight / 2,
            width: scaledWidth,
            height: scaledHeight
        )
    }
    
    /// Calculate the outer crop rectangle on the inner canvas
    public static func outerCropRect(
        spec: DisplaySpec,
        customCrop: NormalizedRect? = nil
    ) -> CGRect {
        let crop = customCrop ?? spec.singleImage.outerCrop
        return crop.rect(in: spec.inner)
    }
    
    /// Calculate where to place the watermark (bottom-right of outer crop)
    public static func watermarkPosition(
        outerCropRect: CGRect,
        watermarkSize: CGSize,
        padding: CGFloat = 20
    ) -> CGPoint {
        CGPoint(
            x: outerCropRect.maxX - watermarkSize.width - padding,
            y: outerCropRect.maxY - watermarkSize.height - padding
        )
    }
    
    /// Calculate the scaling needed to fit an image in the canvas
    public static func fitScale(imageSize: CGSize, canvasSize: CGSize) -> CGFloat {
        let widthRatio = canvasSize.width / imageSize.width
        let heightRatio = canvasSize.height / imageSize.height
        return min(widthRatio, heightRatio)
    }
    
    /// Calculate the scaling needed to fill the canvas (may crop)
    public static func fillScale(imageSize: CGSize, canvasSize: CGSize) -> CGFloat {
        let widthRatio = canvasSize.width / imageSize.width
        let heightRatio = canvasSize.height / imageSize.height
        return max(widthRatio, heightRatio)
    }
    
    /// Calculate transform to center a subject in the outer crop area
    public static func centerInOuterCrop(
        subjectRect: CGRect,
        outerCropRect: CGRect,
        canvasSize: CGSize
    ) -> LayerTransform {
        let normalizedCenterX = outerCropRect.midX / canvasSize.width
        let normalizedCenterY = outerCropRect.midY / canvasSize.height
        
        return LayerTransform(
            center: CGPoint(x: normalizedCenterX, y: normalizedCenterY),
            scale: 1.0,
            rotation: 0
        )
    }
    
    /// Calculate blur extend regions for a photo
    public static func blurExtendRegions(
        photoFrame: CGRect,
        canvasSize: CGSize
    ) -> (left: CGRect, right: CGRect, top: CGRect, bottom: CGRect) {
        let left = CGRect(
            x: 0,
            y: 0,
            width: max(0, photoFrame.minX),
            height: canvasSize.height
        )
        
        let right = CGRect(
            x: photoFrame.maxX,
            y: 0,
            width: max(0, canvasSize.width - photoFrame.maxX),
            height: canvasSize.height
        )
        
        let top = CGRect(
            x: photoFrame.minX,
            y: 0,
            width: photoFrame.width,
            height: max(0, photoFrame.minY)
        )
        
        let bottom = CGRect(
            x: photoFrame.minX,
            y: photoFrame.maxY,
            width: photoFrame.width,
            height: max(0, canvasSize.height - photoFrame.maxY)
        )
        
        return (left, right, top, bottom)
    }
    
    /// Calculate mirror extend regions for a photo
    public static func mirrorExtendRegions(
        photoFrame: CGRect,
        canvasSize: CGSize
    ) -> [(sourceRect: CGRect, destRect: CGRect, flipHorizontal: Bool, flipVertical: Bool)] {
        var regions: [(sourceRect: CGRect, destRect: CGRect, flipHorizontal: Bool, flipVertical: Bool)] = []
        
        if photoFrame.minX > 0 {
            let width = min(photoFrame.minX, photoFrame.width)
            let sourceRect = CGRect(
                x: photoFrame.minX,
                y: photoFrame.minY,
                width: width,
                height: photoFrame.height
            )
            let destRect = CGRect(
                x: photoFrame.minX - width,
                y: photoFrame.minY,
                width: width,
                height: photoFrame.height
            )
            regions.append((sourceRect, destRect, true, false))
        }
        
        if photoFrame.maxX < canvasSize.width {
            let width = min(canvasSize.width - photoFrame.maxX, photoFrame.width)
            let sourceRect = CGRect(
                x: photoFrame.maxX - width,
                y: photoFrame.minY,
                width: width,
                height: photoFrame.height
            )
            let destRect = CGRect(
                x: photoFrame.maxX,
                y: photoFrame.minY,
                width: width,
                height: photoFrame.height
            )
            regions.append((sourceRect, destRect, true, false))
        }
        
        return regions
    }
}

// MARK: - Export Filename Generation

public extension ExportConfig {
    /// Generate a unique filename for export
    func generateFilename(prefix: String = "DuoWall") -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = String(format: "%04X", Int.random(in: 0..<65536))
        return "\(prefix)-\(timestamp)-\(random).\(format.fileExtension)"
    }
}

/// Validation for export readiness
public struct ExportValidator {
    
    /// Check if a document is valid for export
    public static func validate(_ doc: LayerDoc) -> Result<Void, ExportError> {
        if doc.layers.isEmpty {
            return .failure(.noLayers)
        }
        
        if doc.canvas.width <= 0 || doc.canvas.height <= 0 {
            return .failure(.invalidDocument)
        }
        
        return .success(())
    }
    
    /// Check AC1: Exported wallpaper is exactly 2670×1878 px
    public static func validateOutputSize(_ size: CGSize, spec: DisplaySpec) -> Bool {
        size.width == spec.inner.width && size.height == spec.inner.height
    }
}
