// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ApplyKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ApplyKit",
            targets: ["ApplyKit"]
        ),
    ],
    targets: [
        .target(
            name: "ApplyKit",
            dependencies: []
        ),
        .testTarget(
            name: "ApplyKitTests",
            dependencies: ["ApplyKit"]
        ),
    ]
)
