import XCTest
@testable import EditorCore
@testable import DisplaySpecKit

final class EditorCommandTests: XCTestCase {
    
    // MARK: - Add Layer Tests
    
    func testAddLayerCommand() {
        let doc = LayerDoc.new()
        let photo = PhotoLayer(assetFile: "test.heic")
        let command = AddLayerCommand(layer: .photo(photo))
        
        let newDoc = command.apply(to: doc)
        
        XCTAssertEqual(newDoc.layers.count, doc.layers.count + 1)
        XCTAssertNotNil(newDoc.layer(withId: photo.id))
    }
    
    func testAddLayerAtIndex() {
        var doc = LayerDoc()
        doc.layers = [
            .fill(FillLayer(kind: .auto)),
            .fill(FillLayer(kind: .blurExtend))
        ]
        
        let photo = PhotoLayer(assetFile: "test.heic")
        let command = AddLayerCommand(layer: .photo(photo), atIndex: 1)
        
        let newDoc = command.apply(to: doc)
        
        XCTAssertEqual(newDoc.layers.count, 3)
        XCTAssertEqual(newDoc.layerIndex(withId: photo.id), 1)
    }
    
    func testAddLayerInverse() {
        let doc = LayerDoc.new()
        let photo = PhotoLayer(assetFile: "test.heic")
        let command = AddLayerCommand(layer: .photo(photo))
        
        let newDoc = command.apply(to: doc)
        let inverse = command.inverse(for: doc)
        let undoneDoc = inverse.apply(to: newDoc)
        
        XCTAssertEqual(undoneDoc.layers.count, doc.layers.count)
        XCTAssertNil(undoneDoc.layer(withId: photo.id))
    }
    
    // MARK: - Remove Layer Tests
    
    func testRemoveLayerCommand() {
        let photo = PhotoLayer(assetFile: "test.heic")
        var doc = LayerDoc()
        doc.layers = [.photo(photo)]
        
        let command = RemoveLayerCommand(layerId: photo.id)
        let newDoc = command.apply(to: doc)
        
        XCTAssertTrue(newDoc.layers.isEmpty)
    }
    
    func testRemoveLayerInverse() {
        let photo = PhotoLayer(assetFile: "test.heic")
        var doc = LayerDoc()
        doc.layers = [.photo(photo)]
        
        let command = RemoveLayerCommand(layerId: photo.id)
        let newDoc = command.apply(to: doc)
        
        let inverse = command.inverse(for: doc)
        let undoneDoc = inverse.apply(to: newDoc)
        
        XCTAssertEqual(undoneDoc.layers.count, 1)
        XCTAssertNotNil(undoneDoc.layer(withId: photo.id))
    }
    
    // MARK: - Reorder Layer Tests
    
    func testReorderLayerCommand() {
        let layer0 = FillLayer(kind: .auto)
        let layer1 = PhotoLayer(assetFile: "test.heic")
        let layer2 = FillLayer(kind: .blurExtend)
        
        var doc = LayerDoc()
        doc.layers = [.fill(layer0), .photo(layer1), .fill(layer2)]
        
        let command = ReorderLayerCommand(layerId: layer2.id, toIndex: 0)
        let newDoc = command.apply(to: doc)
        
        XCTAssertEqual(newDoc.layerIndex(withId: layer2.id), 0)
        XCTAssertEqual(newDoc.layerIndex(withId: layer0.id), 1)
        XCTAssertEqual(newDoc.layerIndex(withId: layer1.id), 2)
    }
    
    func testReorderLayerInverse() {
        let layer0 = FillLayer(kind: .auto)
        let layer1 = PhotoLayer(assetFile: "test.heic")
        
        var doc = LayerDoc()
        doc.layers = [.fill(layer0), .photo(layer1)]
        
        let command = ReorderLayerCommand(layerId: layer1.id, toIndex: 0)
        let newDoc = command.apply(to: doc)
        
        let inverse = command.inverse(for: doc)
        let undoneDoc = inverse.apply(to: newDoc)
        
        XCTAssertEqual(undoneDoc.layerIndex(withId: layer0.id), 0)
        XCTAssertEqual(undoneDoc.layerIndex(withId: layer1.id), 1)
    }
    
    // MARK: - Update Layer Tests
    
    func testUpdateLayerCommand() {
        var photo = PhotoLayer(assetFile: "test.heic")
        var doc = LayerDoc()
        doc.layers = [.photo(photo)]
        
        photo.assetFile = "updated.heic"
        let command = UpdateLayerCommand(layerId: photo.id, newLayer: .photo(photo))
        
        let newDoc = command.apply(to: doc)
        
        if case .photo(let updatedPhoto) = newDoc.layers[0] {
            XCTAssertEqual(updatedPhoto.assetFile, "updated.heic")
        } else {
            XCTFail("Layer should still be a photo")
        }
    }
    
    // MARK: - Transform Command Tests
    
    func testTransformLayerCommand() {
        let photo = PhotoLayer(assetFile: "test.heic", transform: .identity)
        var doc = LayerDoc()
        doc.layers = [.photo(photo)]
        
        let newTransform = LayerTransform(center: CGPoint(x: 0.3, y: 0.7), scale: 1.5, rotation: 45)
        let command = TransformLayerCommand(layerId: photo.id, newTransform: newTransform)
        
        let newDoc = command.apply(to: doc)
        
        if case .photo(let updatedPhoto) = newDoc.layers[0] {
            XCTAssertEqual(updatedPhoto.transform.center.x, 0.3, accuracy: 0.001)
            XCTAssertEqual(updatedPhoto.transform.scale, 1.5)
            XCTAssertEqual(updatedPhoto.transform.rotation, 45)
        } else {
            XCTFail("Layer should be a photo")
        }
    }
    
    func testTransformLayerInverse() {
        let originalTransform = LayerTransform(center: CGPoint(x: 0.5, y: 0.5), scale: 1.0, rotation: 0)
        let photo = PhotoLayer(assetFile: "test.heic", transform: originalTransform)
        var doc = LayerDoc()
        doc.layers = [.photo(photo)]
        
        let newTransform = LayerTransform(center: CGPoint(x: 0.3, y: 0.7), scale: 1.5, rotation: 45)
        let command = TransformLayerCommand(layerId: photo.id, newTransform: newTransform)
        
        let newDoc = command.apply(to: doc)
        let inverse = command.inverse(for: doc)
        let undoneDoc = inverse.apply(to: newDoc)
        
        if case .photo(let restoredPhoto) = undoneDoc.layers[0] {
            XCTAssertEqual(restoredPhoto.transform.center.x, originalTransform.center.x, accuracy: 0.001)
            XCTAssertEqual(restoredPhoto.transform.scale, originalTransform.scale)
            XCTAssertEqual(restoredPhoto.transform.rotation, originalTransform.rotation)
        } else {
            XCTFail("Layer should be a photo")
        }
    }
    
    // MARK: - Template Command Tests
    
    func testChangeTemplateCommand() {
        let doc = LayerDoc.new(template: .reveal)
        let command = ChangeTemplateCommand(newTemplate: .panorama)
        
        let newDoc = command.apply(to: doc)
        XCTAssertEqual(newDoc.template, .panorama)
    }
    
    func testChangeTemplateInverse() {
        let doc = LayerDoc.new(template: .reveal)
        let command = ChangeTemplateCommand(newTemplate: .panorama)
        
        let newDoc = command.apply(to: doc)
        let inverse = command.inverse(for: doc)
        let undoneDoc = inverse.apply(to: newDoc)
        
        XCTAssertEqual(undoneDoc.template, .reveal)
    }
    
    // MARK: - Outer Crop Command Tests
    
    func testSetOuterCropCommand() {
        let doc = LayerDoc()
        XCTAssertNil(doc.outerCrop)
        
        let customCrop = NormalizedRect(x: 0.2, y: 0, width: 0.6, height: 1)
        let command = SetOuterCropCommand(newCrop: customCrop)
        
        let newDoc = command.apply(to: doc)
        XCTAssertEqual(newDoc.outerCrop, customCrop)
    }
    
    func testSetOuterCropInverse() {
        let originalCrop = NormalizedRect(x: 0.25, y: 0, width: 0.5, height: 1)
        var doc = LayerDoc()
        doc.outerCrop = originalCrop
        
        let newCrop = NormalizedRect(x: 0.3, y: 0, width: 0.4, height: 1)
        let command = SetOuterCropCommand(newCrop: newCrop)
        
        let newDoc = command.apply(to: doc)
        let inverse = command.inverse(for: doc)
        let undoneDoc = inverse.apply(to: newDoc)
        
        XCTAssertEqual(undoneDoc.outerCrop, originalCrop)
    }
    
    // MARK: - Compound Command Tests
    
    func testCompoundCommand() {
        let doc = LayerDoc.new()
        
        let photo = PhotoLayer(assetFile: "test.heic")
        let commands: [any EditorCommand] = [
            AddLayerCommand(layer: .photo(photo)),
            ChangeTemplateCommand(newTemplate: .panorama)
        ]
        
        let compound = CompoundCommand(description: "Add Photo & Change Template", commands: commands)
        let newDoc = compound.apply(to: doc)
        
        XCTAssertNotNil(newDoc.layer(withId: photo.id))
        XCTAssertEqual(newDoc.template, .panorama)
    }
    
    func testCompoundCommandInverse() {
        let doc = LayerDoc.new(template: .reveal)
        
        let photo = PhotoLayer(assetFile: "test.heic")
        let commands: [any EditorCommand] = [
            AddLayerCommand(layer: .photo(photo)),
            ChangeTemplateCommand(newTemplate: .panorama)
        ]
        
        let compound = CompoundCommand(description: "Test", commands: commands)
        let newDoc = compound.apply(to: doc)
        
        let inverse = compound.inverse(for: doc)
        let undoneDoc = inverse.apply(to: newDoc)
        
        XCTAssertNil(undoneDoc.layer(withId: photo.id))
        XCTAssertEqual(undoneDoc.template, .reveal)
    }
    
    // MARK: - Modified Date Tests
    
    func testCommandUpdatesModifiedDate() {
        let doc = LayerDoc(modifiedAt: Date(timeIntervalSince1970: 1000))
        let command = ChangeTemplateCommand(newTemplate: .panorama)
        
        let newDoc = command.apply(to: doc)
        XCTAssertGreaterThan(newDoc.modifiedAt, doc.modifiedAt)
    }
}
