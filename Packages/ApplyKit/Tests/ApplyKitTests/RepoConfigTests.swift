import XCTest

/// Checks committed app config that must stay true on every platform.
/// StoreKitTest itself only compiles in the Xcode test target.
final class RepoConfigTests: XCTestCase {

    func testStoreKitProductIsFamilyShareableNonConsumable() throws {
        let url = repoRoot().appendingPathComponent("Configuration.storekit")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let products = json?["products"] as? [[String: Any]]
        let pro = products?.first { $0["productID"] as? String == "com.jackyu.duowall.pro" }

        XCTAssertEqual(pro?["type"] as? String, "NonConsumable")
        XCTAssertEqual(pro?["familyShareable"] as? Bool, true)
        XCTAssertEqual(pro?["displayPrice"] as? String, "6.99")
    }

    func testStringCatalogTranslatesEveryKeyToChinese() throws {
        let url = repoRoot().appendingPathComponent("App/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["sourceLanguage"] as? String, "en")

        let strings = try XCTUnwrap(json?["strings"] as? [String: Any])
        XCTAssertGreaterThan(strings.count, 80)

        var missing: [String] = []
        for (key, value) in strings {
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let zh = localizations["zh-Hans"] as? [String: Any],
                  let unit = zh["stringUnit"] as? [String: Any],
                  unit["state"] as? String == "translated",
                  let translated = unit["value"] as? String,
                  !translated.isEmpty
            else {
                missing.append(key)
                continue
            }
        }
        XCTAssertEqual(missing, [], "zh-Hans translations missing: \(missing.sorted())")
    }

    func testUIStringLiteralsAreInTheCatalog() throws {
        let catalogURL = repoRoot().appendingPathComponent("App/Resources/Localizable.xcstrings")
        let catalogData = try Data(contentsOf: catalogURL)
        let catalog = try JSONSerialization.jsonObject(with: catalogData) as? [String: Any]
        let keys = Set((catalog?["strings"] as? [String: Any])?.keys.map { $0 } ?? [])

        let sources = repoRoot().appendingPathComponent("App/Sources")
        let pattern = #"(?:Text|Button|Label|Toggle|Section|Picker|NavigationLink|navigationTitle|sectionHeader|ProgressView|ContentUnavailableView)\(\s*"([^"\\]+)"|(?:title|description|question|answer):\s*"([^"\\]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        var missing: [String] = []

        let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                let literal: String?
                if match.range(at: 1).location != NSNotFound, let swiftRange = Range(match.range(at: 1), in: text) {
                    literal = String(text[swiftRange])
                } else if match.range(at: 2).location != NSNotFound, let swiftRange = Range(match.range(at: 2), in: text) {
                    literal = String(text[swiftRange])
                } else {
                    literal = nil
                }
                guard let literal, !literal.isEmpty, literal != "1.0.0" else { continue }
                if !keys.contains(literal) {
                    missing.append("\(file.lastPathComponent): \(literal)")
                }
            }
        }

        XCTAssertEqual(missing, [], "UI strings missing from Localizable.xcstrings:\n\(missing.joined(separator: "\n"))")
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
