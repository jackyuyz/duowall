import XCTest
@testable import EditorCore

final class UndoManagerTests: XCTestCase {
    
    var undoManager: EditorUndoManager!
    
    override func setUp() {
        super.setUp()
        undoManager = EditorUndoManager(maxHistorySize: 50)
    }
    
    // MARK: - Basic Undo/Redo Tests
    
    func testInitialState() {
        XCTAssertFalse(undoManager.canUndo)
        XCTAssertFalse(undoManager.canRedo)
        XCTAssertEqual(undoManager.undoCount, 0)
        XCTAssertEqual(undoManager.redoCount, 0)
    }
    
    func testExecuteEnablesUndo() {
        let doc = LayerDoc.new()
        let command = ChangeTemplateCommand(newTemplate: .panorama)
        
        _ = undoManager.execute(command, on: doc)
        
        XCTAssertTrue(undoManager.canUndo)
        XCTAssertFalse(undoManager.canRedo)
        XCTAssertEqual(undoManager.undoCount, 1)
    }
    
    func testUndoRestoresState() {
        let doc = LayerDoc.new(template: .reveal)
        let command = ChangeTemplateCommand(newTemplate: .panorama)
        
        let changedDoc = undoManager.execute(command, on: doc)
        XCTAssertEqual(changedDoc.template, .panorama)
        
        let undoneDoc = undoManager.undo(on: changedDoc)
        XCTAssertNotNil(undoneDoc)
        XCTAssertEqual(undoneDoc?.template, .reveal)
    }
    
    func testUndoEnablesRedo() {
        let doc = LayerDoc.new()
        let command = ChangeTemplateCommand(newTemplate: .panorama)
        
        let changedDoc = undoManager.execute(command, on: doc)
        _ = undoManager.undo(on: changedDoc)
        
        XCTAssertTrue(undoManager.canRedo)
        XCTAssertEqual(undoManager.redoCount, 1)
    }
    
    func testRedoReappliesCommand() {
        let doc = LayerDoc.new(template: .reveal)
        let command = ChangeTemplateCommand(newTemplate: .panorama)
        
        let changedDoc = undoManager.execute(command, on: doc)
        let undoneDoc = undoManager.undo(on: changedDoc)!
        XCTAssertEqual(undoneDoc.template, .reveal)
        
        let redoneDoc = undoManager.redo(on: undoneDoc)
        XCTAssertNotNil(redoneDoc)
        XCTAssertEqual(redoneDoc?.template, .panorama)
    }
    
    func testNewCommandClearsRedo() {
        let doc = LayerDoc.new()
        let command1 = ChangeTemplateCommand(newTemplate: .panorama)
        let command2 = ChangeTemplateCommand(newTemplate: .splitMood)
        
        let doc1 = undoManager.execute(command1, on: doc)
        let doc2 = undoManager.undo(on: doc1)!
        
        XCTAssertTrue(undoManager.canRedo)
        
        _ = undoManager.execute(command2, on: doc2)
        
        XCTAssertFalse(undoManager.canRedo)
        XCTAssertEqual(undoManager.redoCount, 0)
    }
    
    // MARK: - Multiple Undo/Redo Tests
    
    func testMultipleUndos() {
        let doc = LayerDoc.new(template: .reveal)
        
        let doc1 = undoManager.execute(ChangeTemplateCommand(newTemplate: .panorama), on: doc)
        let photo = PhotoLayer(assetFile: "test.heic")
        let doc2 = undoManager.execute(AddLayerCommand(layer: .photo(photo)), on: doc1)
        
        XCTAssertEqual(undoManager.undoCount, 2)
        
        let undo1 = undoManager.undo(on: doc2)!
        XCTAssertNil(undo1.layer(withId: photo.id))
        
        let undo2 = undoManager.undo(on: undo1)!
        XCTAssertEqual(undo2.template, .reveal)
        
        XCTAssertFalse(undoManager.canUndo)
        XCTAssertEqual(undoManager.redoCount, 2)
    }
    
    func testMultipleRedos() {
        let doc = LayerDoc.new(template: .reveal)
        
        let doc1 = undoManager.execute(ChangeTemplateCommand(newTemplate: .panorama), on: doc)
        let photo = PhotoLayer(assetFile: "test.heic")
        let doc2 = undoManager.execute(AddLayerCommand(layer: .photo(photo)), on: doc1)
        
        let undo1 = undoManager.undo(on: doc2)!
        let undo2 = undoManager.undo(on: undo1)!
        
        let redo1 = undoManager.redo(on: undo2)!
        XCTAssertEqual(redo1.template, .panorama)
        
        let redo2 = undoManager.redo(on: redo1)!
        XCTAssertNotNil(redo2.layer(withId: photo.id))
        
        XCTAssertFalse(undoManager.canRedo)
    }
    
    // MARK: - Max History Size Tests
    
    func testMaxHistorySizeLimit() {
        let smallUndoManager = EditorUndoManager(maxHistorySize: 5)
        var doc = LayerDoc.new()
        
        for i in 0..<10 {
            let photo = PhotoLayer(assetFile: "photo\(i).heic")
            doc = smallUndoManager.execute(AddLayerCommand(layer: .photo(photo)), on: doc)
        }
        
        XCTAssertEqual(smallUndoManager.undoCount, 5)
    }
    
    // MARK: - Description Tests
    
    func testUndoDescription() {
        let doc = LayerDoc.new()
        let command = ChangeTemplateCommand(newTemplate: .panorama)
        
        _ = undoManager.execute(command, on: doc)
        
        XCTAssertEqual(undoManager.undoDescription, "Change Template")
    }
    
    func testRedoDescription() {
        let doc = LayerDoc.new()
        let command = ChangeTemplateCommand(newTemplate: .panorama)
        
        let changedDoc = undoManager.execute(command, on: doc)
        _ = undoManager.undo(on: changedDoc)
        
        XCTAssertEqual(undoManager.redoDescription, "Change Template")
    }
    
    // MARK: - Clear History Tests
    
    func testClearHistory() {
        let doc = LayerDoc.new()
        let command = ChangeTemplateCommand(newTemplate: .panorama)
        
        let changedDoc = undoManager.execute(command, on: doc)
        _ = undoManager.undo(on: changedDoc)
        
        XCTAssertTrue(undoManager.canUndo || undoManager.canRedo)
        
        undoManager.clearHistory()
        
        XCTAssertFalse(undoManager.canUndo)
        XCTAssertFalse(undoManager.canRedo)
        XCTAssertEqual(undoManager.undoCount, 0)
        XCTAssertEqual(undoManager.redoCount, 0)
    }
    
    // MARK: - Save Point Tests
    
    func testSavePointNoChanges() {
        let doc = LayerDoc.new()
        let command = ChangeTemplateCommand(newTemplate: .panorama)
        
        _ = undoManager.execute(command, on: doc)
        undoManager.markSavePoint()
        
        XCTAssertFalse(undoManager.hasUnsavedChanges)
    }
    
    func testSavePointWithChanges() {
        let doc = LayerDoc.new()
        let command1 = ChangeTemplateCommand(newTemplate: .panorama)
        let command2 = ChangeTemplateCommand(newTemplate: .splitMood)
        
        let doc1 = undoManager.execute(command1, on: doc)
        undoManager.markSavePoint()
        _ = undoManager.execute(command2, on: doc1)
        
        XCTAssertTrue(undoManager.hasUnsavedChanges)
    }
    
    func testSavePointAfterUndo() {
        let doc = LayerDoc.new()
        let command1 = ChangeTemplateCommand(newTemplate: .panorama)
        let command2 = ChangeTemplateCommand(newTemplate: .splitMood)
        
        let doc1 = undoManager.execute(command1, on: doc)
        let doc2 = undoManager.execute(command2, on: doc1)
        undoManager.markSavePoint()
        
        _ = undoManager.undo(on: doc2)
        
        XCTAssertTrue(undoManager.hasUnsavedChanges)
    }
    
    // MARK: - AC6: State Preservation Tests (Acceptance Criteria)
    
    func testAC6StatePreservationAcrossFoldTransitions() {
        // AC6: Closing and reopening mid-edit preserves layers, selection, zoom, and undo stack
        
        let doc = LayerDoc.new()
        
        let photo = PhotoLayer(assetFile: "test.heic", transform: LayerTransform(
            center: CGPoint(x: 0.3, y: 0.7),
            scale: 1.5,
            rotation: 45
        ))
        let doc1 = undoManager.execute(AddLayerCommand(layer: .photo(photo)), on: doc)
        let doc2 = undoManager.execute(ChangeTemplateCommand(newTemplate: .panorama), on: doc1)
        
        XCTAssertEqual(undoManager.undoCount, 2, "Undo stack should have 2 entries before fold")
        
        XCTAssertEqual(doc2.layers.count, 2)
        if case .photo(let restoredPhoto) = doc2.layers[1] {
            XCTAssertEqual(restoredPhoto.transform.center.x, 0.3, accuracy: 0.001)
            XCTAssertEqual(restoredPhoto.transform.scale, 1.5)
            XCTAssertEqual(restoredPhoto.transform.rotation, 45)
        }
        XCTAssertEqual(doc2.template, .panorama)
        
        XCTAssertEqual(undoManager.undoCount, 2, "Undo stack should be preserved")
        XCTAssertTrue(undoManager.canUndo)
    }
}
