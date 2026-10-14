// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DisplaySpecKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DisplaySpecKit",
            targets: ["DisplaySpecKit"]
        ),
    ],
    targets: [
        .target(
            name: "DisplaySpecKit",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DisplaySpecKitTests",
            dependencies: ["DisplaySpecKit"]
        ),
    ]
)
