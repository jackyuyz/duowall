// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EditorCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorCore",
            targets: ["EditorCore"]
        ),
    ],
    dependencies: [
        .package(path: "../DisplaySpecKit")
    ],
    targets: [
        .target(
            name: "EditorCore",
            dependencies: ["DisplaySpecKit"]
        ),
        .testTarget(
            name: "EditorCoreTests",
            dependencies: ["EditorCore"]
        ),
    ]
)
