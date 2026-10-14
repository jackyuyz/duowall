import XCTest
@testable import FoldKit

final class FoldStateTests: XCTestCase {
    
    // MARK: - FoldPosture Tests
    
    func testFoldPostureCodable() throws {
        for posture in FoldPosture.allCases {
            let encoded = try JSONEncoder().encode(posture)
            let decoded = try JSONDecoder().decode(FoldPosture.self, from: encoded)
            XCTAssertEqual(posture, decoded)
        }
    }
    
    func testFoldPostureRawValues() {
        XCTAssertEqual(FoldPosture.noHinge.rawValue, "noHinge")
        XCTAssertEqual(FoldPosture.closed.rawValue, "closed")
        XCTAssertEqual(FoldPosture.partiallyOpen.rawValue, "partiallyOpen")
        XCTAssertEqual(FoldPosture.fullyOpen.rawValue, "fullyOpen")
        XCTAssertEqual(FoldPosture.unknown.rawValue, "unknown")
    }
    
    // MARK: - FoldState Tests
    
    func testFoldStateNoHinge() {
        let state = FoldState.noHinge
        XCTAssertEqual(state.posture, .noHinge)
        XCTAssertNil(state.angleDegrees)
        XCTAssertFalse(state.hasHinge)
        XCTAssertFalse(state.isUnfolded)
    }
    
    func testFoldStateHasHinge() {
        let closed = FoldState(posture: .closed, angleDegrees: 0)
        XCTAssertTrue(closed.hasHinge)
        
        let partial = FoldState(posture: .partiallyOpen, angleDegrees: 90)
        XCTAssertTrue(partial.hasHinge)
        
        let open = FoldState(posture: .fullyOpen, angleDegrees: 180)
        XCTAssertTrue(open.hasHinge)
        
        let noHinge = FoldState(posture: .noHinge)
        XCTAssertFalse(noHinge.hasHinge)
    }
    
    func testFoldStateIsUnfolded() {
        XCTAssertFalse(FoldState(posture: .closed, angleDegrees: 0).isUnfolded)
        XCTAssertFalse(FoldState(posture: .noHinge).isUnfolded)
        XCTAssertFalse(FoldState(posture: .unknown).isUnfolded)
        
        XCTAssertTrue(FoldState(posture: .partiallyOpen, angleDegrees: 90).isUnfolded)
        XCTAssertTrue(FoldState(posture: .fullyOpen, angleDegrees: 180).isUnfolded)
    }
    
    func testFoldStateCodable() throws {
        let original = FoldState(posture: .partiallyOpen, angleDegrees: 95.5, timestamp: Date(timeIntervalSince1970: 1000))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FoldState.self, from: encoded)
        
        XCTAssertEqual(original.posture, decoded.posture)
        XCTAssertEqual(original.angleDegrees, decoded.angleDegrees)
        XCTAssertEqual(original.timestamp, decoded.timestamp)
    }
    
    func testFoldStateEquatable() {
        let state1 = FoldState(posture: .closed, angleDegrees: 5, timestamp: Date(timeIntervalSince1970: 100))
        let state2 = FoldState(posture: .closed, angleDegrees: 5, timestamp: Date(timeIntervalSince1970: 100))
        let state3 = FoldState(posture: .closed, angleDegrees: 10, timestamp: Date(timeIntervalSince1970: 100))
        
        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
    }
}
