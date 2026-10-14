import XCTest
@testable import RenderKit
@testable import DisplaySpecKit
@testable import EditorCore

final class ExportConfigTests: XCTestCase {
    
    // MARK: - Export Config Tests
    
    func testDefaultConfig() {
        let config = ExportConfig()
        
        XCTAssertEqual(config.format, .heic)
        XCTAssertEqual(config.colorSpace, .srgb)
        XCTAssertFalse(config.includeWatermark)
        XCTAssertEqual(config.quality, 0.9)
    }
    
    func testFreeConfig() {
        let config = ExportConfig.free
        XCTAssertTrue(config.includeWatermark)
    }
    
    func testProConfig() {
        let config = ExportConfig.pro
        XCTAssertFalse(config.includeWatermark)
    }
    
    func testFilenameGeneration() {
        let config = ExportConfig(format: .heic)
        let filename = config.generateFilename()
        
        XCTAssertTrue(filename.hasPrefix("DuoWall-"))
        XCTAssertTrue(filename.hasSuffix(".heic"))
    }
    
    func testFilenameGenerationPNG() {
        let config = ExportConfig(format: .png)
        let filename = config.generateFilename()
        
        XCTAssertTrue(filename.hasSuffix(".png"))
    }
    
    func testFilenameGenerationCustomPrefix() {
        let config = ExportConfig(format: .heic)
        let filename = config.generateFilename(prefix: "MyWallpaper")
        
        XCTAssertTrue(filename.hasPrefix("MyWallpaper-"))
    }
    
    func testConfigCodable() throws {
        let config = ExportConfig(
            format: .png,
            colorSpace: .displayP3,
            includeWatermark: true,
            quality: 0.85
        )
        
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ExportConfig.self, from: encoded)
        
        XCTAssertEqual(config, decoded)
    }
    
    // MARK: - Export Format Tests
    
    func testExportFormatExtensions() {
        XCTAssertEqual(ExportFormat.heic.fileExtension, "heic")
        XCTAssertEqual(ExportFormat.png.fileExtension, "png")
    }
    
    func testExportFormatMimeTypes() {
        XCTAssertEqual(ExportFormat.heic.mimeType, "image/heic")
        XCTAssertEqual(ExportFormat.png.mimeType, "image/png")
    }
    
    // MARK: - Export Validation Tests (AC1)
    
    func testValidateEmptyDocument() {
        let doc = LayerDoc()
        let result = ExportValidator.validate(doc)
        
        switch result {
        case .failure(let error):
            if case .noLayers = error {
            } else {
                XCTFail("Expected noLayers error")
            }
        case .success:
            XCTFail("Empty document should fail validation")
        }
    }
    
    func testValidateValidDocument() {
        var doc = LayerDoc.new()
        doc.layers.append(.photo(PhotoLayer(assetFile: "test.heic")))
        
        let result = ExportValidator.validate(doc)
        
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Valid document should pass validation: \(error)")
        }
    }
    
    func testValidateInvalidCanvas() {
        var doc = LayerDoc()
        doc.canvas = CGSize(width: 0, height: 0)
        doc.layers = [.fill(FillLayer(kind: .auto))]
        
        let result = ExportValidator.validate(doc)
        
        switch result {
        case .failure(let error):
            if case .invalidDocument = error {
            } else {
                XCTFail("Expected invalidDocument error")
            }
        case .success:
            XCTFail("Invalid canvas should fail validation")
        }
    }
    
    // MARK: - AC1: Output Size Validation
    
    func testAC1OutputSizeValidation() {
        let spec = DisplaySpecLoader.defaultSpec()
        
        let validSize = CGSize(width: 2670, height: 1878)
        XCTAssertTrue(ExportValidator.validateOutputSize(validSize, spec: spec),
            "AC1: Exported wallpaper should be exactly 2670×1878 px")
        
        let invalidSize = CGSize(width: 2670, height: 1879)
        XCTAssertFalse(ExportValidator.validateOutputSize(invalidSize, spec: spec))
        
        let wrongAspect = CGSize(width: 1920, height: 1080)
        XCTAssertFalse(ExportValidator.validateOutputSize(wrongAspect, spec: spec))
    }
    
    // MARK: - Export Result Tests
    
    func testExportResultCreation() {
        let result = ExportResult(
            innerImagePath: "/path/to/inner.heic",
            outerPreviewPath: "/path/to/outer.heic",
            innerSize: CGSize(width: 2670, height: 1878),
            outerPreviewSize: CGSize(width: 1398, height: 2034),
            config: .pro
        )
        
        XCTAssertEqual(result.innerImagePath, "/path/to/inner.heic")
        XCTAssertEqual(result.outerPreviewPath, "/path/to/outer.heic")
        XCTAssertEqual(result.innerSize.width, 2670)
        XCTAssertEqual(result.innerSize.height, 1878)
        XCTAssertFalse(result.config.includeWatermark)
    }
}
