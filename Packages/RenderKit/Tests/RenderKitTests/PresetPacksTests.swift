import XCTest
@testable import RenderKit

final class PresetPacksTests: XCTestCase {
    
    // MARK: - Main Pack Tests
    
    func testMainPackExists() {
        let pack = DefaultPacks.mainPack()
        
        XCTAssertEqual(pack.id, "main")
        XCTAssertFalse(pack.name.isEmpty)
        XCTAssertFalse(pack.pairs.isEmpty)
    }
    
    func testMainPackHas30Pairs() {
        let pack = DefaultPacks.mainPack()
        XCTAssertEqual(pack.pairs.count, 30, "Main pack should have 30 pairs (10 free + 20 premium)")
    }
    
    func testMainPackFreePairs() {
        let pack = DefaultPacks.mainPack()
        XCTAssertEqual(pack.freePairs.count, 10, "Should have 10 free pairs")
    }
    
    func testMainPackPremiumPairs() {
        let pack = DefaultPacks.mainPack()
        XCTAssertEqual(pack.premiumPairs.count, 20, "Should have 20 premium pairs")
    }
    
    // MARK: - Pair Manifest Tests
    
    func testPairManifestHasRequiredFields() {
        let pack = DefaultPacks.mainPack()
        
        for pair in pack.pairs {
            XCTAssertFalse(pair.id.isEmpty, "Pair should have ID")
            XCTAssertFalse(pair.title.isEmpty, "Pair should have title")
            XCTAssertFalse(pair.innerImageFile.isEmpty, "Pair should have image file")
            XCTAssertFalse(pair.accessibilityDescription.isEmpty, "Pair should have accessibility description")
        }
    }
    
    func testPairManifestLocalizedTitle() {
        let pair = DefaultPacks.freePairs().first!
        
        let englishTitle = pair.localizedTitle(for: "en")
        XCTAssertEqual(englishTitle, pair.title)
        
        let chineseTitle = pair.localizedTitle(for: "zh")
        XCTAssertFalse(chineseTitle.isEmpty)
    }
    
    func testPairManifestTemplates() {
        let pack = DefaultPacks.mainPack()
        
        let hasReveal = pack.pairs.contains { $0.template == .reveal }
        let hasPanorama = pack.pairs.contains { $0.template == .panorama }
        let hasSplitMood = pack.pairs.contains { $0.template == .splitMood }
        
        XCTAssertTrue(hasReveal, "Should have reveal templates")
        XCTAssertTrue(hasPanorama, "Should have panorama templates")
        XCTAssertTrue(hasSplitMood, "Should have split mood templates")
    }
    
    func testPairManifestHasPalette() {
        let freePairs = DefaultPacks.freePairs()
        
        for pair in freePairs {
            XCTAssertFalse(pair.palette.isEmpty, "Free pairs should have color palettes")
        }
    }
    
    // MARK: - Codable Tests
    
    func testPairManifestCodable() throws {
        let pair = DefaultPacks.freePairs().first!
        
        let encoded = try JSONEncoder().encode(pair)
        let decoded = try JSONDecoder().decode(PairManifest.self, from: encoded)
        
        XCTAssertEqual(pair.id, decoded.id)
        XCTAssertEqual(pair.title, decoded.title)
        XCTAssertEqual(pair.template, decoded.template)
        XCTAssertEqual(pair.isPremium, decoded.isPremium)
    }
    
    func testWallpaperPackCodable() throws {
        let pack = DefaultPacks.mainPack()
        
        let encoded = try JSONEncoder().encode(pack)
        let decoded = try JSONDecoder().decode(WallpaperPack.self, from: encoded)
        
        XCTAssertEqual(pack.id, decoded.id)
        XCTAssertEqual(pack.pairs.count, decoded.pairs.count)
    }
    
    // MARK: - License Tests
    
    func testMainPackHasLicense() {
        let pack = DefaultPacks.mainPack()
        XCTAssertFalse(pack.license.isEmpty, "Pack should have license information")
    }
    
    // MARK: - Unique IDs Tests
    
    func testAllPairsHaveUniqueIDs() {
        let pack = DefaultPacks.mainPack()
        let ids = pack.pairs.map { $0.id }
        let uniqueIds = Set(ids)
        
        XCTAssertEqual(ids.count, uniqueIds.count, "All pair IDs should be unique")
    }
    
    // MARK: - Accessibility Tests (AC11 related)
    
    func testAllPairsHaveAccessibilityDescriptions() {
        let pack = DefaultPacks.mainPack()
        
        for pair in pack.pairs {
            XCTAssertFalse(pair.accessibilityDescription.isEmpty,
                "Pair \(pair.id) should have accessibility description")
            
            XCTAssertGreaterThan(pair.accessibilityDescription.count, 10,
                "Accessibility description for \(pair.id) should be meaningful")
        }
    }
}
