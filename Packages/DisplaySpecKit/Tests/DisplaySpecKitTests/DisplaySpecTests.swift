import XCTest
@testable import DisplaySpecKit

final class DisplaySpecTests: XCTestCase {
    
    var loader: DisplaySpecLoader!
    
    override func setUp() {
        super.setUp()
        loader = DisplaySpecLoader.shared
    }
    
    // MARK: - Basic Spec Tests
    
    func testSpecLoads() {
        let spec = loader.spec
        XCTAssertEqual(spec.version, 1)
        XCTAssertEqual(spec.inner.width, 2670)
        XCTAssertEqual(spec.inner.height, 1878)
        XCTAssertEqual(spec.outer.width, 1398)
        XCTAssertEqual(spec.outer.height, 2034)
    }
    
    func testDefaultSpecFallback() {
        let defaultSpec = DisplaySpecLoader.defaultSpec()
        XCTAssertEqual(defaultSpec.inner.width, 2670)
        XCTAssertEqual(defaultSpec.outer.width, 1398)
    }
    
    // MARK: - Outer Crop Tests (AC1, AC3 related)
    
    func testOuterCropRectDimensions() {
        let cropRect = loader.outerCropRect
        
        XCTAssertGreaterThan(cropRect.width, 0)
        XCTAssertGreaterThan(cropRect.height, 0)
        
        XCTAssertEqual(cropRect.height, loader.spec.inner.height,
            "Outer crop should use full inner height")
        
        let percentage = loader.outerCropWidthPercentage
        XCTAssertGreaterThan(percentage, 40, "Outer crop should be > 40% of inner width")
        XCTAssertLessThan(percentage, 60, "Outer crop should be < 60% of inner width")
    }
    
    func testOuterCropIsCentered() {
        let cropRect = loader.outerCropRect
        let innerWidth = loader.spec.inner.width
        
        let leftMargin = cropRect.minX
        let rightMargin = innerWidth - cropRect.maxX
        
        XCTAssertEqual(leftMargin, rightMargin, accuracy: 1.0,
            "Outer crop should be horizontally centered")
    }
    
    func testOuterCropAspectRatioMatchesOuterDisplay() {
        let cropRect = loader.outerCropRect
        let cropAspect = cropRect.width / cropRect.height
        
        let outer = loader.spec.outer
        let outerAspect = outer.width / outer.height
        
        XCTAssertEqual(cropAspect, outerAspect, accuracy: 0.01,
            "Outer crop aspect ratio should match outer display")
    }
    
    // MARK: - Crease Band Tests
    
    func testCreaseBandIsCentered() {
        let crease = loader.spec.creaseBand
        let center = crease.center
        
        XCTAssertEqual(center, 0.5, accuracy: 0.02,
            "Crease band should be centered")
    }
    
    func testCreaseBandWidth() {
        let crease = loader.spec.creaseBand
        let width = crease.width
        
        XCTAssertGreaterThan(width, 0, "Crease band should have positive width")
        XCTAssertLessThan(width, 0.1, "Crease band should be < 10% of width")
    }
    
    func testCreaseBandRect() {
        let creaseBandRect = loader.creaseBandRect
        
        XCTAssertEqual(creaseBandRect.minY, 0)
        XCTAssertEqual(creaseBandRect.height, loader.spec.inner.height)
        XCTAssertGreaterThan(creaseBandRect.width, 0)
    }
    
    // MARK: - Safe Area Tests
    
    func testSafeAreasExist() {
        let safeAreas = loader.spec.safeAreas
        XCTAssertFalse(safeAreas.isEmpty, "Should have safe areas defined")
    }
    
    func testOuterSafeAreas() {
        let outerAreas = loader.safeAreas(for: .outer)
        XCTAssertFalse(outerAreas.isEmpty, "Should have outer safe areas")
        
        let hasClockArea = outerAreas.contains { $0.kind == .clock }
        let hasDockArea = outerAreas.contains { $0.kind == .dock }
        
        XCTAssertTrue(hasClockArea, "Outer should have clock safe area")
        XCTAssertTrue(hasDockArea, "Outer should have dock safe area")
    }
    
    func testInnerSafeAreas() {
        let innerAreas = loader.safeAreas(for: .inner)
        XCTAssertFalse(innerAreas.isEmpty, "Should have inner safe areas")
    }
    
    func testSafeAreaFramesAreNormalized() {
        for area in loader.spec.safeAreas {
            let frame = area.normalizedFrame
            
            XCTAssertGreaterThanOrEqual(frame.x, 0, "\(area.id) x should be >= 0")
            XCTAssertGreaterThanOrEqual(frame.y, 0, "\(area.id) y should be >= 0")
            XCTAssertLessThanOrEqual(frame.x + frame.width, 1.0, "\(area.id) should fit in width")
            XCTAssertLessThanOrEqual(frame.y + frame.height, 1.0, "\(area.id) should fit in height")
        }
    }
    
    // MARK: - Coordinate Conversion Tests
    
    func testInnerToOuterPointConversion() {
        let centerInner = CGPoint(x: loader.spec.inner.width / 2, y: loader.spec.inner.height / 2)
        
        let centerOuter = loader.innerToOuterPoint(centerInner)
        XCTAssertNotNil(centerOuter, "Center point should convert")
        
        if let outer = centerOuter {
            XCTAssertEqual(outer.x, loader.spec.outer.width / 2, accuracy: 1.0)
            XCTAssertEqual(outer.y, loader.spec.outer.height / 2, accuracy: 1.0)
        }
    }
    
    func testInnerToOuterPointOutsideCrop() {
        let outsidePoint = CGPoint(x: 10, y: loader.spec.inner.height / 2)
        let result = loader.innerToOuterPoint(outsidePoint)
        
        XCTAssertNil(result, "Point outside crop should return nil")
    }
    
    func testOuterToInnerPointConversion() {
        let centerOuter = CGPoint(x: loader.spec.outer.width / 2, y: loader.spec.outer.height / 2)
        
        let centerInner = loader.outerToInnerPoint(centerOuter)
        
        let cropRect = loader.outerCropRect
        let expectedX = cropRect.midX
        let expectedY = cropRect.midY
        
        XCTAssertEqual(centerInner.x, expectedX, accuracy: 1.0)
        XCTAssertEqual(centerInner.y, expectedY, accuracy: 1.0)
    }
    
    func testRoundTripConversion() {
        let cropRect = loader.outerCropRect
        let innerPoint = CGPoint(x: cropRect.midX, y: cropRect.midY)
        
        if let outerPoint = loader.innerToOuterPoint(innerPoint) {
            let backToInner = loader.outerToInnerPoint(outerPoint)
            
            XCTAssertEqual(backToInner.x, innerPoint.x, accuracy: 0.5)
            XCTAssertEqual(backToInner.y, innerPoint.y, accuracy: 0.5)
        } else {
            XCTFail("Should be able to convert center point")
        }
    }
    
    // MARK: - Point Containment Tests
    
    func testIsPointInOuterCrop() {
        let cropRect = loader.outerCropRect
        
        let centerPoint = CGPoint(x: cropRect.midX, y: cropRect.midY)
        XCTAssertTrue(loader.isPointInOuterCrop(centerPoint))
        
        let outsidePoint = CGPoint(x: 10, y: cropRect.midY)
        XCTAssertFalse(loader.isPointInOuterCrop(outsidePoint))
    }
    
    func testIsPointInCreaseBand() {
        let innerWidth = loader.spec.inner.width
        let innerHeight = loader.spec.inner.height
        
        let creaseCenter = CGPoint(x: innerWidth / 2, y: innerHeight / 2)
        XCTAssertTrue(loader.isPointInCreaseBand(creaseCenter))
        
        let leftPoint = CGPoint(x: 100, y: innerHeight / 2)
        XCTAssertFalse(loader.isPointInCreaseBand(leftPoint))
    }
    
    // MARK: - Rotation Tests
    
    func testInnerRotatedSizes() {
        let landscape = loader.innerLandscape
        let portrait = loader.innerPortrait
        
        XCTAssertEqual(landscape.width, portrait.height)
        XCTAssertEqual(landscape.height, portrait.width)
    }
    
    func testOuterRotatedSizes() {
        let portrait = loader.outerPortrait
        let landscape = loader.outerLandscape
        
        XCTAssertEqual(portrait.width, landscape.height)
        XCTAssertEqual(portrait.height, landscape.width)
    }
    
    // MARK: - NormalizedRect Tests
    
    func testNormalizedRectToRect() {
        let normalized = NormalizedRect(x: 0.25, y: 0.1, width: 0.5, height: 0.8)
        let containerSize = CGSize(width: 1000, height: 500)
        
        let rect = normalized.rect(in: containerSize)
        
        XCTAssertEqual(rect.origin.x, 250)
        XCTAssertEqual(rect.origin.y, 50)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 400)
    }
    
    func testNormalizedRectFromRect() {
        let rect = CGRect(x: 250, y: 50, width: 500, height: 400)
        let containerSize = CGSize(width: 1000, height: 500)
        
        let normalized = NormalizedRect.from(rect: rect, in: containerSize)
        
        XCTAssertEqual(normalized.x, 0.25, accuracy: 0.001)
        XCTAssertEqual(normalized.y, 0.1, accuracy: 0.001)
        XCTAssertEqual(normalized.width, 0.5, accuracy: 0.001)
        XCTAssertEqual(normalized.height, 0.8, accuracy: 0.001)
    }
    
    func testNormalizedRectCenter() {
        let normalized = NormalizedRect(x: 0.2, y: 0.3, width: 0.4, height: 0.2)
        let center = normalized.center
        
        XCTAssertEqual(center.x, 0.4, accuracy: 0.001)
        XCTAssertEqual(center.y, 0.4, accuracy: 0.001)
    }
    
    func testNormalizedRectCentered() {
        let centered = NormalizedRect.centered(width: 0.5, height: 0.8)
        
        XCTAssertEqual(centered.x, 0.25, accuracy: 0.001)
        XCTAssertEqual(centered.y, 0.1, accuracy: 0.001)
        XCTAssertEqual(centered.center.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(centered.center.y, 0.5, accuracy: 0.001)
    }
    
    // MARK: - Codable Tests
    
    func testDisplaySpecCodable() throws {
        let spec = loader.spec
        let encoded = try JSONEncoder().encode(spec)
        let decoded = try JSONDecoder().decode(DisplaySpec.self, from: encoded)
        
        XCTAssertEqual(spec.inner, decoded.inner)
        XCTAssertEqual(spec.outer, decoded.outer)
        XCTAssertEqual(spec.version, decoded.version)
    }
    
    func testSingleImageMappingCodable() throws {
        let mapping = loader.spec.singleImage
        let encoded = try JSONEncoder().encode(mapping)
        let decoded = try JSONDecoder().decode(SingleImageMapping.self, from: encoded)
        
        XCTAssertEqual(mapping.outerCrop, decoded.outerCrop)
        XCTAssertEqual(mapping.systemZoom, decoded.systemZoom)
    }
}
