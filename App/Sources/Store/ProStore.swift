import Foundation
import Observation
import StoreKit

public enum ProProduct {
    public static let id = "com.jackyu.duowall.pro"
}

public enum StoreError: Error {
    case unverified
    case productUnavailable
}

/// StoreKit 2 Pro entitlement. Family Sharing is enabled on the non-consumable
/// in App Store Connect and in `Configuration.storekit`.
@MainActor
@Observable
public final class ProStore {
    public private(set) var isPro = false
    public private(set) var isPendingAskToBuy = false
    public private(set) var products: [Product] = []
    public private(set) var loadError: String?

    /// Free exports include a watermark. Purchase removes it immediately.
    public var showsWatermark: Bool { !isPro }

    public init() {}

    public func loadProducts() async {
        do {
            products = try await Product.products(for: [ProProduct.id])
            loadError = products.isEmpty ? "Store unavailable. Try again later." : nil
        } catch {
            products = []
            loadError = "Store unavailable. Try again later."
        }
    }

    public func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == ProProduct.id else { continue }
            if transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPro = entitled
        if entitled {
            isPendingAskToBuy = false
        }
    }

    /// Purchase Pro. Ask to Buy stays pending and does not grant the entitlement.
    public func purchase() async throws {
        if products.isEmpty {
            await loadProducts()
        }
        guard let product = products.first(where: { $0.id == ProProduct.id }) else {
            throw StoreError.productUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            if transaction.revocationDate == nil {
                isPro = true
            }
            isPendingAskToBuy = false
            await transaction.finish()
        case .pending:
            isPendingAskToBuy = true
        case .userCancelled:
            break
        @unknown default:
            break
        }
    }

    public func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    public func listenForTransactions() async {
        await refreshEntitlements()
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await transaction.finish()
            }
            await refreshEntitlements()
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreError.unverified
        }
    }
}
