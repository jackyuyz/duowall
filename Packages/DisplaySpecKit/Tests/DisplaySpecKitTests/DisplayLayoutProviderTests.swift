import XCTest
@testable import DisplaySpecKit

final class DisplayLayoutProviderTests: XCTestCase {
    
    // MARK: - Display Constants Tests (no MainActor)
    
    func testMockDefaultConstants() {
        // Third-party pt values
        XCTAssertEqual(DuoDisplayConstants.mockInnerWidthPt, 951)
        XCTAssertEqual(DuoDisplayConstants.mockInnerHeightPt, 669)
        XCTAssertEqual(DuoDisplayConstants.mockOuterWidthPt, 466)
        XCTAssertEqual(DuoDisplayConstants.mockOuterHeightPt, 678)
        XCTAssertEqual(DuoDisplayConstants.mockScaleFactor, 3.0)
        XCTAssertEqual(DuoDisplayConstants.mockCreaseWidthPt, 40)
    }
    
    func testPixelValuesUnchanged() {
        // PM-researched pixel values
        XCTAssertEqual(DuoDisplayConstants.innerWidthPx, 2670)
        XCTAssertEqual(DuoDisplayConstants.innerHeightPx, 1878)
        XCTAssertEqual(DuoDisplayConstants.outerWidthPx, 1398)
        XCTAssertEqual(DuoDisplayConstants.outerHeightPx, 2034)
    }
    
    // MARK: - Edge Insets Tests
    
    func testEdgeInsetsZero() {
        let insets = EdgeInsets.zero
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.leading, 0)
        XCTAssertEqual(insets.bottom, 0)
        XCTAssertEqual(insets.trailing, 0)
    }
    
    func testEdgeInsetsCustom() {
        let insets = EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0)
        XCTAssertEqual(insets.top, 47)
        XCTAssertEqual(insets.leading, 0)
        XCTAssertEqual(insets.bottom, 34)
        XCTAssertEqual(insets.trailing, 0)
    }
    
    // MARK: - Mock Default Static Constants
    
    func testMockInnerBoundsPt() {
        let bounds = MockDisplayLayoutProvider.mockInnerBoundsPt
        XCTAssertEqual(bounds.width, 951)
        XCTAssertEqual(bounds.height, 669)
    }
    
    func testMockOuterBoundsPt() {
        let bounds = MockDisplayLayoutProvider.mockOuterBoundsPt
        XCTAssertEqual(bounds.width, 466)
        XCTAssertEqual(bounds.height, 678)
    }
    
    func testMockCreaseWidthPt() {
        let width = MockReservedRegionsProvider.mockCreaseWidthPt
        XCTAssertEqual(width, 40, "Mock crease should be ~40pt")
    }
    
    // MARK: - Mock Provider Tests (using async/await to run on MainActor)
    
    func testMockDisplayLayoutProviderDefaultsToInner() async {
        await MainActor.run {
            let provider = MockDisplayLayoutProvider()
            
            XCTAssertTrue(provider.isInnerDisplay)
            XCTAssertEqual(provider.bounds, MockDisplayLayoutProvider.mockInnerBoundsPt)
            XCTAssertEqual(provider.displayScale, DuoDisplayConstants.mockScaleFactor)
        }
    }
    
    func testMockDisplayLayoutProviderOuterDisplay() async {
        await MainActor.run {
            let provider = MockDisplayLayoutProvider(isInnerDisplay: false)
            
            XCTAssertFalse(provider.isInnerDisplay)
            XCTAssertEqual(provider.bounds, MockDisplayLayoutProvider.mockOuterBoundsPt)
        }
    }
    
    func testMockDisplayLayoutProviderCustomBounds() async {
        await MainActor.run {
            let customBounds = CGRect(x: 0, y: 0, width: 500, height: 400)
            let provider = MockDisplayLayoutProvider(bounds: customBounds)
            
            XCTAssertEqual(provider.bounds, customBounds)
        }
    }
    
    func testMockDisplayLayoutProviderSetters() async {
        await MainActor.run {
            let provider = MockDisplayLayoutProvider()
            
            let newBounds = CGRect(x: 0, y: 0, width: 800, height: 600)
            provider.setBounds(newBounds)
            XCTAssertEqual(provider.bounds, newBounds)
            
            provider.setDisplayScale(2.0)
            XCTAssertEqual(provider.displayScale, 2.0)
            
            let newInsets = EdgeInsets(top: 10, leading: 5, bottom: 20, trailing: 5)
            provider.setSafeAreaInsets(newInsets)
            XCTAssertEqual(provider.safeAreaInsets, newInsets)
        }
    }
    
    func testMockDisplayLayoutProviderSwitchDisplay() async {
        await MainActor.run {
            let provider = MockDisplayLayoutProvider(isInnerDisplay: true)
            XCTAssertEqual(provider.bounds, MockDisplayLayoutProvider.mockInnerBoundsPt)
            
            provider.setIsInnerDisplay(false)
            XCTAssertFalse(provider.isInnerDisplay)
            XCTAssertEqual(provider.bounds, MockDisplayLayoutProvider.mockOuterBoundsPt)
            
            provider.setIsInnerDisplay(true)
            XCTAssertTrue(provider.isInnerDisplay)
            XCTAssertEqual(provider.bounds, MockDisplayLayoutProvider.mockInnerBoundsPt)
        }
    }
    
    // MARK: - Mock Reserved Regions Provider Tests
    
    func testMockReservedRegionsProviderDefaultCrease() async {
        await MainActor.run {
            let provider = MockReservedRegionsProvider()
            
            // Default crease should be ~40pt wide, centered
            let crease = provider.divisionRegion
            XCTAssertEqual(crease.width, MockReservedRegionsProvider.mockCreaseWidthPt)
            
            // Should be centered in the default inner bounds
            let bounds = MockDisplayLayoutProvider.mockInnerBoundsPt
            let expectedX = (bounds.width - MockReservedRegionsProvider.mockCreaseWidthPt) / 2
            XCTAssertEqual(crease.origin.x, expectedX, accuracy: 0.01)
            XCTAssertEqual(crease.height, bounds.height)
        }
    }
    
    func testMockReservedRegionsProviderNoCrease() async {
        await MainActor.run {
            let provider = MockReservedRegionsProvider.noCrease()
            
            XCTAssertEqual(provider.divisionRegion, .zero)
            XCTAssertTrue(provider.occlusionRegions.isEmpty)
        }
    }
    
    func testMockReservedRegionsProviderCustomCrease() async {
        await MainActor.run {
            let customCrease = CGRect(x: 100, y: 0, width: 50, height: 669)
            let provider = MockReservedRegionsProvider(divisionRegion: customCrease)
            
            XCTAssertEqual(provider.divisionRegion, customCrease)
        }
    }
    
    func testMockReservedRegionsProviderOcclusions() async {
        await MainActor.run {
            let occlusions = [
                CGRect(x: 10, y: 10, width: 30, height: 40),
                CGRect(x: 900, y: 5, width: 20, height: 30)
            ]
            let provider = MockReservedRegionsProvider(occlusionRegions: occlusions)
            
            XCTAssertEqual(provider.occlusionRegions.count, 2)
            XCTAssertEqual(provider.occlusionRegions[0], occlusions[0])
            XCTAssertEqual(provider.occlusionRegions[1], occlusions[1])
        }
    }
    
    func testMockReservedRegionsProviderSetters() async {
        await MainActor.run {
            let provider = MockReservedRegionsProvider()
            
            let newCrease = CGRect(x: 200, y: 0, width: 60, height: 669)
            provider.setDivisionRegion(newCrease)
            XCTAssertEqual(provider.divisionRegion, newCrease)
            
            let newOcclusions = [CGRect(x: 50, y: 20, width: 25, height: 35)]
            provider.setOcclusionRegions(newOcclusions)
            XCTAssertEqual(provider.occlusionRegions, newOcclusions)
        }
    }
    
    // MARK: - Crease from Runtime Tests
    
    func testCreaseBandFromReservedRegions() async {
        await MainActor.run {
            let spec = DisplaySpecLoader.defaultSpec()
            let layout = MockDisplayLayoutProvider()
            let regions = MockReservedRegionsProvider()
            
            // Get crease band from runtime providers
            let band = spec.creaseBand(from: regions, layout: layout)
            XCTAssertNotNil(band)
            
            // Should be centered around 0.5
            let center = band!.center
            XCTAssertEqual(center, 0.5, accuracy: 0.01)
            
            // Width should be ~40pt / 951pt ≈ 0.042
            let expectedWidth = MockReservedRegionsProvider.mockCreaseWidthPt / MockDisplayLayoutProvider.mockInnerBoundsPt.width
            XCTAssertEqual(band!.width, expectedWidth, accuracy: 0.001)
        }
    }
    
    func testCreaseBandReturnsNilWhenFullyUnfolded() async {
        await MainActor.run {
            let spec = DisplaySpecLoader.defaultSpec()
            let layout = MockDisplayLayoutProvider()
            let regions = MockReservedRegionsProvider.noCrease()
            
            // When fully unfolded, crease region is zero
            let band = spec.creaseBand(from: regions, layout: layout)
            XCTAssertNil(band)
        }
    }
}
