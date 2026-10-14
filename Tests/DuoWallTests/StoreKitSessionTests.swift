import StoreKit
import StoreKitTest
import XCTest
@testable import DuoWall

/// AC9. Compiles and runs in the DuoWall Xcode scheme.
/// StoreKitTest is not available on Linux, so this target is not part of `swift test`.
@MainActor
final class StoreKitSessionTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Configuration")
        session.disableDialogs = true
        session.clearTransactions()
        try session.resetToDefaultState()
    }

    override func tearDown() {
        session = nil
    }

    func testPurchaseRemovesWatermarkImmediately() async throws {
        let store = ProStore()
        XCTAssertTrue(store.showsWatermark)

        try await store.loadProducts()
        XCTAssertFalse(store.products.isEmpty)

        try await store.purchase()

        XCTAssertTrue(store.isPro)
        XCTAssertFalse(store.showsWatermark)
        XCTAssertFalse(store.isPendingAskToBuy)
    }

    func testRestoreGrantsPro() async throws {
        _ = try session.buyProduct(identifier: ProProduct.id)

        let store = ProStore()
        try await store.restore()

        XCTAssertTrue(store.isPro)
        XCTAssertFalse(store.showsWatermark)
    }

    func testRefundRemovesProAndRestoresWatermark() async throws {
        let transaction = try session.buyProduct(identifier: ProProduct.id)
        let store = ProStore()
        await store.refreshEntitlements()
        XCTAssertTrue(store.isPro)
        XCTAssertFalse(store.showsWatermark)

        try session.refundTransaction(identifier: transaction.identifier)
        await store.refreshEntitlements()

        XCTAssertFalse(store.isPro)
        XCTAssertTrue(store.showsWatermark)
    }

    func testAskToBuyStaysPendingWithoutUnlockingPro() async throws {
        session.askToBuyEnabled = true

        let store = ProStore()
        try await store.loadProducts()
        try await store.purchase()

        XCTAssertTrue(store.isPendingAskToBuy)
        XCTAssertFalse(store.isPro)
        XCTAssertTrue(store.showsWatermark)
    }
}
