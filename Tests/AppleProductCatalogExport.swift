import Foundation

enum AppPreferenceKeys { static let reduceExtraAnimations = "reduceExtraAnimations" }

@main struct AppleProductCatalogExport {
    static func main() throws {
        var products: [String: [String: Any]] = [:]
        for pack in CoinPackProduct.all { products[pack.id] = ["coins": pack.coins] }
        products[RankedAccessProduct.allAccessProductID] = ["mode": "all"]
        for mode in GameMode.allCases {
            products[RankedAccessProduct.productID(for: mode)] = ["mode": mode.rawValue]
        }
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: products, options: [.sortedKeys]))
    }
}
