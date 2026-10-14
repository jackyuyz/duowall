// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RenderKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "RenderKit",
            targets: ["RenderKit"]
        ),
    ],
    dependencies: [
        .package(path: "../DisplaySpecKit"),
        .package(path: "../EditorCore")
    ],
    targets: [
        .target(
            name: "RenderKit",
            dependencies: ["DisplaySpecKit", "EditorCore"]
        ),
        .testTarget(
            name: "RenderKitTests",
            dependencies: ["RenderKit"]
        ),
    ]
)
