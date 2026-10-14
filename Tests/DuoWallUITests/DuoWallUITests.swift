import XCTest

final class DuoWallUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }
    
    func testGalleryLoads() throws {
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "nohinge"]
        app.launch()
        
        XCTAssertTrue(app.navigationBars["DuoWall"].exists)
    }
    
    func testNoHingeLayoutIsCompact() throws {
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "nohinge"]
        app.launch()
        
        let compactLayout = app.otherElements["layout.compact"]
        XCTAssertTrue(compactLayout.waitForExistence(timeout: 5))
    }
    
    func testOpenLayoutIsSplit() throws {
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "open"]
        app.launch()
        
        let splitLayout = app.otherElements["layout.split"]
        XCTAssertTrue(splitLayout.waitForExistence(timeout: 5))
    }
    
    func testClosedLayoutIsCompact() throws {
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "closed"]
        app.launch()
        
        let compactLayout = app.otherElements["layout.compact"]
        XCTAssertTrue(compactLayout.waitForExistence(timeout: 5))
    }
    
    func testSettingsNavigation() throws {
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "nohinge"]
        app.launch()
        
        let settingsButton = app.buttons["gear"]
        if settingsButton.exists {
            settingsButton.tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        }
    }
}
