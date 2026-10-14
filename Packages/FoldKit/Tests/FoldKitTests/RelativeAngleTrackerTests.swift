import XCTest
@testable import FoldKit

final class RelativeAngleTrackerTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        let tracker = RelativeAngleTracker()
        XCTAssertNil(tracker.anchorDegrees)
        XCTAssertFalse(tracker.isAnchored)
        XCTAssertEqual(tracker.smoothing, 0.25)
    }
    
    func testCustomInitialization() {
        let tracker = RelativeAngleTracker(
            anchorDegrees: 90,
            observedMin: 85,
            observedMax: 95,
            smoothing: 0.5
        )
        XCTAssertEqual(tracker.anchorDegrees, 90)
        XCTAssertEqual(tracker.observedMin, 85)
        XCTAssertEqual(tracker.observedMax, 95)
        XCTAssertEqual(tracker.smoothing, 0.5)
        XCTAssertTrue(tracker.isAnchored)
    }
    
    // MARK: - Begin Tests
    
    func testBeginSetsAnchor() {
        var tracker = RelativeAngleTracker()
        tracker.begin(at: 45)
        
        XCTAssertEqual(tracker.anchorDegrees, 45)
        XCTAssertEqual(tracker.observedMin, 45)
        XCTAssertEqual(tracker.observedMax, 45)
        XCTAssertTrue(tracker.isAnchored)
    }
    
    func testBeginResetsObservations() {
        var tracker = RelativeAngleTracker(
            anchorDegrees: 90,
            observedMin: 80,
            observedMax: 100
        )
        
        tracker.begin(at: 45)
        
        XCTAssertEqual(tracker.anchorDegrees, 45)
        XCTAssertEqual(tracker.observedMin, 45)
        XCTAssertEqual(tracker.observedMax, 45)
    }
    
    // MARK: - Update Tests
    
    func testUpdateAutoAnchors() {
        var tracker = RelativeAngleTracker()
        let progress = tracker.update(50)
        
        XCTAssertTrue(tracker.isAnchored)
        XCTAssertEqual(tracker.anchorDegrees, 50)
        XCTAssertEqual(progress, 0)
    }
    
    func testUpdateProgressIncreases() {
        var tracker = RelativeAngleTracker(smoothing: 1.0) // No smoothing for predictable results
        tracker.begin(at: 90)
        
        let p1 = tracker.update(100)
        let p2 = tracker.update(120)
        let p3 = tracker.update(150)
        
        XCTAssertGreaterThan(p1, 0)
        XCTAssertGreaterThan(p2, p1)
        XCTAssertGreaterThan(p3, p2)
    }
    
    func testUpdateProgressClamps() {
        var tracker = RelativeAngleTracker(smoothing: 1.0)
        tracker.begin(at: 90)
        
        let p1 = tracker.update(180)
        let p2 = tracker.update(200) // Beyond typical range
        
        XCTAssertLessThanOrEqual(p1, 1.0)
        XCTAssertLessThanOrEqual(p2, 1.0)
        XCTAssertGreaterThanOrEqual(p1, 0.0)
    }
    
    func testUpdateProgressMonotonicallyIncreasesOnSweep() {
        var tracker = RelativeAngleTracker(smoothing: 0.5)
        tracker.begin(at: 20)
        
        var previousProgress: Double = -1
        for angle in stride(from: 20.0, to: 180.0, by: 5.0) {
            let progress = tracker.update(angle)
            XCTAssertGreaterThanOrEqual(progress, previousProgress - 0.05, // Allow small tolerance for smoothing
                "Progress should increase monotonically: angle=\(angle), progress=\(progress), previous=\(previousProgress)")
            previousProgress = progress
        }
    }
    
    func testUpdateExpandsObservedRange() {
        var tracker = RelativeAngleTracker()
        tracker.begin(at: 90)
        
        _ = tracker.update(80)
        XCTAssertEqual(tracker.observedMin, 80)
        
        _ = tracker.update(110)
        XCTAssertEqual(tracker.observedMax, 110)
        
        XCTAssertEqual(tracker.currentRangeSpan, 30)
    }
    
    // MARK: - Delta Tests
    
    func testDeltaFromAnchor() {
        var tracker = RelativeAngleTracker()
        tracker.begin(at: 90)
        
        XCTAssertEqual(tracker.delta(90), 0)
        XCTAssertEqual(tracker.delta(100), 10)
        XCTAssertEqual(tracker.delta(80), -10)
        XCTAssertEqual(tracker.delta(180), 90)
    }
    
    func testDeltaAutoAnchors() {
        var tracker = RelativeAngleTracker()
        let delta = tracker.delta(45)
        
        XCTAssertEqual(delta, 0)
        XCTAssertTrue(tracker.isAnchored)
        XCTAssertEqual(tracker.anchorDegrees, 45)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        var tracker = RelativeAngleTracker()
        tracker.begin(at: 90)
        _ = tracker.update(120)
        _ = tracker.update(60)
        
        tracker.reset()
        
        XCTAssertNil(tracker.anchorDegrees)
        XCTAssertEqual(tracker.observedMin, .infinity)
        XCTAssertEqual(tracker.observedMax, -.infinity)
        XCTAssertFalse(tracker.isAnchored)
    }
    
    // MARK: - Smoothing Tests
    
    func testSmoothingReducesJitter() {
        var smoothed = RelativeAngleTracker(smoothing: 0.1)
        var unsmoothed = RelativeAngleTracker(smoothing: 1.0)
        
        smoothed.begin(at: 90)
        unsmoothed.begin(at: 90)
        
        let angles = [100.0, 95.0, 102.0, 98.0, 101.0, 99.0, 100.0]
        var smoothedChanges: [Double] = []
        var unsmoothedChanges: [Double] = []
        
        var lastSmoothed = 0.0
        var lastUnsmoothed = 0.0
        
        for angle in angles {
            let s = smoothed.update(angle)
            let u = unsmoothed.update(angle)
            
            smoothedChanges.append(abs(s - lastSmoothed))
            unsmoothedChanges.append(abs(u - lastUnsmoothed))
            
            lastSmoothed = s
            lastUnsmoothed = u
        }
        
        let avgSmoothedChange = smoothedChanges.dropFirst().reduce(0, +) / Double(smoothedChanges.count - 1)
        let avgUnsmoothedChange = unsmoothedChanges.dropFirst().reduce(0, +) / Double(unsmoothedChanges.count - 1)
        
        XCTAssertLessThan(avgSmoothedChange, avgUnsmoothedChange,
            "Smoothed tracker should have smaller average changes")
    }
    
    // MARK: - Codable Tests
    
    func testCodable() throws {
        var original = RelativeAngleTracker(smoothing: 0.3)
        original.begin(at: 45)
        _ = original.update(90)
        _ = original.update(30)
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RelativeAngleTracker.self, from: encoded)
        
        XCTAssertEqual(original.anchorDegrees, decoded.anchorDegrees)
        XCTAssertEqual(original.observedMin, decoded.observedMin)
        XCTAssertEqual(original.observedMax, decoded.observedMax)
        XCTAssertEqual(original.smoothing, decoded.smoothing)
    }
    
    // MARK: - AC5: Sweep Progress Tests (Acceptance Criteria)
    
    func testAC5SweepProgressRisesMonotonically() {
        // AC5: With `-FoldMock sweep:20-180:3`, gallery reveal progress rises
        // monotonically from 0 to 1 (±0.05 jitter).
        
        var tracker = RelativeAngleTracker(smoothing: 0.25)
        
        let steps = FoldScriptStep.sweep(from: 20, to: 180, duration: 3.0, steps: 30)
        
        var previousProgress: Double = -0.05 // Allow first step to be 0
        var progressValues: [Double] = []
        
        for (index, step) in steps.enumerated() {
            if let angle = step.angleDegrees {
                if index == 0 {
                    tracker.begin(at: angle)
                    progressValues.append(0)
                    previousProgress = 0
                } else {
                    let progress = tracker.update(angle)
                    progressValues.append(progress)
                    
                    XCTAssertGreaterThanOrEqual(progress, previousProgress - 0.05,
                        "Progress should be monotonically increasing (±0.05 jitter): step=\(index), angle=\(angle), progress=\(progress), previous=\(previousProgress)")
                    previousProgress = progress
                }
            }
        }
        
        guard let lastProgress = progressValues.last else {
            XCTFail("No progress values recorded")
            return
        }
        XCTAssertGreaterThan(lastProgress, 0.9, "Final progress should approach 1.0")
    }
}
