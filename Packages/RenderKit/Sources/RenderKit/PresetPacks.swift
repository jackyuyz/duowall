import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import EditorCore

/// Metadata for a bundled wallpaper pair
public struct PairManifest: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    
    /// Display title
    public var title: String
    
    /// Localized titles (key = locale code, value = title)
    public var localizedTitles: [String: String]
    
    /// Color palette extracted from the images
    public var palette: [String]
    
    /// Artist credit
    public var artistCredit: String?
    
    /// Template used for this pair
    public var template: TemplateKind
    
    /// Whether this requires Pro
    public var isPremium: Bool
    
    /// Filename of the inner image in the pack
    public var innerImageFile: String
    
    /// Description for accessibility
    public var accessibilityDescription: String
    
    /// Tags for search/filtering
    public var tags: [String]
    
    public init(
        id: String,
        title: String,
        localizedTitles: [String: String] = [:],
        palette: [String] = [],
        artistCredit: String? = nil,
        template: TemplateKind = .reveal,
        isPremium: Bool = false,
        innerImageFile: String,
        accessibilityDescription: String,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.localizedTitles = localizedTitles
        self.palette = palette
        self.artistCredit = artistCredit
        self.template = template
        self.isPremium = isPremium
        self.innerImageFile = innerImageFile
        self.accessibilityDescription = accessibilityDescription
        self.tags = tags
    }
    
    /// Get localized title for current locale
    public func localizedTitle(for locale: String = Locale.current.identifier) -> String {
        let languageCode = String(locale.prefix(2))
        return localizedTitles[languageCode] ?? localizedTitles[locale] ?? title
    }
}

/// A bundled wallpaper pack
public struct WallpaperPack: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    
    /// Pack display name
    public var name: String
    
    /// Localized names
    public var localizedNames: [String: String]
    
    /// Pack description
    public var description: String
    
    /// Pairs in this pack
    public var pairs: [PairManifest]
    
    /// Pack version
    public var version: Int
    
    /// License information
    public var license: String
    
    public init(
        id: String,
        name: String,
        localizedNames: [String: String] = [:],
        description: String,
        pairs: [PairManifest],
        version: Int = 1,
        license: String = "CC0"
    ) {
        self.id = id
        self.name = name
        self.localizedNames = localizedNames
        self.description = description
        self.pairs = pairs
        self.version = version
        self.license = license
    }
    
    /// Get all free pairs
    public var freePairs: [PairManifest] {
        pairs.filter { !$0.isPremium }
    }
    
    /// Get all premium pairs
    public var premiumPairs: [PairManifest] {
        pairs.filter { $0.isPremium }
    }
}

// MARK: - Default Pack Definition

/// Default bundled pack for DuoWall
/// In the real app, this would be loaded from bundled JSON files.
public struct DefaultPacks {
    
    /// The main bundled pack with 30 pairs (10 free, 20 premium)
    public static func mainPack() -> WallpaperPack {
        WallpaperPack(
            id: "main",
            name: "DuoWall Collection",
            localizedNames: ["zh": "DuoWall 精选"],
            description: "The essential wallpaper collection for iPhone Duo",
            pairs: freePairs() + premiumPairs(),
            version: 1,
            license: "In-house designs + CC0 licensed artwork. See docs/artwork-licenses.md"
        )
    }
    
    /// Free tier pairs (10)
    public static func freePairs() -> [PairManifest] {
        [
            PairManifest(
                id: "aurora",
                title: "Aurora",
                localizedTitles: ["zh": "极光"],
                palette: ["#1a1a2e", "#16213e", "#0f3460", "#e94560"],
                template: .reveal,
                isPremium: false,
                innerImageFile: "aurora.png",
                accessibilityDescription: "Aurora borealis over mountains, reveals mountain range when opened",
                tags: ["nature", "night", "mountains"]
            ),
            PairManifest(
                id: "ocean-depths",
                title: "Ocean Depths",
                localizedTitles: ["zh": "深海"],
                palette: ["#0a1628", "#1a3a5c", "#2d6187", "#4a90b5"],
                template: .reveal,
                isPremium: false,
                innerImageFile: "ocean-depths.png",
                accessibilityDescription: "Deep ocean scene, reveals underwater coral when opened",
                tags: ["ocean", "underwater", "calm"]
            ),
            PairManifest(
                id: "sunset-gradient",
                title: "Sunset Gradient",
                localizedTitles: ["zh": "日落渐变"],
                palette: ["#ff6b6b", "#ffa07a", "#ffd93d", "#6bcb77"],
                template: .reveal,
                isPremium: false,
                innerImageFile: "sunset-gradient.png",
                accessibilityDescription: "Warm sunset colors, reveals extended sky when opened",
                tags: ["gradient", "warm", "sunset"]
            ),
            PairManifest(
                id: "minimal-geo",
                title: "Minimal Geometry",
                localizedTitles: ["zh": "几何简约"],
                palette: ["#f8f9fa", "#e9ecef", "#343a40", "#212529"],
                template: .reveal,
                isPremium: false,
                innerImageFile: "minimal-geo.png",
                accessibilityDescription: "Clean geometric shapes, reveals full pattern when opened",
                tags: ["minimal", "geometric", "modern"]
            ),
            PairManifest(
                id: "forest-mist",
                title: "Forest Mist",
                localizedTitles: ["zh": "森林薄雾"],
                palette: ["#2d4a3e", "#3d6b4f", "#5a8f6c", "#95c4a8"],
                template: .reveal,
                isPremium: false,
                innerImageFile: "forest-mist.png",
                accessibilityDescription: "Misty forest, reveals depth of trees when opened",
                tags: ["nature", "forest", "calm"]
            ),
            PairManifest(
                id: "night-city",
                title: "Night City",
                localizedTitles: ["zh": "夜城"],
                palette: ["#0d1b2a", "#1b263b", "#415a77", "#778da9"],
                template: .panorama,
                isPremium: false,
                innerImageFile: "night-city.png",
                accessibilityDescription: "City skyline at night, spans full inner display",
                tags: ["city", "night", "urban"]
            ),
            PairManifest(
                id: "desert-dunes",
                title: "Desert Dunes",
                localizedTitles: ["zh": "沙漠沙丘"],
                palette: ["#d4a574", "#c4956a", "#a67c52", "#8b6339"],
                template: .reveal,
                isPremium: false,
                innerImageFile: "desert-dunes.png",
                accessibilityDescription: "Golden desert dunes, reveals horizon when opened",
                tags: ["nature", "desert", "warm"]
            ),
            PairManifest(
                id: "space-nebula",
                title: "Space Nebula",
                localizedTitles: ["zh": "星云"],
                palette: ["#1a1a2e", "#4a1942", "#6b2d5c", "#9b4d96"],
                template: .reveal,
                isPremium: false,
                innerImageFile: "space-nebula.png",
                accessibilityDescription: "Colorful nebula in space, reveals full cosmic scene when opened",
                tags: ["space", "cosmic", "colorful"]
            ),
            PairManifest(
                id: "cherry-blossom",
                title: "Cherry Blossom",
                localizedTitles: ["zh": "樱花"],
                palette: ["#ffcad4", "#f4acb7", "#9d8189", "#6d6875"],
                template: .reveal,
                isPremium: false,
                innerImageFile: "cherry-blossom.png",
                accessibilityDescription: "Cherry blossom branches, reveals tree when opened",
                tags: ["nature", "flowers", "spring"]
            ),
            PairManifest(
                id: "abstract-waves",
                title: "Abstract Waves",
                localizedTitles: ["zh": "抽象波纹"],
                palette: ["#2b2d42", "#8d99ae", "#edf2f4", "#ef233c"],
                template: .reveal,
                isPremium: false,
                innerImageFile: "abstract-waves.png",
                accessibilityDescription: "Abstract wave pattern, reveals full design when opened",
                tags: ["abstract", "modern", "pattern"]
            )
        ]
    }
    
    /// Premium tier pairs (20)
    public static func premiumPairs() -> [PairManifest] {
        (1...20).map { i in
            PairManifest(
                id: "premium-\(i)",
                title: "Premium Design \(i)",
                localizedTitles: ["zh": "高级设计 \(i)"],
                palette: ["#000000", "#333333", "#666666", "#999999"],
                template: i % 3 == 0 ? .panorama : (i % 3 == 1 ? .reveal : .splitMood),
                isPremium: true,
                innerImageFile: "premium-\(i).png",
                accessibilityDescription: "Premium wallpaper design number \(i)",
                tags: ["premium"]
            )
        }
    }
}
