import XCTest
@testable import RenderKit
@testable import DisplaySpecKit
@testable import EditorCore

final class RenderGeometryTests: XCTestCase {
    
    let spec = DisplaySpecLoader.defaultSpec()
    
    // MARK: - Photo Frame Tests
    
    func testPhotoFrameIdentityTransform() {
        let layer = PhotoLayer(assetFile: "test.heic", transform: .identity)
        let canvasSize = CGSize(width: 2670, height: 1878)
        let imageSize = CGSize(width: 1000, height: 800)
        
        let frame = RenderGeometry.photoFrame(
            layer: layer,
            canvasSize: canvasSize,
            imageSize: imageSize
        )
        
        XCTAssertEqual(frame.midX, canvasSize.width / 2, accuracy: 0.1)
        XCTAssertEqual(frame.midY, canvasSize.height / 2, accuracy: 0.1)
        XCTAssertEqual(frame.width, imageSize.width, accuracy: 0.1)
        XCTAssertEqual(frame.height, imageSize.height, accuracy: 0.1)
    }
    
    func testPhotoFrameScaledTransform() {
        let transform = LayerTransform(center: CGPoint(x: 0.5, y: 0.5), scale: 2.0, rotation: 0)
        let layer = PhotoLayer(assetFile: "test.heic", transform: transform)
        let canvasSize = CGSize(width: 2670, height: 1878)
        let imageSize = CGSize(width: 1000, height: 800)
        
        let frame = RenderGeometry.photoFrame(
            layer: layer,
            canvasSize: canvasSize,
            imageSize: imageSize
        )
        
        XCTAssertEqual(frame.width, imageSize.width * 2, accuracy: 0.1)
        XCTAssertEqual(frame.height, imageSize.height * 2, accuracy: 0.1)
    }
    
    func testPhotoFrameOffsetTransform() {
        let transform = LayerTransform(center: CGPoint(x: 0.25, y: 0.75), scale: 1.0, rotation: 0)
        let layer = PhotoLayer(assetFile: "test.heic", transform: transform)
        let canvasSize = CGSize(width: 2670, height: 1878)
        let imageSize = CGSize(width: 1000, height: 800)
        
        let frame = RenderGeometry.photoFrame(
            layer: layer,
            canvasSize: canvasSize,
            imageSize: imageSize
        )
        
        XCTAssertEqual(frame.midX, canvasSize.width * 0.25, accuracy: 0.1)
        XCTAssertEqual(frame.midY, canvasSize.height * 0.75, accuracy: 0.1)
    }
    
    // MARK: - Outer Crop Tests (AC1, AC3)
    
    func testOuterCropRectUsesSpec() {
        let cropRect = RenderGeometry.outerCropRect(spec: spec)
        
        XCTAssertGreaterThan(cropRect.width, 0)
        XCTAssertGreaterThan(cropRect.height, 0)
        
        XCTAssertEqual(cropRect.height, spec.inner.height, accuracy: 0.1,
            "Outer crop should use full inner height")
    }
    
    func testOuterCropRectUsesCustomCrop() {
        let customCrop = NormalizedRect(x: 0.3, y: 0, width: 0.4, height: 1.0)
        let cropRect = RenderGeometry.outerCropRect(spec: spec, customCrop: customCrop)
        
        XCTAssertEqual(cropRect.origin.x, spec.inner.width * 0.3, accuracy: 0.1)
        XCTAssertEqual(cropRect.width, spec.inner.width * 0.4, accuracy: 0.1)
    }
    
    func testOuterCropIsCentered() {
        let cropRect = RenderGeometry.outerCropRect(spec: spec)
        let leftMargin = cropRect.minX
        let rightMargin = spec.inner.width - cropRect.maxX
        
        XCTAssertEqual(leftMargin, rightMargin, accuracy: 1.0,
            "Outer crop should be horizontally centered")
    }
    
    // MARK: - Watermark Position Tests
    
    func testWatermarkPosition() {
        let cropRect = RenderGeometry.outerCropRect(spec: spec)
        let watermarkSize = CGSize(width: 100, height: 30)
        let padding: CGFloat = 20
        
        let position = RenderGeometry.watermarkPosition(
            outerCropRect: cropRect,
            watermarkSize: watermarkSize,
            padding: padding
        )
        
        XCTAssertEqual(position.x, cropRect.maxX - watermarkSize.width - padding, accuracy: 0.1)
        XCTAssertEqual(position.y, cropRect.maxY - watermarkSize.height - padding, accuracy: 0.1)
    }
    
    // MARK: - Scale Calculation Tests
    
    func testFitScaleLandscapeInPortrait() {
        let imageSize = CGSize(width: 2000, height: 1000)
        let canvasSize = CGSize(width: 1000, height: 1500)
        
        let scale = RenderGeometry.fitScale(imageSize: imageSize, canvasSize: canvasSize)
        
        XCTAssertEqual(scale, 0.5, accuracy: 0.01)
    }
    
    func testFitScalePortraitInLandscape() {
        let imageSize = CGSize(width: 1000, height: 2000)
        let canvasSize = CGSize(width: 2000, height: 1000)
        
        let scale = RenderGeometry.fitScale(imageSize: imageSize, canvasSize: canvasSize)
        
        XCTAssertEqual(scale, 0.5, accuracy: 0.01)
    }
    
    func testFillScaleLandscapeInPortrait() {
        let imageSize = CGSize(width: 2000, height: 1000)
        let canvasSize = CGSize(width: 1000, height: 1500)
        
        let scale = RenderGeometry.fillScale(imageSize: imageSize, canvasSize: canvasSize)
        
        XCTAssertEqual(scale, 1.5, accuracy: 0.01)
    }
    
    func testFillScalePortraitInLandscape() {
        let imageSize = CGSize(width: 1000, height: 2000)
        let canvasSize = CGSize(width: 2000, height: 1000)
        
        let scale = RenderGeometry.fillScale(imageSize: imageSize, canvasSize: canvasSize)
        
        XCTAssertEqual(scale, 2.0, accuracy: 0.01)
    }
    
    // MARK: - Center in Outer Crop Tests
    
    func testCenterInOuterCrop() {
        let canvasSize = spec.inner
        let cropRect = RenderGeometry.outerCropRect(spec: spec)
        let subjectRect = CGRect(x: 100, y: 100, width: 500, height: 500)
        
        let transform = RenderGeometry.centerInOuterCrop(
            subjectRect: subjectRect,
            outerCropRect: cropRect,
            canvasSize: canvasSize
        )
        
        let normalizedCropCenterX = cropRect.midX / canvasSize.width
        let normalizedCropCenterY = cropRect.midY / canvasSize.height
        
        XCTAssertEqual(transform.center.x, normalizedCropCenterX, accuracy: 0.001)
        XCTAssertEqual(transform.center.y, normalizedCropCenterY, accuracy: 0.001)
    }
    
    // MARK: - Blur Extend Region Tests
    
    func testBlurExtendRegionsLeftRight() {
        let canvasSize = CGSize(width: 2670, height: 1878)
        let photoFrame = CGRect(x: 500, y: 0, width: 1670, height: 1878)
        
        let regions = RenderGeometry.blurExtendRegions(
            photoFrame: photoFrame,
            canvasSize: canvasSize
        )
        
        XCTAssertEqual(regions.left.origin.x, 0)
        XCTAssertEqual(regions.left.width, 500, accuracy: 0.1)
        
        XCTAssertEqual(regions.right.origin.x, photoFrame.maxX, accuracy: 0.1)
        XCTAssertEqual(regions.right.width, canvasSize.width - photoFrame.maxX, accuracy: 0.1)
    }
    
    func testBlurExtendRegionsFullWidth() {
        let canvasSize = CGSize(width: 2670, height: 1878)
        let photoFrame = CGRect(x: 0, y: 200, width: 2670, height: 1478)
        
        let regions = RenderGeometry.blurExtendRegions(
            photoFrame: photoFrame,
            canvasSize: canvasSize
        )
        
        XCTAssertEqual(regions.left.width, 0)
        XCTAssertEqual(regions.right.width, 0)
        XCTAssertEqual(regions.top.height, 200, accuracy: 0.1)
        XCTAssertEqual(regions.bottom.height, 200, accuracy: 0.1)
    }
    
    // MARK: - Mirror Extend Region Tests
    
    func testMirrorExtendRegionsLeftRight() {
        let canvasSize = CGSize(width: 2670, height: 1878)
        let photoFrame = CGRect(x: 500, y: 0, width: 1670, height: 1878)
        
        let regions = RenderGeometry.mirrorExtendRegions(
            photoFrame: photoFrame,
            canvasSize: canvasSize
        )
        
        XCTAssertEqual(regions.count, 2, "Should have left and right mirror regions")
        
        let leftRegion = regions.first { $0.destRect.minX < photoFrame.minX }
        let rightRegion = regions.first { $0.destRect.minX >= photoFrame.maxX }
        
        XCTAssertNotNil(leftRegion)
        XCTAssertNotNil(rightRegion)
        
        if let left = leftRegion {
            XCTAssertTrue(left.flipHorizontal)
        }
    }
}
