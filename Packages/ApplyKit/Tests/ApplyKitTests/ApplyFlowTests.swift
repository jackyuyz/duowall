import XCTest
@testable import ApplyKit

private struct MockLauncher: ShortcutLaunching {
    var opens: Bool
    func openShortcut(url: URL) async -> Bool { opens }
}

final class ApplyFlowTests: XCTestCase {

    func testDeadlineIsOneSecond() {
        XCTAssertEqual(ApplyTiming.manualGuideDeadline, .seconds(1))
        XCTAssertLessThan(ApplyTiming.returnFallbackDelay, ApplyTiming.manualGuideDeadline)
    }

    func testMissingShortcutShowsManualGuideWithinOneSecond() async {
        let flow = ApplyFlow(launcher: MockLauncher(opens: true), shortcutInstalled: false)
        let start = ContinuousClock.now
        let phase = await flow.startApply()
        let elapsed = ContinuousClock.now - start

        XCTAssertEqual(phase, .manualGuide(.shortcutNotInstalled))
        XCTAssertLessThan(elapsed, ApplyTiming.manualGuideDeadline)
    }

    func testOpenFailureShowsManualGuideWithinOneSecond() async {
        let flow = ApplyFlow(launcher: MockLauncher(opens: false), shortcutInstalled: true)
        let start = ContinuousClock.now
        let phase = await flow.startApply()
        let elapsed = ContinuousClock.now - start

        XCTAssertEqual(phase, .manualGuide(.openFailed))
        XCTAssertLessThan(elapsed, ApplyTiming.manualGuideDeadline)
    }

    func testShortcutErrorCallbackShowsManualGuideWithinOneSecond() async {
        let flow = ApplyFlow(launcher: MockLauncher(opens: true), shortcutInstalled: true)
        let launched = await flow.startApply()
        XCTAssertEqual(launched, .launchingShortcut)

        let start = ContinuousClock.now
        let phase = await flow.handleCallback(.error)
        let elapsed = ContinuousClock.now - start

        XCTAssertEqual(phase, .manualGuide(.shortcutError))
        XCTAssertLessThan(elapsed, ApplyTiming.manualGuideDeadline)
    }

    func testReturnWithoutSuccessShowsManualGuideWithinOneSecond() async {
        let flow = ApplyFlow(launcher: MockLauncher(opens: true), shortcutInstalled: true)
        let launched = await flow.startApply()
        XCTAssertEqual(launched, .launchingShortcut)

        let start = ContinuousClock.now
        let phase = await flow.handleReturnWithoutSuccess()
        let elapsed = ContinuousClock.now - start

        XCTAssertEqual(phase, .manualGuide(.returnedWithoutSuccess))
        XCTAssertLessThan(elapsed, ApplyTiming.manualGuideDeadline)
    }

    func testSuccessCallbackDoesNotFallBackToGuide() async {
        let flow = ApplyFlow(launcher: MockLauncher(opens: true), shortcutInstalled: true)
        _ = await flow.startApply()
        let success = await flow.handleCallback(.success)
        XCTAssertEqual(success, .shortcutSucceeded)

        let afterReturn = await flow.handleReturnWithoutSuccess()
        XCTAssertEqual(afterReturn, .shortcutSucceeded)
    }

    func testLaunchURLUsesXCallback() {
        let url = ApplyShortcut.launchURL.absoluteString
        XCTAssertTrue(url.hasPrefix("shortcuts://x-callback-url/run-shortcut"))
        XCTAssertTrue(url.contains("x-success=duowall://applied"))
        XCTAssertTrue(url.contains("x-error=duowall://failed"))
        XCTAssertTrue(url.contains("DuoWall%20Apply"))
    }
}
