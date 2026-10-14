import XCTest
@testable import FoldKit

actor ReceivedStatesBox {
    var states: [FoldState] = []
    
    func append(_ state: FoldState) {
        states.append(state)
    }
}

final class FoldStateProviderTests: XCTestCase {
    
    // MARK: - MockFoldStateProvider Tests
    
    func testMockProviderInitialState() {
        let provider = MockFoldStateProvider.noHinge()
        XCTAssertEqual(provider.state.posture, .noHinge)
        
        let closed = MockFoldStateProvider.closed()
        XCTAssertEqual(closed.state.posture, .closed)
        XCTAssertEqual(closed.state.angleDegrees, 0)
        
        let open = MockFoldStateProvider.fullyOpen()
        XCTAssertEqual(open.state.posture, .fullyOpen)
        XCTAssertEqual(open.state.angleDegrees, 180)
        
        let partial = MockFoldStateProvider.partiallyOpen(angle: 95)
        XCTAssertEqual(partial.state.posture, .partiallyOpen)
        XCTAssertEqual(partial.state.angleDegrees, 95)
    }
    
    func testMockProviderSetState() {
        let provider = MockFoldStateProvider.noHinge()
        
        provider.set(.closed, angle: 0)
        XCTAssertEqual(provider.state.posture, .closed)
        XCTAssertEqual(provider.state.angleDegrees, 0)
        
        provider.set(.partiallyOpen, angle: 90)
        XCTAssertEqual(provider.state.posture, .partiallyOpen)
        XCTAssertEqual(provider.state.angleDegrees, 90)
        
        provider.set(.fullyOpen, angle: 180)
        XCTAssertEqual(provider.state.posture, .fullyOpen)
        XCTAssertEqual(provider.state.angleDegrees, 180)
    }
    
    func testMockProviderFromLaunchArgument() {
        let noHinge = MockFoldStateProvider.from(launchArgument: "nohinge")
        XCTAssertEqual(noHinge.state.posture, .noHinge)
        
        let closed = MockFoldStateProvider.from(launchArgument: "closed")
        XCTAssertEqual(closed.state.posture, .closed)
        
        let open = MockFoldStateProvider.from(launchArgument: "open")
        XCTAssertEqual(open.state.posture, .fullyOpen)
        
        let half = MockFoldStateProvider.from(launchArgument: "half:95")
        XCTAssertEqual(half.state.posture, .partiallyOpen)
        XCTAssertEqual(half.state.angleDegrees, 95)
        
        let halfDefault = MockFoldStateProvider.from(launchArgument: "half:")
        XCTAssertEqual(halfDefault.state.angleDegrees, 90)
    }
    
    func testMockProviderAsyncStream() async {
        let provider = MockFoldStateProvider.closed()
        
        let receivedStates = ReceivedStatesBox()
        let expectation = XCTestExpectation(description: "Receive states")
        
        let task = Task {
            var count = 0
            for await state in provider.states() {
                await receivedStates.append(state)
                count += 1
                if count >= 3 {
                    expectation.fulfill()
                    break
                }
            }
        }
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        provider.set(.partiallyOpen, angle: 90)
        try? await Task.sleep(nanoseconds: 50_000_000)
        provider.set(.fullyOpen, angle: 180)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        task.cancel()
        
        let states = await receivedStates.states
        XCTAssertEqual(states.count, 3)
        XCTAssertEqual(states[0].posture, .closed)
        XCTAssertEqual(states[1].posture, .partiallyOpen)
        XCTAssertEqual(states[2].posture, .fullyOpen)
    }
    
    // MARK: - SystemFoldStateProvider Tests
    
    func testSystemProviderInitialState() {
        let provider = SystemFoldStateProvider()
        XCTAssertEqual(provider.state, .noHinge)
    }
    
    func testSystemProviderIngestNoHinge() {
        let provider = SystemFoldStateProvider()
        provider.ingestNoHinge()
        XCTAssertEqual(provider.state.posture, .noHinge)
    }
    
    func testSystemProviderIngestHingeStatus() {
        let provider = SystemFoldStateProvider()
        
        provider.ingest(angleDegrees: 0, statusRaw: "closed")
        XCTAssertEqual(provider.state.posture, .closed)
        XCTAssertEqual(provider.state.angleDegrees, 0)
        
        provider.ingest(angleDegrees: 90, statusRaw: "partiallyOpen")
        XCTAssertEqual(provider.state.posture, .partiallyOpen)
        XCTAssertEqual(provider.state.angleDegrees, 90)
        
        provider.ingest(angleDegrees: 180, statusRaw: "fullyOpen")
        XCTAssertEqual(provider.state.posture, .fullyOpen)
        XCTAssertEqual(provider.state.angleDegrees, 180)
        
        provider.ingest(angleDegrees: nil, statusRaw: "unknownValue")
        XCTAssertEqual(provider.state.posture, .unknown)
    }
    
    // MARK: - FoldScriptStep Tests
    
    func testFoldScriptStepSweep() {
        let steps = FoldScriptStep.sweep(from: 0, to: 180, duration: 1.0, steps: 10)
        
        XCTAssertEqual(steps.count, 11) // 0 to 10 inclusive
        XCTAssertEqual(steps.first?.angleDegrees, 0)
        XCTAssertEqual(steps.last?.angleDegrees, 180)
        
        XCTAssertEqual(steps[0].posture, .closed)
        XCTAssertEqual(steps[5].posture, .partiallyOpen)
        XCTAssertEqual(steps[10].posture, .fullyOpen)
        
        let totalDuration = steps.reduce(0) { $0 + $1.durationSeconds }
        XCTAssertEqual(totalDuration, 1.1, accuracy: 0.01)
    }
    
    func testFoldScriptStepCodable() throws {
        let step = FoldScriptStep(posture: .partiallyOpen, angleDegrees: 90, durationSeconds: 0.5)
        let encoded = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(FoldScriptStep.self, from: encoded)
        XCTAssertEqual(step, decoded)
    }
}
