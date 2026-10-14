import XCTest
@testable import EditorCore
@testable import DisplaySpecKit

final class LayerDocTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testDefaultInitialization() {
        let doc = LayerDoc()
        
        XCTAssertEqual(doc.canvas.width, 2670)
        XCTAssertEqual(doc.canvas.height, 1878)
        XCTAssertTrue(doc.layers.isEmpty)
        XCTAssertEqual(doc.template, .reveal)
        XCTAssertNil(doc.outerCrop)
    }
    
    func testNewDocumentHasFillLayer() {
        let doc = LayerDoc.new()
        
        XCTAssertEqual(doc.layers.count, 1)
        XCTAssertFalse(doc.fillLayers.isEmpty)
    }
    
    func testNewDocumentWithTemplate() {
        let doc = LayerDoc.new(template: .panorama)
        XCTAssertEqual(doc.template, .panorama)
    }
    
    // MARK: - Layer Query Tests
    
    func testLayerById() {
        let photoLayer = PhotoLayer(assetFile: "test.heic")
        var doc = LayerDoc()
        doc.layers = [.photo(photoLayer)]
        
        let found = doc.layer(withId: photoLayer.id)
        XCTAssertNotNil(found)
        
        let notFound = doc.layer(withId: UUID())
        XCTAssertNil(notFound)
    }
    
    func testLayerIndex() {
        let layer1 = PhotoLayer(assetFile: "1.heic")
        let layer2 = FillLayer(kind: .auto)
        var doc = LayerDoc()
        doc.layers = [.photo(layer1), .fill(layer2)]
        
        XCTAssertEqual(doc.layerIndex(withId: layer1.id), 0)
        XCTAssertEqual(doc.layerIndex(withId: layer2.id), 1)
        XCTAssertNil(doc.layerIndex(withId: UUID()))
    }
    
    func testPhotoLayers() {
        let photo1 = PhotoLayer(assetFile: "1.heic")
        let photo2 = PhotoLayer(assetFile: "2.heic")
        let fill = FillLayer(kind: .auto)
        
        var doc = LayerDoc()
        doc.layers = [.photo(photo1), .fill(fill), .photo(photo2)]
        
        XCTAssertEqual(doc.photoLayers.count, 2)
    }
    
    func testFillLayers() {
        let fill1 = FillLayer(kind: .auto)
        let fill2 = FillLayer(kind: .blurExtend)
        let photo = PhotoLayer(assetFile: "test.heic")
        
        var doc = LayerDoc()
        doc.layers = [.fill(fill1), .photo(photo), .fill(fill2)]
        
        XCTAssertEqual(doc.fillLayers.count, 2)
    }
    
    // MARK: - Effective Outer Crop Tests
    
    func testEffectiveOuterCropUsesDefault() {
        let doc = LayerDoc()
        let spec = DisplaySpecLoader.defaultSpec()
        
        let crop = doc.effectiveOuterCrop(using: spec)
        XCTAssertEqual(crop, spec.singleImage.outerCrop)
    }
    
    func testEffectiveOuterCropUsesCustom() {
        let customCrop = NormalizedRect(x: 0.2, y: 0, width: 0.6, height: 1)
        var doc = LayerDoc()
        doc.outerCrop = customCrop
        
        let spec = DisplaySpecLoader.defaultSpec()
        let crop = doc.effectiveOuterCrop(using: spec)
        
        XCTAssertEqual(crop, customCrop)
    }
    
    // MARK: - Layer Visibility Tests
    
    func testLayerVisibility() {
        var layer = Layer.photo(PhotoLayer(assetFile: "test.heic"))
        XCTAssertTrue(layer.isVisible)
        
        layer.isVisible = false
        XCTAssertFalse(layer.isVisible)
    }
    
    // MARK: - Codable Tests
    
    func testLayerDocCodable() throws {
        var doc = LayerDoc.new(template: .reveal)
        doc.layers.append(.photo(PhotoLayer(assetFile: "photo.heic")))
        doc.layers.append(.text(TextLayer(text: "Hello")))
        
        let encoded = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(LayerDoc.self, from: encoded)
        
        XCTAssertEqual(doc.canvas, decoded.canvas)
        XCTAssertEqual(doc.template, decoded.template)
        XCTAssertEqual(doc.layers.count, decoded.layers.count)
    }
    
    func testAllLayerTypesCodable() throws {
        let layers: [Layer] = [
            .photo(PhotoLayer(assetFile: "test.heic", transform: .identity)),
            .fill(FillLayer(kind: .blurExtend)),
            .fill(FillLayer(kind: .mirrorExtend)),
            .fill(FillLayer(kind: .solid(hex: "#FF0000"))),
            .fill(FillLayer(kind: .auto)),
            .text(TextLayer(text: "Test")),
            .gradient(GradientLayer(stops: [
                GradientStop(colorHex: "#000000", location: 0),
                GradientStop(colorHex: "#FFFFFF", location: 1)
            ]))
        ]
        
        for layer in layers {
            let encoded = try JSONEncoder().encode(layer)
            let decoded = try JSONDecoder().decode(Layer.self, from: encoded)
            XCTAssertEqual(layer.id, decoded.id, "Layer \(layer.typeName) should round-trip")
        }
    }
    
    // MARK: - Template Tests
    
    func testAllTemplates() {
        for template in TemplateKind.allCases {
            XCTAssertFalse(template.displayName.isEmpty)
            XCTAssertFalse(template.description.isEmpty)
        }
    }
    
    // MARK: - Transform Tests
    
    func testTransformIdentity() {
        let transform = LayerTransform.identity
        XCTAssertEqual(transform.center.x, 0.5)
        XCTAssertEqual(transform.center.y, 0.5)
        XCTAssertEqual(transform.scale, 1.0)
        XCTAssertEqual(transform.rotation, 0)
    }
    
    func testTransformTranslated() {
        let transform = LayerTransform.identity.translated(by: CGPoint(x: 0.1, y: -0.1))
        XCTAssertEqual(transform.center.x, 0.6, accuracy: 0.001)
        XCTAssertEqual(transform.center.y, 0.4, accuracy: 0.001)
    }
    
    func testTransformScaled() {
        let transform = LayerTransform.identity.scaled(by: 2.0)
        XCTAssertEqual(transform.scale, 2.0)
    }
    
    func testTransformRotated() {
        let transform = LayerTransform.identity.rotated(by: 45)
        XCTAssertEqual(transform.rotation, 45)
    }
}
