import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#if canImport(UIKit)
import UIKit
#endif
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

// MARK: - Image Asset Provider Protocol

#if canImport(CoreGraphics)
/// Protocol for loading image assets (allows testing with mocks)
public protocol ImageAssetProvider: Sendable {
    /// Load an image from the given asset path
    func loadImage(from assetPath: String) async throws -> CGImage
}
#endif

// MARK: - Export Renderer

#if canImport(CoreGraphics) && canImport(ImageIO)
/// Renders LayerDoc to actual image files.
/// AC1: Produces exactly 2670×1878 px images in HEIC or PNG format, no alpha.
public final class ExportRenderer: @unchecked Sendable {
    private let spec: DisplaySpec
    private let assetProvider: ImageAssetProvider
    private let outputDirectory: URL
    
    public init(
        spec: DisplaySpec,
        assetProvider: ImageAssetProvider,
        outputDirectory: URL
    ) {
        self.spec = spec
        self.assetProvider = assetProvider
        self.outputDirectory = outputDirectory
    }
    
    /// Render a document and export to files.
    /// Returns paths to the exported inner wallpaper and optional outer preview.
    public func render(
        _ doc: LayerDoc,
        config: ExportConfig
    ) async throws -> ExportResult {
        switch ExportValidator.validate(doc) {
        case .failure(let error):
            throw error
        case .success:
            break
        }
        
        let canvasSize = CGSize(
            width: Int(spec.inner.width),
            height: Int(spec.inner.height)
        )
        
        let innerImage = try await renderToImage(doc, canvasSize: canvasSize, config: config)
        
        guard let innerImage = innerImage else {
            throw ExportError.renderingFailed("Failed to create image context")
        }
        
        let renderedSize = CGSize(
            width: CGFloat(CGImageGetWidth(innerImage)),
            height: CGFloat(CGImageGetHeight(innerImage))
        )
        guard ExportValidator.validateOutputSize(renderedSize, spec: spec) else {
            throw ExportError.renderingFailed("Output size mismatch: got \(renderedSize), expected \(spec.inner)")
        }
        
        let innerFilename = config.generateFilename(prefix: "DuoWall-Inner")
        let innerPath = outputDirectory.appendingPathComponent(innerFilename)
        
        try saveImage(innerImage, to: innerPath, config: config)
        
        var outerPreviewPath: String? = nil
        var outerPreviewSize: CGSize? = nil
        
        let outerCropRect = RenderGeometry.outerCropRect(spec: spec, customCrop: doc.outerCrop)
        if let outerImage = cropImage(innerImage, to: outerCropRect, targetSize: spec.outer) {
            let outerFilename = config.generateFilename(prefix: "DuoWall-Outer")
            let outerPath = outputDirectory.appendingPathComponent(outerFilename)
            try saveImage(outerImage, to: outerPath, config: config)
            outerPreviewPath = outerPath.path
            outerPreviewSize = CGSize(
                width: CGFloat(CGImageGetWidth(outerImage)),
                height: CGFloat(CGImageGetHeight(outerImage))
            )
        }
        
        return ExportResult(
            innerImagePath: innerPath.path,
            outerPreviewPath: outerPreviewPath,
            innerSize: renderedSize,
            outerPreviewSize: outerPreviewSize,
            config: config
        )
    }
    
    private func renderToImage(
        _ doc: LayerDoc,
        canvasSize: CGSize,
        config: ExportConfig
    ) async throws -> CGImage? {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        
        let colorSpace: CGColorSpace
        switch config.colorSpace {
        case .srgb:
            colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        case .displayP3:
            colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        }
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        for layer in doc.layers {
            try await renderLayer(layer, to: context, canvasSize: canvasSize, config: config)
        }
        
        if config.includeWatermark {
            renderWatermark(to: context, canvasSize: canvasSize, doc: doc)
        }
        
        return context.makeImage()
    }
    
    private func renderLayer(
        _ layer: Layer,
        to context: CGContext,
        canvasSize: CGSize,
        config: ExportConfig
    ) async throws {
        switch layer {
        case .photo(let photoLayer):
            try await renderPhotoLayer(photoLayer, to: context, canvasSize: canvasSize)
        case .fill(let fillLayer):
            renderFillLayer(fillLayer, to: context, canvasSize: canvasSize)
        case .text(let textLayer):
            renderTextLayer(textLayer, to: context, canvasSize: canvasSize)
        case .gradient(let gradientLayer):
            renderGradientLayer(gradientLayer, to: context, canvasSize: canvasSize)
        }
    }
    
    private func renderPhotoLayer(
        _ layer: PhotoLayer,
        to context: CGContext,
        canvasSize: CGSize
    ) async throws {
        let image = try await assetProvider.loadImage(from: layer.assetFile)
        let imageSize = CGSize(
            width: CGFloat(CGImageGetWidth(image)),
            height: CGFloat(CGImageGetHeight(image))
        )
        
        let frame = RenderGeometry.photoFrame(
            layer: layer,
            canvasSize: canvasSize,
            imageSize: imageSize
        )
        
        context.saveGState()
        
        let centerX = frame.midX
        let centerY = canvasSize.height - frame.midY
        
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: -CGFloat(layer.transform.rotation))
        context.translateBy(x: -centerX, y: -centerY)
        
        let flippedFrame = CGRect(
            x: frame.origin.x,
            y: canvasSize.height - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
        
        context.draw(image, in: flippedFrame)
        context.restoreGState()
    }
    
    private func renderFillLayer(
        _ layer: FillLayer,
        to context: CGContext,
        canvasSize: CGSize
    ) {
        switch layer.kind {
        case .solid(let r, let g, let b, let a):
            context.setFillColor(CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a)))
            context.fill(CGRect(origin: .zero, size: canvasSize))
        case .blurExtend, .mirrorExtend, .auto:
            context.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1))
            context.fill(CGRect(origin: .zero, size: canvasSize))
        }
    }
    
    private func renderTextLayer(
        _ layer: TextLayer,
        to context: CGContext,
        canvasSize: CGSize
    ) {
        #if canImport(UIKit)
        let fontSize = layer.fontSize * canvasSize.height
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(
                red: CGFloat(layer.color.0),
                green: CGFloat(layer.color.1),
                blue: CGFloat(layer.color.2),
                alpha: CGFloat(layer.color.3)
            )
        ]
        
        let text = layer.text as NSString
        let textSize = text.size(withAttributes: attributes)
        
        let x = layer.position.x * canvasSize.width - textSize.width / 2
        let y = canvasSize.height - (layer.position.y * canvasSize.height) - textSize.height / 2
        
        UIGraphicsPushContext(context)
        text.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
        UIGraphicsPopContext()
        #endif
    }
    
    private func renderGradientLayer(
        _ layer: GradientLayer,
        to context: CGContext,
        canvasSize: CGSize
    ) {
        var cgColors: [CGColor] = []
        for stop in layer.stops {
            cgColors.append(CGColor(
                red: CGFloat(stop.color.0),
                green: CGFloat(stop.color.1),
                blue: CGFloat(stop.color.2),
                alpha: CGFloat(stop.color.3)
            ))
        }
        
        let locations = layer.stops.map { CGFloat($0.location) }
        
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: cgColors as CFArray,
            locations: locations
        ) else { return }
        
        let startPoint = CGPoint(
            x: layer.startPoint.x * canvasSize.width,
            y: canvasSize.height - layer.startPoint.y * canvasSize.height
        )
        let endPoint = CGPoint(
            x: layer.endPoint.x * canvasSize.width,
            y: canvasSize.height - layer.endPoint.y * canvasSize.height
        )
        
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
    
    private func renderWatermark(
        to context: CGContext,
        canvasSize: CGSize,
        doc: LayerDoc
    ) {
        let watermarkText = "DuoWall"
        let fontSize: CGFloat = 24
        
        let outerCropRect = RenderGeometry.outerCropRect(spec: spec, customCrop: doc.outerCrop)
        let position = RenderGeometry.watermarkPosition(
            outerCropRect: outerCropRect,
            watermarkSize: CGSize(width: 100, height: 30),
            padding: 20
        )
        
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.5)
        ]
        
        let flippedY = canvasSize.height - position.y - 30
        
        UIGraphicsPushContext(context)
        (watermarkText as NSString).draw(
            at: CGPoint(x: position.x, y: flippedY),
            withAttributes: attributes
        )
        UIGraphicsPopContext()
        #else
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
        let watermarkRect = CGRect(x: position.x, y: canvasSize.height - position.y - 20, width: 80, height: 20)
        context.fill(watermarkRect)
        #endif
    }
    
    private func cropImage(_ image: CGImage, to rect: CGRect, targetSize: CGSize) -> CGImage? {
        guard let croppedImage = image.cropping(to: rect) else {
            return nil
        }
        
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue).rawValue
        ) else {
            return croppedImage
        }
        
        context.interpolationQuality = .high
        context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage() ?? croppedImage
    }
    
    private func saveImage(_ image: CGImage, to url: URL, config: ExportConfig) throws {
        let uti: CFString
        var properties: [CFString: Any] = [:]
        
        switch config.format {
        case .heic:
            uti = "public.heic" as CFString
            properties[kCGImageDestinationLossyCompressionQuality] = config.quality
        case .png:
            uti = "public.png" as CFString
        }
        
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, uti, 1, nil) else {
            throw ExportError.saveFailed("Failed to create image destination")
        }
        
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.saveFailed("Failed to write image to \(url.path)")
        }
    }
}

// MARK: - Mock Asset Provider for Testing

/// Mock asset provider that returns a solid color image
public final class MockImageAssetProvider: ImageAssetProvider, @unchecked Sendable {
    private let defaultSize: CGSize
    private let defaultColor: (CGFloat, CGFloat, CGFloat)
    
    public init(defaultSize: CGSize = CGSize(width: 2000, height: 1500), defaultColor: (CGFloat, CGFloat, CGFloat) = (0.2, 0.3, 0.5)) {
        self.defaultSize = defaultSize
        self.defaultColor = defaultColor
    }
    
    public func loadImage(from assetPath: String) async throws -> CGImage {
        let width = Int(defaultSize.width)
        let height = Int(defaultSize.height)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue).rawValue
        ) else {
            throw ExportError.assetNotFound(assetPath)
        }
        
        context.setFillColor(CGColor(red: defaultColor.0, green: defaultColor.1, blue: defaultColor.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let image = context.makeImage() else {
            throw ExportError.assetNotFound(assetPath)
        }
        
        return image
    }
}
#endif
