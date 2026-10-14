import XCTest
@testable import FoldKit
@testable import DisplaySpecKit
@testable import EditorCore
@testable import RenderKit

final class DuoWallTests: XCTestCase {
    
    func testFoldStateProviderIntegration() {
        let mock = MockFoldStateProvider.noHinge()
        XCTAssertEqual(mock.state.posture, .noHinge)
        
        mock.set(.closed, angle: 0)
        XCTAssertEqual(mock.state.posture, .closed)
        
        mock.set(.fullyOpen, angle: 180)
        XCTAssertEqual(mock.state.posture, .fullyOpen)
    }
    
    func testDisplaySpecIntegration() {
        let spec = DisplaySpecLoader.shared.spec
        XCTAssertEqual(spec.inner.width, 2670)
        XCTAssertEqual(spec.inner.height, 1878)
    }
    
    func testLayerDocCreation() {
        let doc = LayerDoc.new(template: .reveal)
        XCTAssertEqual(doc.template, .reveal)
        XCTAssertFalse(doc.layers.isEmpty)
    }
    
    func testExportValidation() {
        let doc = LayerDoc.new()
        let result = ExportValidator.validate(doc)
        
        switch result {
        case .success:
            break
        case .failure:
            XCTFail("New document should be valid")
        }
    }
}
